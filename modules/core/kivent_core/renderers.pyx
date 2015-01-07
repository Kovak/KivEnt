# cython: profile=True
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from kivy.core.image import Image as CoreImage
from cpython cimport bool
from kivy.properties import (BooleanProperty, StringProperty, NumericProperty)
from os import path
cdef extern from "string.h":
    void *memcpy(void *dest, void *src, size_t n)
from gamesystems cimport (PositionComponent, RotateComponent, ScaleComponent,
    ColorComponent)
from kivy.graphics import RenderContext, Callback
from gamesystems import GameSystem
from cmesh cimport CMesh
import json
from kivy.graphics.opengl import (glEnable, glBlendFunc, GL_SRC_ALPHA, GL_ONE, 
    GL_ZERO, GL_SRC_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_ONE_MINUS_SRC_ALPHA, 
    GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA, GL_DST_COLOR, GL_ONE_MINUS_DST_COLOR,
    glDisable)
cimport cython


cdef class TextureManager:
    '''The TextureManager handles the loading of all image resources into our
    game engine. Use **load_image** for image files and **load_atlas** for
    .atlas files. Do not load 2 images with the same name even in different
    atlas files. Prefer to access kivent.renderers.texture_manager than
    making your own instance.'''

    def __init__(self):
        self._textures = {}
        self._keys = {}
        self._sizes = {}
        self._uvs = {}
        self._groups = {}

    def load_image(self, source):
        texture = CoreImage(source, nocache=True).texture
        name = path.splitext(path.basename(source))[0]
        if name not in self._textures:
            self._textures[name] = texture
            self._keys[name] = name
            self._uvs[name] = [0., 0., 1., 1.]
            self._groups[name] = [name]
        else:
            raise KeyError()

    def load_texture(self, name, texture):
        if name in self._textures:
            raise KeyError()
        else:
            self._textures[name] = texture
            self._keys[name] = name
            self._uvs[name] = [0., 0., 1., 1.]
            self._groups[name] = [name]

    def unload_texture(self, name):
        if name not in self._textures:
            raise KeyError()
        else:
            texture_keys = self._groups[name]
            for key in texture_keys:
                del self._uvs[key]
                del self._keys[key]
            del self._groups[name]
            del self._textures[name]


    def get_uvs(self, tex_key):
        try:
            return self._uvs[tex_key]
        except:
            return [0., 0., 1., 1.]

    def get_size(self,tex_key):
        return self._sizes[tex_key]

    def get_texture(self, tex_name):
        return self._textures[tex_name]

    def get_texture_from_key(self, tex_key):
        return self._textures[self._keys[tex_key]]

    def get_texname_from_texkey(self, tex_key):
        return self._keys[tex_key]

    def get_texkey_in_group(self, tex_key, atlas_name):
        if tex_key is None and atlas_name is None:#should this be or?
            return True
        else:
            return atlas_name in self._groups and tex_key in self._groups[atlas_name]

    def load_atlas(self, source):
        dirname = path.dirname(source)
        with open(source, 'r') as data:
             atlas_data = json.load(data)

        for imgname in atlas_data:
            texture = CoreImage(path.join(dirname,imgname), nocache=True).texture
            name = str(path.basename(imgname))
            size = texture.size
            w = <float>size[0]
            h = <float>size[1]
            keys = self._keys
            uvs = self._uvs
            group_list = []
            group_list_a = group_list.append
            atlas_content = atlas_data[imgname]

            if name in self._textures:
                raise KeyError("'%s' already in textures"%name)
            self._textures[name] = texture
            for key in atlas_content:
                key = <str>key
                kx,ky,kw,kh = atlas_content[key]
                self._keys[key] = name
                self._sizes[key] = kw, kh
                x1, y1 = kx, ky
                x2, y2 = x1 + kw, y1 + kh
                self._uvs[key] = [x1/w, 1.-y1/h, x2/w, 1.-y2/h] 
                group_list_a(str(key))
            self._groups[name] = group_list

texture_manager = TextureManager()

