# cython: profile=True
# cython: embedsignature=True
from cpython cimport bool
from kivy.properties import (
    BooleanProperty, StringProperty, NumericProperty, ListProperty
    )
from kivy.graphics import Callback
from kivy.graphics.instructions cimport RenderContext
from kivent_core.rendering.vertex_formats cimport (
    VertexFormat4F, VertexFormat2F4UB, VertexFormat7F, VertexFormat4F4UB,
    VertexFormat7F4UB
    )
from kivent_core.rendering.vertex_formats import (
    vertex_format_4f, vertex_format_7f, vertex_format_4f4ub, 
    vertex_format_2f4ub, vertex_format_7f4ub
    )
from kivent_core.rendering.vertex_format cimport KEVertexFormat
from kivent_core.rendering.cmesh cimport CMesh
from kivent_core.rendering.batching cimport BatchManager, IndexedBatch
from kivent_core.managers.resource_managers import texture_manager
from kivent_core.managers.resource_managers cimport ModelManager, TextureManager
from kivy.graphics.opengl import (
    glEnable, glDisable, glBlendFunc, GL_SRC_ALPHA, GL_ONE, 
    GL_ZERO, GL_SRC_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_ONE_MINUS_SRC_ALPHA, 
    GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA, GL_DST_COLOR, GL_ONE_MINUS_DST_COLOR,
    )
cimport cython
from kivy.graphics.c_opengl cimport GLfloat, GLushort
from staticmemgamesystem cimport StaticMemGameSystem, MemComponent
from kivent_core.systems.position_systems cimport PositionStruct2D
from kivent_core.systems.rotate_systems cimport RotateStruct2D
from kivent_core.systems.scale_systems cimport ScaleStruct2D
from kivent_core.systems.color_systems cimport ColorStruct
from kivent_core.entity cimport Entity
from kivent_core.rendering.model cimport VertexModel
from kivy.factory import Factory
from libc.math cimport fabs
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivent_core.systems.staticmemgamesystem cimport ComponentPointerAggregator
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivy.properties import ObjectProperty, NumericProperty
from kivy.clock import Clock
from kivent_core.rendering.gl_debug cimport gl_log_debug_message
from functools import partial


cdef class RenderComponent(MemComponent):
    '''The component associated with various renderers including: Renderer 
    and RotateRenderer. Designed for 2d sprites, but potentially useful for 
    other types of models as well. If not using for sprites, ignore **width**,
    **height**, and **texture_key** properties as they are designed for
    convenience when working with textured quads. Prefer instead to modify the
    properties of the **vert_mesh** directly.

    **Attributes:**
        **entity_id** (unsigned int): The entity_id this component is currently
        associated with. Will be <unsigned int>-1 if the component is
        unattached.

        **width** (float): The width of the sprite.

        **height** (float): The height of the sprite.

        **batch_id** (unsigned int): The batch the entity is assigned to. Read
        Only. If the entity is not currently batched will be <unsigned int>-1.

        **attribute_count** (unsigned int): The number of attributes in the
        vertex format for the model.

        **texture_key** (str): The name of the texture for this component. If
        there is no texture None will be returned.

        **render** (bool): Whether or not this entity should actually be
        rendered.

        **vertex_count** (unsigned int): The number of vertices in the current
        model (the **vert_mesh**). You should not modify the number of vertices
        while an entity is batched.

        **index_count** (unsigned int): The number of indices in the current
        model (the **vert_mesh**). You should not modify the number of indices
        while an entity is batched.

        **vert_mesh** (VertMesh): The actual VertMesh object containing the
        model information for this component.
    '''

    property entity_id:
        def __get__(self):
            cdef RenderStruct* data = <RenderStruct*>self.pointer
            return data.entity_id

    property width:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            return fabs(model[0].pos[0]*2.)

        def __set__(self, float value):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            cdef float w
            if value != 0:
                w = .5*value
                model[0].pos = [-w, model[0].pos[1]]
                model[1].pos = [-w, model[1].pos[1]]
                model[2].pos = [w, model[2].pos[1]]
                model[3].pos = [w, model[3].pos[1]]


    property height:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            return fabs(model[0].pos[1]*2.)

        def __set__(self, float value):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            cdef float h
            if value != 0:
                h = .5*value
                model[0].pos = [model[0].pos[0], -h]
                model[1].pos = [model[1].pos[0], h]
                model[2].pos = [model[2].pos[0], h]
                model[3].pos = [model[3].pos[0], -h]


    property batch_id:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            return component_data.batch_id


    property texture_key:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            if component_data.texkey == <unsigned int>-1:
                return None
            else:
                return texture_manager.get_texname_from_texkey(
                    component_data.texkey)

        def __set__(self, str value):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef unsigned int groupkey = (
                texture_manager.get_groupkey_from_texkey(component_data.texkey))
            cdef unsigned int texkey = texture_manager.get_texkey_from_name(
                value)
            cdef float u0, v0, u1, v1
            cdef list uv_list = texture_manager.get_uvs(texkey)
            u0 = uv_list[0]
            v0 = uv_list[1]
            u1 = uv_list[2]
            v1 = uv_list[3]
            same_batch = texture_manager.get_texkey_in_group(texkey, groupkey)
            cdef VertexModel model = <VertexModel>component_data.model
            cdef Renderer renderer = <Renderer>component_data.renderer
            if not same_batch:
                renderer._unbatch_entity(component_data.entity_id,
                    component_data)
            component_data.texkey = texkey
            model[0].uvs = [u0, v0]
            model[1].uvs = [u0, v1]
            model[2].uvs = [u1, v1]
            model[3].uvs = [u1, v0]
            if not same_batch:
                renderer._batch_entity(component_data.entity_id,
                    component_data)


    property render:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            return component_data.render

        def __set__(self, bool value):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            if value:
                component_data.render = 1
            else:
                component_data.render = 0


    property vertex_count:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            return model._vertex_count

        def __set__(self, int value):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            cdef Renderer renderer = <Renderer>component_data.renderer
            renderer._unbatch_entity(component_data.entity_id, component_data)
            model.vertex_count = value
            renderer._batch_entity(component_data.entity_id, component_data)


    property index_count:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            return model._index_count

        def __set__(self, int value):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            cdef Renderer renderer = <Renderer>component_data.renderer
            renderer._unbatch_entity(component_data.entity_id, component_data)
            model.index_count = value
            renderer._batch_entity(component_data.entity_id, component_data)


    property model:
        def __get__(self):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef VertexModel model = <VertexModel>component_data.model
            return model

        def __set__(self, str model_name):
            cdef RenderStruct* component_data = <RenderStruct*>self.pointer
            cdef Renderer renderer = <Renderer>component_data.renderer
            renderer._unbatch_entity(component_data.entity_id, component_data)
            cdef ModelManager manager = renderer.gameworld.model_manager
            manager.unregister_entity_with_model(component_data.entity_id,
                (<VertexModel>component_data.model)._name)
            cdef VertexModel model = manager._models[model_name]
            component_data.model = <void*>model
            manager.register_entity_with_model(component_data.entity_id,
                renderer.system_id, model._name)
            renderer._batch_entity(component_data.entity_id, component_data)