@cython.freelist(100)
cdef class RenderComponent:

    def __cinit__(self, bool render, str texture_key, 
        int attribute_count, width=None, height=None, 
        VertMesh vert_mesh=None, copy=False):
        self._render = render
        self._texture_key = texture_key
        self._attrib_count = attribute_count
        if width is not None and height is not None:
            self._width = width
            self._height = height
            self._vert_mesh = vert_mesh = VertMesh(attribute_count, 4, 6)
            vert_mesh.set_textured_rectangle(width, height, 
                texture_manager.get_uvs(texture_key))
        elif vert_mesh != None:
            self._width = 0
            self._height = 0
            if not copy:
                self._vert_mesh = vert_mesh
            else:
                self._vert_mesh = new_vert_mesh = VertMesh(attribute_count, 
                    vert_mesh._vert_count, vert_mesh._index_count)
                new_vert_mesh.copy_vert_mesh(vert_mesh)

    property width:
        def __get__(self):
            return self._width

        def __set__(self, float value):
            width = value
            height = self._height
            cdef VertMesh vert_mesh = self._vert_mesh

            if width != 0 and height != 0:
                w = .5*width
                self._width = width
                set_vertex_attribute=vert_mesh.set_vertex_attribute
                set_vertex_attribute(0,0,-w)
                set_vertex_attribute(1,0,-w)
                set_vertex_attribute(2,0,w)
                set_vertex_attribute(3,0,w)
        

    property height:
        def __get__(self):
            return self._height

        def __set__(self, float value):
            width = self._width
            height = value
            if width != 0 and height != 0:
                h = .5*height
                self._height = height
                set_vertex_attribute=self._vert_mesh.set_vertex_attribute
                set_vertex_attribute(0,1,-h)
                set_vertex_attribute(1,1,h)
                set_vertex_attribute(2,1,h)
                set_vertex_attribute(3,1,-h)

    property batch_id:
        def __get__(self):
            return self._batch_id

    property attribute_count:
        def __get__(self):
            return self._attrib_count

        def __set__(self, int value):
            self._attrib_count = value
            self._vert_mesh.attribute_count = value

    property texture_key:
        def __get__(self):
            return self._texture_key
        def __set__(self, str value):
            self._texture_key = value
            cdef float u0, v0, u1, v1
            cdef list uv_list = texture_manager.get_uvs(value)
            u0 = uv_list[0]
            v0 = uv_list[1]
            u1 = uv_list[2]
            v1 = uv_list[3]
            set_vertex_attribute=self._vert_mesh.set_vertex_attribute
            set_vertex_attribute(0, 2, u0)
            set_vertex_attribute(0, 3, v0)
            set_vertex_attribute(1, 2, u0)
            set_vertex_attribute(1, 3, v1)
            set_vertex_attribute(2, 2, u1)
            set_vertex_attribute(2, 3, v1)
            set_vertex_attribute(3, 2, u1)
            set_vertex_attribute(3, 3, v0)

    property render:
        def __get__(self):
            return self._render
        def __set__(self, bool value):
            self._render = value

    property vertex_count:
        def __get__(self):
            return self._vert_mesh._vert_count

        def __set__(self, int value):
            self._vert_mesh.vertex_count = value

    property index_count:
        def __get__(self):
            return self._vert_mesh._index_count

        def __set__(self, int value):
            self._vert_mesh.index_count = value

    property vert_mesh:
        def __get__(self):
            return self._vert_mesh

        def __set__(self, VertMesh vert_mesh):
            self._vert_mesh = vert_mesh