cdef class Renderer(StaticMemGameSystem):
    '''
    Processing Depends On: PositionSystem2D, Renderer

    The basic KivEnt renderer draws with the VertexFormat4F:

    .. code-block:: cython

        ctypedef struct VertexFormat4F:
            GLfloat[2] pos
            GLfloat[2] uvs

    Entities will be batched into groups of up to **maximum_vertices**, if
    they can share the source of texture. This GameSystem is only
    dependent on its own component and the PositionComponent2D.

    If you want a static renderer, set **frame_count** to 1 and **updateable**
    to false.

    **Attributes:**
        **shader_source** (StringProperty): Path to the .glsl to be used, do
        include '.glsl' in the name. You must ensure that your shader matches
        your vertex format or you will have problems.

        **maximum_vertices** (NumericProperty): The maximum number of vertices
        that will be placed in a batch.

        **attribute_count** (NumericProperty): The number of attributes each
        vertex will contain. Computed automatically inside
        calculate_vertex_format.

        **vertex_format** (dict): describes format of data sent to shaders,
        generated automatically based on do_rotate, do_scale, do_color

        **blend_factor_source** (NumericProperty): Sets the Blend Source. for
        a visual exploration of this concept visit :
        http://www.andersriggelsen.dk/glblendfunc.php
        Options Include:
        GL_SRC_ALPHA, GL_ONE, GL_ZERO, GL_SRC_COLOR, GL_ONE_MINUS_SRC_COLOR,
        GL_ONE_MINUS_SRC_ALPHA, GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA,
        GL_DST_COLOR, GL_ONE_MINUS_DST_COLOR

        **blend_factor_dest** (NumericProperty): Sets the Blend Dest.
        See blend_factor_sourc for more details.

        **reset_blend_factor_source** (NumericProperty): The blend source
        will be reset to this after drawing this canvas.
        See blend_factor_source for more details.

        **reset_blend_factor_dest** (NumericProperty): The blend dest
        will be reset to this after drawing this canvas.
        See blend_factor_source for more details.

        **smallest_vertex_count** (NumericProperty, should be int): Used to
        estimate the number of entities that can fit in each batch at max,
        batch ComponentPointerAggregator will then be **size_of_batches** //
        **smallest_vertex_count** * **vertex_format_size**.

        **max_batches** (NumericProperty, should be int): The maximum number
        of space to reserve for this renderer. Will be **max_batches** *
        **frame_count** * **size_of_batches**.

        **size_of_batches** (NumericProperty): Size in kibibytes of each batch.

        **vertex_format_size** (NumericProperty): The size in bytes of the
        vertex_format to be used. Will typically be the result of calling
        sizeof on the struct being used.

        **frame_count** (NumericProperty, should be int): The number of frames
        to multibuffer.

        **force_update** (BooleanProperty): Set force_update if you want to be
        sure an Entity is drawn immediately upon being added instead of waiting
        for the next update tick. Useful if you want to have a static renderer,
        or if you are adding and removing an Entity every frame.

        **static_rendering** (BooleanProperty): Set static_rendering to True,
        if you do not want to redraw every Entity every frame. Usually used
        in combination with force_update = True.

        **update_trigger** (function): Invoke update_trigger if you want to
        force the renderer to redraw a frame. force_update = True will call
        update_trigger automatically on batching and unbatching of an Entity.

    **Attributes: (Cython Access Only)**
        **attribute_count** (unsigned int): The number of attributes in the
        VertMesh format for this renderer. Defaults to 4 (x, y, u, v).

        **batch_manager** (BatchManager): The BatchManager that is responsible
        for actually submitting vertex data to the GPU.

    '''
    system_id = StringProperty('renderer')
    updateable = BooleanProperty(True)
    renderable = BooleanProperty(True)
    static_rendering = BooleanProperty(False)
    force_update = BooleanProperty(False)
    max_batches = NumericProperty(20)
    size_of_batches = NumericProperty(256)
    vertex_format_size = NumericProperty(sizeof(VertexFormat4F))
    frame_count = NumericProperty(2)
    smallest_vertex_count = NumericProperty(4)
    system_names = ListProperty(['renderer', 'position'])
    shader_source = StringProperty('positionshader.glsl')
    model_format = StringProperty('vertex_format_4f')
    blend_factor_source = NumericProperty(GL_SRC_ALPHA)
    blend_factor_dest = NumericProperty(GL_ONE_MINUS_SRC_ALPHA)
    reset_blend_factor_source = NumericProperty(GL_SRC_ALPHA)
    reset_blend_factor_dest = NumericProperty(GL_ONE_MINUS_SRC_ALPHA)
    type_size = NumericProperty(sizeof(RenderStruct))
    component_type = ObjectProperty(RenderComponent)

    def __init__(self, **kwargs):
        self.canvas = RenderContext(use_parent_projection=True,
                                    nocompiler=True)
        if 'shader_source' in kwargs:
            self.canvas.shader.source = kwargs.get('shader_source')
        super(Renderer, self).__init__(**kwargs)
        with self.canvas.before:
            Callback(self._set_blend_func)
        with self.canvas.after:
            Callback(self._reset_blend_func)
        self.update_trigger = Clock.create_trigger(partial(self.update, True))


    property update_trigger:

        def __get__(self):
            return self.update_trigger

    def _set_blend_func(self, instruction):
        '''
        This function is called internally in a callback on canvas.before
        to set up the blend function, it will obey **blend_factor_source**
        and **blend_factor_dest** properties.
        '''
        gl_log_debug_message('Renderer._set_blend_func-preglBlendFunc')
        glBlendFunc(self.blend_factor_source, self.blend_factor_dest)
        gl_log_debug_message('Renderer._set_blend_func-glBlendFunc')

    def _reset_blend_func(self, instruction):
        '''
        This function is called internally in a callback on canvas.after
        to reset the blend function, it will obey **reset_blend_factor_source**
        and **reset_blend_factor_dest** properties.
        '''
        glBlendFunc(self.reset_blend_factor_source,
            self.reset_blend_factor_dest)
        gl_log_debug_message('Renderer._reset_blend_func-glBlendFunc')

    def _update(self, dt):
        '''
        We only want to update renderer once per frame, so we will override
        the basic GameSystem logic here which accounts appropriately for
        dt.
        '''
        self.update(False, dt)

    def on_shader_source(self, instance, value):
        '''
        Event that sets the canvas.shader.source property when the
        **shader_source** property is set
        '''
        self.canvas.shader.source = value

    def clear_component(self, unsigned int component_index):
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef RenderStruct* pointer = <RenderStruct*>memory_zone.get_pointer(
            component_index)
        pointer.entity_id = -1
        pointer.model = NULL
        pointer.renderer = NULL
        pointer.texkey = -1
        pointer.render = 0
        pointer.batch_id = -1
        pointer.vert_index = -1
        pointer.ind_index = -1

    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        '''
        Function called internally during **allocate** to setup the
        BatchManager. The KEVertexFormat should be initialized in this
        function as well.
        '''
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat4F), *vertex_format_4f)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count,
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names],
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager

    def allocate(self, Buffer master_buffer, dict reserve_spec):
        super(Renderer, self).allocate(master_buffer, reserve_spec)
        self.setup_batch_manager(master_buffer)

    def get_system_size(self):
        return super(
            Renderer, self).get_system_size() + self.batch_manager.get_size()

    def get_size_estimate(self, dict reserve_spec):
        cdef unsigned int total = super(Renderer, self).get_size_estimate(
            reserve_spec)
        cdef unsigned int count = len(self.system_names)
        cdef unsigned int vsize_in_bytes = self.size_of_batches * 1024
        cdef unsigned int vtype_size = self.vertex_format_size
        cdef unsigned int vert_slots_per_block = vsize_in_bytes // vtype_size
        cdef unsigned int ent_per_batch = (
            vert_slots_per_block // self.smallest_vertex_count)

        cdef unsigned int size_per_ent = sizeof(void*) * count
        pointer_size_in_kb = (
            (self.max_batches * ent_per_batch * size_per_ent) // 1024) + 1
        return total + pointer_size_in_kb + (
            self.max_batches * self.size_of_batches * self.frame_count * 2)

    cdef void* _init_component(self, unsigned int component_index,
        unsigned int entity_id, bool render, VertexModel model,
        unsigned int texkey) except NULL:
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef RenderStruct* pointer = <RenderStruct*>memory_zone.get_pointer(
            component_index)
        pointer.entity_id = entity_id
        pointer.model = <void*>model
        pointer.renderer = <void*>self
        pointer.texkey = texkey
        if render:
            pointer.render = 1
        else:
            pointer.render = 0
        self._batch_entity(entity_id, pointer)
        return pointer

    def init_component(self, unsigned int component_index,
        unsigned int entity_id, str zone_name, args):
        '''
        A RenderComponent is initialized with an args dict with many
        optional values.

        Optional Args:

            texture (str): If 'texture' is in args, the appropriate texture
            will be loaded from managers.resource_managers.texture_manager.
            #change to model_key
            vert_mesh_key (str): If 'vert_mesh_key' is in args, the associated
            model from managers.resource_managers.model_manager will be loaded.
            Otherwise, it will be assumed we are rendering a sprite and the
            appropriate model for that sprite will either be generated or
            loaded from the model_manager if it already exists. If this occurs
            the models name will be str(**attribute_count**) + texture_key.

            size (tuple): If size is provided and there is no 'vert_mesh_key'
            and the sprite has not been loaded before the size of the newly
            generated sprite VertMesh will be set to (width, height).

            render (bool): If 'render' is in args, the components render
            attribute will be set to the provided, otherwise it defaults to
            True.

        Keep in mind that all RenderComponent will share the same VertMesh if
        they have the same vert_mesh_key or load the same sprite.
        '''
        cdef float w, h
        cdef int vert_index_key, texkey
        cdef bool copy, render
        if 'texture' in args:
            texture_key = args['texture']
            texkey = texture_manager.get_texkey_from_name(texture_key)
            w, h = texture_manager.get_size(texkey)
        else:
            texture_key = str(None)
            texkey = -1
        if 'size' in args:
            w, h = args['size']
        copy = args.get('copy', False)
        copy_name = args.get('copy_name', None)
        render = args.get('render', True)
        model_key = args.get('model_key', None)
        cdef ModelManager model_manager = self.gameworld.model_manager
        if model_key is None:
            if copy_name is None:
                copy_name = self.model_format + '_' + texture_key
            model_key = model_manager.load_textured_rectangle(
                self.model_format, w, h, texture_key, copy_name,
                do_copy=copy)
        elif model_key is not None and copy:
            model_key = model_manager.copy_model(model_key,
                model_name=copy_name)
        cdef VertexModel model = model_manager._models[model_key]
        model_manager.register_entity_with_model(entity_id, self.system_id,
            model_key)
        self._init_component(component_index, entity_id, render, model, texkey)

    def update(self, force_update, dt):
        '''
        Update function where all drawing of entities is performed.
        Override this method if you would like to create a renderer with
        customized behavior. The basic logic is that we iterate through
        each batch getting the entities in that batch, then iterate through
        the vertices in the RenderComponent.vert_mesh, copying every
        vertex into the batches data and combining it with data from other
        components.

        Args:
            dt (float): The time elapsed since last update, not usually
            used in rendering but passed in to maintain a consistent API.
        '''
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct2D* pos_comp
        cdef VertexFormat4F* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat4F* vertex
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat4F* model_vertices
        cdef VertexFormat4F model_vertex
        cdef unsigned int used, i, ri, component_count, n, t
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering

        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat4F*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for t in range(used):
                        ri = t * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct2D*>component_data[ri+1]
                            model_vertices = <VertexFormat4F*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = pos_comp.x + model_vertex.pos[0]
                                vertex.pos[1] = pos_comp.y + model_vertex.pos[1]
                                vertex.uvs[0] = model_vertex.uvs[0]
                                vertex.uvs[1] = model_vertex.uvs[1]
                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()

    def remove_component(self, unsigned int component_index):
        cdef IndexedMemoryZone components = self.imz_components
        cdef RenderStruct* pointer = <RenderStruct*>components.get_pointer(
            component_index)
        self._unbatch_entity(pointer.entity_id, pointer)
        self.gameworld.model_manager.unregister_entity_with_model(
            pointer.entity_id, (<VertexModel>pointer.model)._name)
        super(Renderer, self).remove_component(component_index)

    def unbatch_entity(self, unsigned int entity_id):
        '''
        Python accessible function for unbatching the entity, the real work
        is done in the cdefed _unbatch_entity.

        Args:
            entity_id (unsigned int): The id of the entity to unbatch.
        '''
        cdef IndexedMemoryZone components = self.imz_components
        cdef IndexedMemoryZone entities = self.gameworld.entities
        cdef Entity entity = entities[entity_id]
        cdef unsigned int component_index = entity.get_component_index(
            self.system_id)
        self._unbatch_entity(entity_id, <RenderStruct*>components.get_pointer(
            component_index))

    cdef void* _unbatch_entity(self, unsigned int entity_id,
        RenderStruct* component_data) except NULL:
        '''
        The actual unbatching function. Will call
        **batch_manager**.unbatch_entity.

        Args:
            entity_id (unsigned int): The id of the entity to be unbatched.

            component_data (RenderStruct*): Pointer to the actual component
            data for the entity.

        Return:
            void*: Will return a pointer to the component_data passed in
            if successful, will raise an exception if NULL is returned. This
            return is required for exception propogation.
        '''
        cdef VertexModel model = <VertexModel>component_data.model
        self.batch_manager.unbatch_entity(entity_id, component_data.batch_id,
            model._vertex_count, model._index_count, component_data.vert_index,
            component_data.ind_index)
        component_data.batch_id = -1
        component_data.vert_index = -1
        component_data.ind_index = -1
        if self.force_update:
            self.update_trigger()
        return component_data

    def batch_entity(self, unsigned int entity_id):
        '''
        Python accessible function for batching the entity, the real work
        is done in the cdefed _batch_entity.

        Args:
            entity_id (unsigned int): The id of the entity to unbatch.
        '''
        cdef IndexedMemoryZone components = self.imz_components
        cdef IndexedMemoryZone entities = self.gameworld.entities
        cdef Entity entity = entities[entity_id]
        cdef unsigned int component_index = entity.get_component_index(
            self.system_id)
        self._batch_entity(entity_id,
            <RenderStruct*>components.get_pointer(component_index))

    cdef void* _batch_entity(self, unsigned int entity_id,
        RenderStruct* component_data) except NULL:
        '''
        The actual batching function. Will call
        **batch_manager**.batch_entity.

        Args:
            entity_id (unsigned int): The id of the entity to be unbatched.

            component_data (RenderStruct*): Pointer to the actual component
            data for the entity.

        Return:
            void*: Will return a pointer to the component_data passed in
            if successful, will raise an exception if NULL is returned. This
            return is required for exception propogation.
        '''
        cdef tuple batch_indices
        cdef VertexModel model = <VertexModel>component_data.model
        cdef unsigned int texkey = texture_manager.get_groupkey_from_texkey(
            component_data.texkey)
        batch_indices = self.batch_manager.batch_entity(entity_id,
            texkey, model._vertex_count, model._index_count)
        component_data.batch_id = batch_indices[0]
        component_data.vert_index = batch_indices[1]
        component_data.ind_index = batch_indices[2]
        if self.force_update:
            self.update_trigger()
        return component_data


cdef class RotateRenderer(Renderer):
    '''
    Processing Depends On: PositionSystem2D, RotateSystem2D, RotateRenderer

    The renderer draws with the VertexFormat7F:

    .. code-block:: cython

        ctypedef struct VertexFormat7F:
            GLfloat[2] pos
            GLfloat[2] uvs
            GLfloat rot
            GLfloat[2] center


    This renderer draws every entity with rotation data suitable
    for use with entities using the CymunkPhysics GameSystems.

    '''
    system_names = ListProperty(['rotate_renderer', 'position',
        'rotate'])
    system_id = StringProperty('rotate_renderer')
    vertex_format_size = NumericProperty(sizeof(VertexFormat7F))

    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat7F), *vertex_format_7f)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count,
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names],
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager


    def update(self, force_update, dt):
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct2D* pos_comp
        cdef RotateStruct2D* rot_comp
        cdef VertexFormat7F* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat7F* vertex
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat4F* model_vertices
        cdef VertexFormat4F model_vertex
        cdef unsigned int used, i, ri, component_count, n, t
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering

        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat7F*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for t in range(used):
                        ri = t * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct2D*>component_data[ri+1]
                            rot_comp = <RotateStruct2D*>component_data[ri+2]
                            model_vertices = <VertexFormat4F*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = model_vertex.pos[0]
                                vertex.pos[1] = model_vertex.pos[1]
                                vertex.uvs[0] = model_vertex.uvs[0]
                                vertex.uvs[1] = model_vertex.uvs[1]
                                vertex.rot = rot_comp.r
                                vertex.center[0] = pos_comp.x
                                vertex.center[1] = pos_comp.y
                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()


cdef class RotateColorRenderer(Renderer):
    '''
    Processing Depends On: PositionSystem2D, RotateSystem2D,
    ColorSystem, RotateColorRenderer

    The renderer draws with the VertexFormat7F4UB:

    .. code-block:: cython

        ctypedef struct VertexFormat7F:
            GLfloat[2] pos
            GLfloat[2] uvs
            GLfloat rot
            GLfloat[2] center
            GLubyte[4] v_color


    This renderer draws every entity with rotation data suitable
    for use with entities using the CymunkPhysics GameSystems. 

    '''
    system_names = ListProperty(['rotate_color_renderer', 'position',
        'rotate', 'color'])
    system_id = StringProperty('rotate_color_renderer')
    vertex_format_size = NumericProperty(sizeof(VertexFormat7F4UB))
    
    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat7F4UB), *vertex_format_7f4ub)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count, 
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names], 
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager


    def update(self, force_update, dt):
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct2D* pos_comp
        cdef RotateStruct2D* rot_comp
        cdef VertexFormat7F4UB* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat7F4UB* vertex
        cdef ColorStruct* color_comp
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat4F* model_vertices
        cdef VertexFormat4F model_vertex
        cdef unsigned int used, i, ri, component_count, n, t
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering

        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat7F4UB*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for t in range(used):
                        ri = t * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct2D*>component_data[ri+1]
                            rot_comp = <RotateStruct2D*>component_data[ri+2]
                            color_comp = <ColorStruct*>component_data[ri+3]
                            model_vertices = <VertexFormat4F*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = model_vertex.pos[0]
                                vertex.pos[1] = model_vertex.pos[1]
                                vertex.uvs[0] = model_vertex.uvs[0]
                                vertex.uvs[1] = model_vertex.uvs[1]
                                vertex.rot = rot_comp.r
                                vertex.center[0] = pos_comp.x
                                vertex.center[1] = pos_comp.y
                                vertex.v_color[0] = color_comp.color[0]
                                vertex.v_color[1] = color_comp.color[1]
                                vertex.v_color[2] = color_comp.color[2]
                                vertex.v_color[3] = color_comp.color[3]

                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()