class Renderer(GameSystem):
    '''The basic KivEnt renderer it draws every entity every frame. Entities 
    will be batched into groups of up to **maximum_vertices**, if they can
    share the source of texture. 

    **Attributes:**
        **do_rotate** (BooleanProperty): Determines whether or not vertex 
        format will have a float for rotate

        **do_color** (BooleanProperty): Determines whether or not vertex 
        format will have 4 floats for rgba color

        **do_scale** (BooleanProperty): Determines whether or not vertex 
        format will have a float for scale

        **shader_source** (StringProperty): Path to the .glsl to be used, do 
        include '.glsl' in the name. You must ensure that your shader matches 
        your vertex format or you will have problems

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


    '''
    system_id = StringProperty('renderer')
    updateable = BooleanProperty(True)
    renderable = BooleanProperty(True)
    do_rotate = BooleanProperty(False)
    do_color = BooleanProperty(False)
    do_scale = BooleanProperty(False)
    attribute_count = NumericProperty(4)
    maximum_vertices = NumericProperty(20000)
    shader_source = StringProperty('positionshader.glsl')
    blend_factor_source = NumericProperty(GL_SRC_ALPHA)
    blend_factor_dest = NumericProperty(GL_ONE_MINUS_SRC_ALPHA)
    reset_blend_factor_source = NumericProperty(GL_SRC_ALPHA)
    reset_blend_factor_dest = NumericProperty(GL_ONE_MINUS_SRC_ALPHA)


    def __init__(self, **kwargs):
        self.canvas = RenderContext(use_parent_projection=True)
        if 'shader_source' in kwargs:
            self.canvas.shader.source = kwargs.get('shader_source')
        super(Renderer, self).__init__(**kwargs)
        self.batches = []
        self.vertex_format = self.calculate_vertex_format()
        self._do_r_index = -1
        self._do_g_index = -1
        self._do_b_index = -1
        self._do_a_index = -1
        self._do_rot_index = -1
        self._do_scale_index = -1
        self._do_center_x = 4
        self._do_center_y = 5
        with self.canvas.before:
            Callback(self._set_blend_func)
        with self.canvas.after:
            Callback(self._reset_blend_func)

    def _set_blend_func(self, instruction):
        glBlendFunc(self.blend_factor_source, self.blend_factor_dest)

    def _reset_blend_func(self, instruction):
        glBlendFunc(self.reset_blend_factor_source, 
            self.reset_blend_factor_dest)

    def _update(self, dt):
        '''
        We only want to update renderer once per frame, so we will override
        the basic GameSystem logic here which accounts appropriately for
        dt.
        '''
        self.update(dt)

    def on_shader_source(self, instance, value):
        self.canvas.shader.source = value

    def on_do_rotate(self, instance, value):
        self.vertex_format = self.calculate_vertex_format()

    def on_do_scale(self, instance, value):
        self.vertex_format = self.calculate_vertex_format()

    def on_do_color(self, instance, value):
        self.vertex_format = self.calculate_vertex_format()

    def calculate_vertex_format(self):
        '''Function used internally to calculate the vertex_format.
        Override this method if you would like to create a custom
        vertex format.'''
        vertex_format = [
            ('vPosition', 2, 'float'),
            ('vTexCoords0', 2, 'float'),
            ('vCenter', 2, 'float'),
            ]
        attribute_count = 6
        if self.do_rotate:
            vertex_format.append(('vRotation', 1, 'float'))
            self._do_rot_index = attribute_count
            attribute_count += 1
        if self.do_color:
            vertex_format.append(('vColor', 4, 'float'))
            self._do_r_index = attribute_count
            self._do_g_index = attribute_count + 1
            self._do_b_index = attribute_count + 2
            self._do_a_index = attribute_count + 3
            attribute_count += 4
        if self.do_scale:
            self._do_scale_index = attribute_count
            vertex_format.append(('vScale', 1, 'float'))
            attribute_count += 1
        self.attribute_count = attribute_count
        return vertex_format

    def update(self, dt):
        '''Update function where all drawing of entities is performed. 
        Override this method in combination with calculate_vertex_format
        if you would like to create a renderer with customized behavior.'''
        cdef list batches = self.batches
        cdef int num_batches = len(batches)
        cdef str system_id = self.system_id
        cdef RenderBatch batch
        cdef object gameworld = self.gameworld
        cdef object entity
        cdef int entity_id
        cdef list entities = gameworld.entities
        cdef list entity_ids
        cdef RenderComponent render_comp
        cdef PositionComponent pos_comp
        cdef RotateComponent rot_comp
        cdef ScaleComponent scale_comp
        cdef ColorComponent color_comp
        cdef int vert_offset
        cdef int attribute_count = self.attribute_count
        cdef int vertex_count
        cdef int index_count
        cdef int index_offset
        cdef int mesh_index_offset
        cdef int n
        cdef int attr_ind
        cdef int i
        cdef float rot
        cdef float s
        cdef float r
        cdef float g
        cdef float b
        cdef float a
        cdef bool do_rotate = self.do_rotate
        cdef bool do_scale = self.do_scale
        cdef bool do_color = self.do_color
        cdef int center_x_index = self._do_center_x
        cdef int center_y_index = self._do_center_y
        cdef int rot_index = self._do_rot_index
        cdef int r_index = self._do_r_index
        cdef int g_index = self._do_g_index
        cdef int b_index = self._do_b_index
        cdef int a_index = self._do_a_index
        cdef int scale_index = self._do_scale_index
        cdef float x, y
        cdef VertMesh vert_mesh
        cdef float* batch_data
        cdef float* mesh_data
        cdef unsigned short* batch_indices
        cdef unsigned short* mesh_indices
        cdef int data_index
        cdef int mesh_index
        cdef int num_entities
        cdef int batch_ind
        cdef int ent_ind
        for batch_ind in range(num_batches):
            batch = batches[batch_ind]
            batch.update_batch()
            batch_data = batch._batch_data
            batch_indices = batch._batch_indices
            entity_ids = batch._entity_ids
            num_entities = len(entity_ids)
            index_offset = 0
            vert_offset = 0
            mesh_index_offset = 0
            for ent_ind in range(num_entities):
                entity_id = entity_ids[ent_ind]
                entity = entities[entity_id]
                render_comp = getattr(entity, system_id)
                vertex_count = render_comp.vertex_count
                index_count = render_comp.index_count
                if render_comp._render:
                    pos_comp = entity.position
                    x = pos_comp._x
                    y = pos_comp._y
                    if do_rotate:
                        rot_comp = entity.rotate
                        rot = rot_comp._r
                    if do_scale:
                        scale_comp = entity.scale
                        s = scale_comp._s
                    if do_color:
                        color_comp = entity.color
                        r = color_comp._r
                        g = color_comp._g
                        b = color_comp._b
                        a = color_comp._a
                    vert_mesh = render_comp._vert_mesh
                    mesh_data = vert_mesh._data
                    mesh_indices = vert_mesh._indices
                    for i in range(index_count):
                        batch_indices[i+index_offset] = (
                            mesh_indices[i] + mesh_index_offset)
                    for n in range(vertex_count):
                        for attr_ind in range(attribute_count):
                            mesh_index = n*attribute_count + attr_ind
                            data_index = mesh_index + vert_offset
                            if attr_ind == center_x_index:
                                batch_data[data_index] = x
                            elif attr_ind == center_y_index:
                                batch_data[data_index] = y
                            elif attr_ind == rot_index:
                                batch_data[data_index] = rot
                            elif attr_ind == r_index:
                                batch_data[data_index] = r
                            elif attr_ind == b_index:
                                batch_data[data_index] = b
                            elif attr_ind == g_index:
                                batch_data[data_index] = g
                            elif attr_ind == a_index:
                                batch_data[data_index] = a
                            elif attr_ind == scale_index:
                                batch_data[data_index] = s
                            else:
                                batch_data[data_index] = mesh_data[mesh_index]
                else:
                    for i in range(index_count):
                        batch_indices[i+index_offset] = -1
                vert_offset += vertex_count * attribute_count
                mesh_index_offset += vertex_count
                index_offset += index_count
            batch._cmesh.flag_update()

    def remove_entity(self, int entity_id):
        cdef list entities = self.gameworld.entities
        cdef object entity = entities[entity_id]
        cdef RenderComponent render_comp = getattr(entity, self.system_id)
        cdef int batch_id = render_comp._batch_id
        cdef RenderBatch batch = self.batches[batch_id]
        batch.remove_entity(entity_id)
        super(Renderer, self).remove_entity(entity_id)

    def on_attribute_count(self, instance, value):
        cdef RenderBatch batch 
        cdef list batches = self.batches
        for batch in batches:
            batch._attrib_count = value
        self.rebatch_all()

    def update_entity_batch_counts(self, int entity_id):
        '''If you have changed the number of vertices or indices in your
        entities VertMesh, call this function'''
        cdef list entities = self.gameworld.entities
        cdef list batches = self.batches
        cdef object entity = entities[entity_id]
        cdef RenderComponent render_comp = getattr(entity, self.system_id)
        cdef int batch_id = render_comp._batch_id
        cdef RenderBatch batch = batches[batch_id]
        batch.update_entity_counts(entity_id, render_comp.vertex_count, 
            render_comp.index_count)

    def rebatch_all(self):
        cdef list entity_ids = self.entity_ids
        cdef int entity_id
        rebatch_entity = self.rebatch_entity
        for entity_id in entity_ids:
            rebatch_entity(entity_id)

    def remove_entity_from_batch(self, int entity_id):
        cdef list entities = self.gameworld.entities
        cdef object entity = entities[entity_id]
        cdef list batches = self.batches
        cdef RenderComponent render_comp = getattr(entity, self.system_id)
        cdef int batch_id = render_comp._batch_id
        cdef RenderBatch batch = batches[batch_id]
        batch.remove_entity(entity_id)

    def rebatch_entity(self, int entity_id):
        cdef list entities = self.gameworld.entities
        cdef object entity = entities[entity_id]
        cdef list batches = self.batches
        cdef RenderComponent render_comp = getattr(entity, self.system_id)
        cdef int batch_id = render_comp._batch_id
        cdef RenderBatch batch = batches[batch_id]
        render_comp._attrib_count = self.attribute_count
        batch.remove_entity(entity_id)
        self.batch_entity(entity_id, render_comp.vertex_count, 
            render_comp.index_count, render_comp._texture_key, render_comp)

    def batch_entity(self, int entity_id, int vertex_count, int index_count, 
        str texture_key, RenderComponent render_comp):
        try_existing, batch_id = self.add_to_existing_batch(
            entity_id, vertex_count, index_count, texture_key)
        if not try_existing:
            batch_id = self.create_new_batch(entity_id, self.maximum_vertices, 
                self.attribute_count, vertex_count, index_count, texture_key)
        render_comp._batch_id = batch_id

    def create_component(self, object entity, args):
        cdef RenderComponent render_comp = self.generate_component(args)
        setattr(entity, self.system_id, render_comp)
        cdef int entity_id = entity.entity_id
        self.entity_ids.append(entity_id)
        cdef int vertex_count = render_comp.vertex_count
        cdef int index_count = render_comp.index_count
        cdef str texture_key = render_comp._texture_key
        self.batch_entity(entity_id, vertex_count, index_count, texture_key,
            render_comp)

    def create_new_batch(self, int entity_id, int max_verts, 
        int attribute_count, int vertex_count, int index_count, 
        str texture_key):
        '''Used internally when no batch exists or has room for the 
        entity being rendered'''
        if texture_key is not None:
            texture_name = texture_manager.get_texname_from_texkey(
                texture_key)
            texture = texture_manager.get_texture(texture_name)
        else:
            texture_name = None
            texture = None
        cdef CMesh cmesh
        with self.canvas:
            cmesh = CMesh(fmt=self.vertex_format, mode='triangles',
                    texture=texture)
        batch_id = len(self.batches)
        cdef RenderBatch new_batch = RenderBatch(max_verts, attribute_count, 
            cmesh, texture_name, batch_id)
        self.batches.append(new_batch)
        added = new_batch.add_entity(entity_id, vertex_count, index_count, 
            texture_key)
        if not added:
            raise Exception(
                'Entity: ' + str(entity_id) + ' not added to batch')
        return batch_id

    def add_to_existing_batch(self, int entity_id, int vertex_count, 
        int index_count, str texture_key):
        '''Used internally when there is an available batch to fit entity in'''
        cdef list batches = self.batches
        cdef RenderBatch batch
        for batch in batches:
            if batch.add_entity(entity_id, vertex_count, 
                index_count, texture_key):
                return True, batch._batch_id
        return False, None

    def generate_component(self, dict entity_component_dict):
        '''Renderers take in a dict containing a string 'texture' 
        correspondingto the name of the texture in the atlas, and a size tuple 
        of width, height if you would like to construct a textured quad. 
        You may also create your own VertMesh and supply it for direct use or 
        to be copied internally. In this case do not provide size, instead 
        provide 'copy' and 'vert_mesh' fields in the creation args dict 
        for your RenderComponent. You may also set 'render' at creation to 
        determine whether entity should be drawn.
        R'''
        if 'texture' in entity_component_dict:
            texture = entity_component_dict['texture']
        else:
            texture = None
        if 'size' in entity_component_dict:
            w, h = entity_component_dict['size']
        else:
            w, h = None, None
        if 'copy' in entity_component_dict:
            copy = entity_component_dict['copy']
        else:
            copy = False
        if 'render' in entity_component_dict:
            render = entity_component_dict['render']
        else:
            render = True
        if 'vert_mesh' in entity_component_dict:
            vert_mesh = entity_component_dict['vert_mesh']
        else:
            vert_mesh = None
        new_component = RenderComponent.__new__(RenderComponent, render, 
            texture, self.attribute_count, width=w, height=h, copy=copy,
            vert_mesh=vert_mesh)
        return new_component