cdef class ColorRenderer(Renderer):
    '''
    Processing Depends On: PositionSystem2D, ColorSystem, ColorRenderer

    The renderer draws with the VertexFormat8F:

    .. code-block:: cython

        ctypedef struct VertexFormat8F:
            GLfloat[2] pos
            GLfloat[2] uvs
            GLubyte[4] v_color

    '''
    system_names = ListProperty(['color_renderer', 'position',
        'color'])
    system_id = StringProperty('color_renderer')
    vertex_format_size = NumericProperty(sizeof(VertexFormat4F4UB))

    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat4F4UB), *vertex_format_4f4ub)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count,
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names],
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager


    def update(self, force_update, dt):
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct2D* pos_comp
        cdef ColorStruct* color_comp
        cdef VertexFormat4F4UB* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat4F4UB* vertex
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat4F* model_vertices
        cdef VertexFormat4F model_vertex
        cdef unsigned int used, i, ri, component_count, n, t
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering
        cdef int ii

        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat4F4UB*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for t in range(used):
                        ri = t * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[
                            ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct2D*>component_data[
                                ri+1]
                            color_comp = <ColorStruct*>component_data[
                                ri+2]
                            model_vertices = <VertexFormat4F*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = pos_comp.x + model_vertex.pos[0]
                                vertex.pos[1] = pos_comp.y + model_vertex.pos[1]
                                vertex.uvs[0] = model_vertex.uvs[0]
                                vertex.uvs[1] = model_vertex.uvs[1]
                                for ii in range(4):
                                    vertex.v_color[ii] = color_comp.color[ii]
                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()

cdef unsigned char blend_integer_colors(unsigned char color1,
                                        unsigned char color2):
    return <unsigned char>((<float>color1 / 255.) * (
                           <float>color2 / 255.) * 255)

cdef class PolyRenderer(Renderer):
    '''
    Processing Depends On: PositionSystem2D, PolyRenderer

    The renderer draws with the VertexFormat2F4UB:

    .. code-block:: cython

        ctypedef struct VertexFormat2F4UB:
            GLfloat[2] pos
            GLubyte[4] v_color

    '''
    system_names = ListProperty(['poly_renderer', 'position'])
    system_id = StringProperty('poly_renderer')
    model_format = StringProperty('vertex_format_2f4ub')
    vertex_format_size = NumericProperty(sizeof(VertexFormat2F4UB))
    
    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat2F4UB), *vertex_format_2f4ub)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count, 
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names], 
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager


    def update(self, force_update, dt):
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct2D* pos_comp
        cdef VertexFormat2F4UB* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat2F4UB* vertex
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat2F4UB* model_vertices
        cdef VertexFormat2F4UB model_vertex
        cdef unsigned int used, i, ri, component_count, n
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering
        
        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat2F4UB*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for i in range(used):
                        ri = i * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct2D*>component_data[
                                ri+1]
                            model_vertices = <VertexFormat2F4UB*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = pos_comp.x + model_vertex.pos[0]
                                vertex.pos[1] = pos_comp.y + model_vertex.pos[1]
                                vertex.v_color[0] = model_vertex.v_color[0]
                                vertex.v_color[1] = model_vertex.v_color[1]
                                vertex.v_color[2] = model_vertex.v_color[2]
                                vertex.v_color[3] = model_vertex.v_color[3]
                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()