@cython.freelist(20)
cdef class RenderBatch:

    def __cinit__(self, int maximum_verts, int attribute_count, CMesh cmesh,
            str texture_name, int batch_id):
        self._entity_ids = []
        self._entity_counts = {}
        self._maximum_verts = maximum_verts
        self._batch_data = NULL
        self._batch_indices = NULL
        self._r_index_count = 0
        self._r_vert_count = 0
        self._r_attrib_count = 0
        self._vert_count = 0
        self._index_count = 0
        self._attrib_count = attribute_count
        self._cmesh = cmesh
        self._texture = texture_name
        self._batch_id = batch_id

    def update_batch(self):
        cdef int vert_count = self._vert_count
        cdef int r_vert_count = self._r_vert_count
        cdef int index_count = self._index_count
        cdef int r_index_count = self._r_index_count
        cdef int r_attrib_count = self._r_attrib_count
        cdef float* batch_data = self._batch_data
        cdef int attribute_count = self._attrib_count
        cdef CMesh cmesh = self._cmesh
        cdef unsigned short* batch_indices = self._batch_indices
        if vert_count != r_vert_count or attribute_count != r_attrib_count:
            if not batch_data:
                batch_data = <float *>PyMem_Malloc(
                    vert_count * attribute_count * sizeof(float))
            else:
                batch_data = <float *>PyMem_Realloc(batch_data, 
                    attribute_count * vert_count * sizeof(float))
                if not batch_data:
                    raise MemoryError()
            self._r_vert_count = vert_count
            self._r_attrib_count = attribute_count
            self._batch_data = batch_data
            cmesh._vertices = batch_data
            cmesh.vcount = vert_count*attribute_count
        if index_count != r_index_count:
            if not batch_indices:
                batch_indices = <unsigned short*>PyMem_Malloc(
                    index_count * sizeof(unsigned short))
            else:
                batch_indices = <unsigned short*>PyMem_Realloc(
                    batch_indices, index_count * sizeof(unsigned short))
                if not batch_indices:
                    raise MemoryError()
            self._r_index_count = index_count
            self._batch_indices = batch_indices
            cmesh._indices = batch_indices
            cmesh.icount = index_count


    def __dealloc__(self):
        if self._batch_data != NULL:
            PyMem_Free(self._batch_data)
        if self._batch_indices != NULL:
            PyMem_Free(self._batch_indices)

    def add_entity(self, int entity_id, int num_verts, int num_indices,
        str texture_key):
        if num_verts + self._vert_count > self._maximum_verts or not (
            texture_manager.get_texkey_in_group(texture_key, self._texture)):
            return False
        else:
            self._vert_count += num_verts
            self._index_count += num_indices
            self._entity_ids.append(entity_id)
            self._entity_counts[entity_id] = (num_verts, num_indices)
            return True

    def remove_entity(self, int entity_id):
        self._entity_ids.remove(entity_id)
        entity_counts = self._entity_counts
        num_verts, num_indices = entity_counts[entity_id]
        self._vert_count -= num_verts
        self._index_count -= num_indices
        del entity_counts[entity_id]

    def update_entity_counts(self, int entity_id, int new_vert_count, 
        int new_indices_count):
        entity_counts = self._entity_counts
        num_verts, num_indices = entity_counts[entity_id]
        vert_change = new_vert_count - num_verts
        index_change = new_indices_count - num_indices
        self._vert_count += vert_change
        self._index_count += index_change
        entity_counts[entity_id] = (new_vert_count, new_indices_count)

@cython.freelist(100)
cdef class VertMesh:
    '''The VertMesh represents a collection of **vertex_count** vertices, 
    all having **attribute_count** floating point data fields. The 
    relationship between the vertices is kept in the form of a list of indices
    **index_count** in length corresponding to the triangles our mesh is made 
    up of. Typically you will want your vertex data to be centered around the
    origin, as the default rendering behavior will then obey the 
    PositionComponent of your entity.

    To work with an individual vertex you can:

    vert_mesh[vertex_number] = [1., 1., 1., 1.] #New vertex data 

    This will replace the first n attributes with the contents of the assigned
    list. Do not have length of assigned list exceed attribute_count.

    **Attributes:**
        **index_count** (int): Number of indices in the list of triangles.

        **attribute_count** (int): Number of attributes per vertex.

        **vertex_count** (int): Number of vertices in your mesh.

        **data** (list): Returns a copy of the VertMesh's vertex data. When 
        setting ensure your input list matches vertex_count * attribute_count 
        in size. To work with individual vertices use __setitem__ and
         __getitem__ or other helper functions. 

        **indices** (list): Returns a copy of the VertMesh's index data. When 
        setting ensure your input list matches index_count in size. 

    '''

    def __cinit__(self, int attribute_count, int vert_count, int index_count):
        self._attrib_count = attribute_count
        self._vert_count = vert_count
        self._index_count = index_count
        self._data = data = <float *>PyMem_Malloc(
            vert_count * attribute_count * sizeof(float))
        if not data:
            raise MemoryError()
        cdef unsigned short* indices = <unsigned short*>PyMem_Malloc(
                index_count * sizeof(unsigned short))
        if not indices:
            raise MemoryError()
        self._indices = indices
        
    def __dealloc__(self):
        if self._data != NULL:
            PyMem_Free(self._data)
        if self._indices != NULL:
            PyMem_Free(self._indices)

    property index_count:
        def __set__(self, int new_count):
            if new_count == self._index_count:
                return
            cdef unsigned short* new_indices = <unsigned short*>PyMem_Realloc(
                self._indices, new_count * sizeof(unsigned short))
            if not new_indices:
                raise MemoryError()
            self._indices = new_indices
            self._index_count = new_count

        def __get__(self):
            return self._index_count

    property attribute_count:

        def __set__(self, int new_count):
            if new_count == self._attrib_count:
                return
            new_data = <float *>PyMem_Realloc(self._data, 
                new_count * self._vert_count * sizeof(float))
            if not new_data:
                raise MemoryError()
            self._data = new_data
            self._attrib_count = new_count

        def __get__(self):
            return self._attrib_count

    property vertex_count:

        def __set__(self, int new_count):
            if new_count == self._vert_count:
                return
            new_data = <float *>PyMem_Realloc(self._data, 
                new_count * self._attrib_count * sizeof(float))
            if not new_data:
                raise MemoryError()
            self._data = new_data
            self._vert_count = new_count

        def __get__(self):
            return self._vert_count

    property data:

        def __get__(self):
            cdef float* data = self._data
            cdef list return_list = []
            cdef int length = len(self)
            r_append = return_list.append
            cdef int i
            for i from 0 <= i < length:
                r_append(data[i])
            return return_list

        def __set__(self, list new_data):
            cdef int vert_count = self._vert_count
            cdef int attrib_count = self._attrib_count
            if len(new_data) != len(self):
                raise Exception("Provided data doesn't match internal size")
            cdef float* data = self._data
            for i from 0 <= i < attrib_count * vert_count:
                data[i] = new_data[i]

    property indices:

        def __get__(self):
            cdef unsigned short* indices = self._indices
            cdef list return_list = []
            cdef int index_count = self._index_count
            r_append = return_list.append
            cdef int i
            cdef int index
            for i from 0 <= i < index_count:
                index = indices[i]
                r_append(index)
            return return_list

        def __set__(self, list new_indices):
            cdef int index_count = self._index_count
            if len(new_indices) != index_count:
                raise Exception("Provided data doesn't match internal size")
            cdef unsigned short* indices = self._indices
            for i from 0 <= i < index_count:
                indices[i] = new_indices[i]

    def __setitem__(self, int index, list values):
        cdef int vert_count = self._vert_count
        if not index < vert_count:
            raise IndexError()
        cdef int attrib_count = self._attrib_count
        cdef int start = attrib_count * index
        cdef int set_count = len(values)
        if not set_count <= attrib_count:
            raise Exception("Provided data doesn't match internal size")
        cdef int i
        cdef float* data = self._data
        cdef int vert_offset
        for i from 0 <= i < set_count:
            vert_offset = start + i
            data[vert_offset] = values[i]

    def __getitem__(self, int index):
        cdef int vert_count = self._vert_count
        if not index < vert_count:
            raise IndexError()
        cdef float* data = self._data
        cdef int attrib_count = self._attrib_count
        cdef int start = attrib_count * index
        cdef int i
        cdef return_list = []
        r_append = return_list.append
        for i from start <= i < start + attrib_count:
            r_append(data[i])
        return return_list

    def __len__(self):
        cdef int vert_count = self._vert_count
        cdef int attrib_count = self._attrib_count
        return vert_count * attrib_count

    def copy_vert_mesh(self, VertMesh vert_mesh):
        cdef float* from_data = vert_mesh._data
        self.vertex_count = vert_mesh._vert_count
        self.attribute_count = vert_mesh._attrib_count
        self.index_count = vert_mesh._index_count
        cdef float* data = self._data
        cdef unsigned short* indices = self._indices
        cdef unsigned short* from_indices = vert_mesh._indices
        memcpy(<char *>indices, <void *>from_indices, self._index_count*sizeof(
            unsigned short))
        memcpy(<char *>data, <void *>from_data, len(self) * sizeof(float))


    def set_vertex_attribute(self, int vertex_n, int attribute_n, float value):
        '''Set attribute number attribute_n of vertex number vertex_n to value.
        '''
        if not vertex_n < self._vert_count:
            raise IndexError()
        cdef int attrib_count = self._attrib_count
        if not attribute_n < attrib_count:
            raise Exception('Attribute out of bounds')
        cdef int start = attrib_count * vertex_n
        cdef float* data = self._data
        data[start + attribute_n] = value

    def add_vertex_attribute(self, int vertex_n, 
        int attribute_n, float value):
        '''Add value to attribute number attribute_n of vertex number vertex_n.
        '''
        if not vertex_n < self._vert_count:
            raise IndexError()
        cdef int attrib_count = self._attrib_count
        if not attribute_n < attrib_count:
            raise Exception('Attribute out of bounds')
        cdef int start = attrib_count * vertex_n
        cdef float* data = self._data
        cdef index = start + attribute_n
        data[index] = data[index] + value

    def mult_vertex_attribute(self, int vertex_n, 
        int attribute_n, float value):
        '''Multiply the value of attribute number attribute_n of vertex number 
        vertex_n by value.
        '''
        if not vertex_n < self._vert_count:
            raise IndexError()
        cdef int attrib_count = self._attrib_count
        if not attribute_n < attrib_count:
            raise Exception('Attribute out of bounds')
        cdef int start = attrib_count * vertex_n
        cdef float* data = self._data
        cdef int index = start + attribute_n
        data[index] = data[index] * value

    def set_all_vertex_attribute(self, int attribute_n, float value):
        '''Set attribute number attribute_n of all vertices to value.
        '''
        cdef int attrib_count = self._attrib_count
        cdef int vert_count = self._vert_count
        if not attribute_n < attrib_count:
            raise Exception('Attribute out of bounds')
        cdef int start
        cdef float* data = self._data
        cdef int i
        cdef int index
        for i from 0 <= i < vert_count:
            start = attrib_count * i
            index = start + attribute_n
            data[index] = value

    def add_all_vertex_attribute(self, int attribute_n, float value):
        '''Add value to attribute number attribute_n of all vertices.
        '''
        cdef int attrib_count = self._attrib_count
        cdef int vert_count = self._vert_count
        if not attribute_n < attrib_count:
            raise Exception('Attribute out of bounds')
        cdef int start
        cdef float* data = self._data
        cdef int i
        cdef int index
        for i from 0 <= i < vert_count:
            start = attrib_count * i
            index = start + attribute_n
            data[index] = data[index] + value

    def mult_all_vertex_attribute(self, int attribute_n, float value):
        '''Multiply the value of attribute number attribute_n of all vertices 
        by value.
        '''
        cdef int attrib_count = self._attrib_count
        cdef int vert_count = self._vert_count
        if not attribute_n < attrib_count:
            raise Exception('Attribute out of bounds')
        cdef int start
        cdef float* data = self._data
        cdef int i
        cdef int index
        for i from 0 <= i < vert_count:
            start = attrib_count * i
            index = start + attribute_n
            data[index] = data[index] * value

    def set_textured_rectangle(self, float width, float height, list uvs):
        '''Prepare a 4 vertex_count, 6 index_count textured quad of size:
        width x height. Normally called internally when creating a VertMesh 
        using size and texture property. The first two attributes will be
        used to store the coordinate of the quad offset from the origin, and 
        the next two will store the UV coordinate data for each vertex.'''
        self.vertex_count = 4
        self.index_count = 6
        self.indices = [0, 1, 2, 2, 3, 0]
        w = .5*width
        h = .5*height
        u0, v0, u1, v1 = uvs
        self[0] = [-w, -h, u0, v0]
        self[1] = [-w, h, u0, v1]
        self[2] = [w, h, u1, v1]
        self[3] = [w, -h, u1, v0]