cdef class ColorPolyRenderer(Renderer):
    '''
    Processing Depends On: PositionSystem2D, ColorSystem, ColorPolyRenderer

    The renderer draws with the VertexFormat2F4UB:

    .. code-block:: cython

        ctypedef struct VertexFormat2F4UB:
            GLfloat[2] pos
            GLubyte[4] v_color

    '''
    system_names = ListProperty(['color_poly_renderer', 'position', 'color'])
    system_id = StringProperty('color_poly_renderer')
    model_format = StringProperty('vertex_format_2f4ub')
    vertex_format_size = NumericProperty(sizeof(VertexFormat2F4UB))
    
    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat2F4UB), *vertex_format_2f4ub)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count, 
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names], 
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager


    def update(self, force_update, dt):
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct2D* pos_comp
        cdef ColorStruct* color_comp
        cdef VertexFormat2F4UB* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat2F4UB* vertex
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat2F4UB* model_vertices
        cdef VertexFormat2F4UB model_vertex
        cdef unsigned int used, i, ri, component_count, n
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering
        
        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat2F4UB*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for i in range(used):
                        ri = i * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct2D*>component_data[
                                ri+1]
                            color_comp = <ColorStruct*>component_data[
                                ri+2]
                            model_vertices = <VertexFormat2F4UB*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = pos_comp.x + model_vertex.pos[0]
                                vertex.pos[1] = pos_comp.y + model_vertex.pos[1]
                                vertex.v_color[0] = blend_integer_colors(
                                    model_vertex.v_color[0],
                                    color_comp.color[0]) 
                                vertex.v_color[1] = blend_integer_colors(
                                    model_vertex.v_color[1],
                                    color_comp.color[1]) 
                                vertex.v_color[2] = blend_integer_colors(
                                    model_vertex.v_color[2],
                                    color_comp.color[2]) 
                                vertex.v_color[3] = blend_integer_colors(
                                    model_vertex.v_color[3],
                                    color_comp.color[3]) 
                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()

cdef class ScaledPolyRenderer(Renderer):
    '''
    Processing Depends On: PositionSystem2D, PolyRenderer

    The renderer draws with the VertexFormat2F4UB:

    .. code-block:: cython

        ctypedef struct VertexFormat2F4UB:
            GLfloat[2] pos
            GLubyte[4] v_color

    '''
    system_names = ListProperty(['scaled_poly_renderer', 'position', 'scale', 'color'])
    system_id = StringProperty('scaled_poly_renderer')
    model_format = StringProperty('vertex_format_2f4ub')
    vertex_format_size = NumericProperty(sizeof(VertexFormat2F4UB))
    
    cdef void* setup_batch_manager(self, Buffer master_buffer) except NULL:
        cdef KEVertexFormat batch_vertex_format = KEVertexFormat(
            sizeof(VertexFormat2F4UB), *vertex_format_2f4ub)
        self.batch_manager = BatchManager(
            self.size_of_batches, self.max_batches, self.frame_count, 
            batch_vertex_format, master_buffer, 'triangles', self.canvas,
            [x for x in self.system_names], 
            self.smallest_vertex_count, self.gameworld)
        return <void*>self.batch_manager


    def update(self, force_update, dt):
        cdef IndexedBatch batch
        cdef list batches
        cdef unsigned int batch_key
        cdef unsigned int index_offset, vert_offset
        cdef RenderStruct* render_comp
        cdef PositionStruct2D* pos_comp
        cdef ScaleStruct2D* scale_comp
        cdef ColorStruct* color_comp
        cdef VertexFormat2F4UB* frame_data
        cdef GLushort* frame_indices
        cdef VertexFormat2F4UB* vertex
        cdef VertexModel model
        cdef GLushort* model_indices
        cdef VertexFormat2F4UB* model_vertices
        cdef VertexFormat2F4UB model_vertex
        cdef unsigned int used, i, ri, component_count, n
        cdef ComponentPointerAggregator entity_components
        cdef BatchManager batch_manager = self.batch_manager
        cdef dict batch_groups = batch_manager.batch_groups
        cdef CMesh mesh_instruction
        cdef MemoryBlock components_block
        cdef void** component_data
        cdef bint static_rendering = self.static_rendering
        
        for batch_key in batch_groups:
            batches = batch_groups[batch_key]
            for batch in batches:
                if not static_rendering or force_update:
                    entity_components = batch.entity_components
                    components_block = entity_components.memory_block
                    used = components_block.used_count
                    component_count = entity_components.count
                    component_data = <void**>components_block.data
                    frame_data = <VertexFormat2F4UB*>batch.get_vbo_frame_to_draw()
                    frame_indices = <GLushort*>batch.get_indices_frame_to_draw()
                    index_offset = 0
                    for i in range(used):
                        ri = i * component_count
                        if component_data[ri] == NULL:
                            continue
                        render_comp = <RenderStruct*>component_data[ri+0]
                        vert_offset = render_comp.vert_index
                        model = <VertexModel>render_comp.model
                        if render_comp.render:
                            pos_comp = <PositionStruct2D*>component_data[ri+1]
                            scale_comp = <ScaleStruct2D*>component_data[ri+2]
                            color_comp = <ColorStruct*>component_data[
                                ri+3]
                            model_vertices = <VertexFormat2F4UB*>(
                                model.vertices_block.data)
                            model_indices = <GLushort*>model.indices_block.data
                            for i in range(model._index_count):
                                frame_indices[i+index_offset] = (
                                    model_indices[i] + vert_offset)
                            for n in range(model._vertex_count):
                                vertex = &frame_data[n + vert_offset]
                                model_vertex = model_vertices[n]
                                vertex.pos[0] = pos_comp.x + (
                                                model_vertex.pos[0] * 
                                                scale_comp.sx)
                                vertex.pos[1] = pos_comp.y + (
                                                model_vertex.pos[1] * 
                                                scale_comp.sy)
                                vertex.v_color[0] = blend_integer_colors(
                                    model_vertex.v_color[0],
                                    color_comp.color[0]) 
                                vertex.v_color[1] = blend_integer_colors(
                                    model_vertex.v_color[1],
                                    color_comp.color[1]) 
                                vertex.v_color[2] = blend_integer_colors(
                                    model_vertex.v_color[2],
                                    color_comp.color[2]) 
                                vertex.v_color[3] = blend_integer_colors(
                                    model_vertex.v_color[3],
                                    color_comp.color[3]) 
                            index_offset += model._index_count
                    batch.set_index_count_for_frame(index_offset)
                mesh_instruction = batch.mesh_instruction
                mesh_instruction.flag_update()



Factory.register('Renderer', cls=Renderer)
Factory.register('RotateRenderer', cls=RotateRenderer)
Factory.register('RotateColorRenderer', cls=RotateColorRenderer)
Factory.register('ColorRenderer', cls=ColorRenderer)
Factory.register('PolyRenderer', cls=PolyRenderer)
Factory.register('ColorPolyRenderer', cls=ColorPolyRenderer)
Factory.register('ScaledPolyRenderer', cls=ScaledPolyRenderer)

