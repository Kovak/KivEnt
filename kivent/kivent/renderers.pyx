from kivy.uix.widget import Widget
from kivy.properties import (StringProperty, ListProperty, NumericProperty, 
DictProperty, BooleanProperty, ObjectProperty)
from kivy.graphics import (PushMatrix, PopMatrix, Translate, Quad, Instruction, 
Rotate, Color, Scale, Point, Callback, RenderContext)
from kivy.core.image import Image as CoreImage
from kivy.atlas import Atlas
from kivy.clock import Clock
from kivy.graphics.transformation import Matrix
import json


cdef class VertMeshComponent:
    cdef bool _do_texture
    cdef object _texture
    cdef str _tex_name
    cdef VertMesh _vert_mesh
    cdef CMesh _cmesh

    def __cinit__(self, int vert_data_count, int vert_count, 
        int tri_count, VertMesh vert_mesh=None, list vertices=None, 
        list triangles=None, bool do_texture=False, str texture=None,
        tuple offset=None):
        self._do_texture = do_texture
        self._tex_name = texture
        if texture is not None:
            self._texture = CoreImage(texture).texture
        else:
            self._texture = None
        self._vert_mesh = vertm = VertMesh(
            vert_data_count, vert_count, tri_count)
        if vert_mesh is not None:
            vertm.copy_from_existing(vert_mesh)
        elif triangles is not None and vertices is not None:
            vertm.load_from_python(vertices, triangles)
        if offset is not None:
            vertm.offset_mesh(offset)

    property texture_name:
        def __get__(self):
            return self._tex_name
        def __set__(self, str name):
            self._tex_name = name
            if name is not None:
                self._texture = CoreImage(name).texture
            else:
                self._texture = None


    property vert_mesh:
        def __get__(self):
            return self._vert_mesh

    property tri_count:
        def __get__(self):
            return self._vert_mesh.tri_count

    property vert_count:
        def __get__(self):
            return self._vert_mesh.vert_count

class StaticVertMeshRenderer(GameSystem):
    vertex_data_count = NumericProperty(4)
    shader_source = StringProperty('positionshader.glsl')

    def __init__(self, **kwargs):
        self.canvas = RenderContext(use_parent_projection=True)
        if 'shader_source' in kwargs:
            self.canvas.shader.source = kwargs.get('shader_source')
        super(StaticVertMeshRenderer, self).__init__(**kwargs)
        self.redraw = Clock.create_trigger(self.trigger_redraw)
        self.vertex_format = self.calculate_vertex_format()

    def on_shader_source(self, instance, value):
        self.canvas.shader.source = value

    def on_vertex_data_count(self, instance, value):
        self.vertex_format = self.calculate_vertex_format()

    def trigger_redraw(self, dt):
        cdef list entity_ids = self.entity_ids
        cdef int entity_id
        cdef object redraw_entity = self.redraw_entity
        for entity_id in entity_ids:
            self.redraw_entity(entity_id)

    def calculate_vertex_format(self):
        '''Function used internally to calculate the vertex_format'''
        cdef int vertex_data_count = self.vertex_data_count
        vertex_format = [
            ('v0', 1, 'float'),
            ('v1', 1, 'float'),
            ('v2', 1, 'float'),
            ('v3', 1, 'float'),
            ]
        ve = vertex_format.extend
        if vertex_data_count > 4:
            ve([
                ('v4', 1, 'float'),
                ('v5', 1, 'float'),
                ('v6', 1, 'float'),
                ('v7', 1, 'float'),
                ])
        if vertex_data_count > 8:
            ve([
                ('v8', 1, 'float'),
                ('v9', 1, 'float'),
                ('v10', 1, 'float'),
                ('v11', 1, 'float'),
                ])
        if vertex_data_count > 12:
            ve([
                ('v12', 1, 'float'),
                ('v13', 1, 'float'),
                ('v14', 1, 'float'),
                ('v15', 1, 'float'),
                ])
        return vertex_format

    def create_component(self, object entity, args):
        super(StaticVertMeshRenderer, self).create_component(
            entity, args)

    def generate_component(self, dict entity_component_dict):
        cdef int vert_data_count = entity_component_dict['vert_data_count']
        cdef int vert_count = entity_component_dict['vert_count']
        cdef int tri_count = entity_component_dict['tri_count']
        cdef list vertices 
        cdef list triangles
        cdef bool do_texture
        cdef str texture
        cdef tuple offset
        cdef dict kwargs = {}
        cdef VertMesh vert_mesh
        if 'triangles' in entity_component_dict and (
            'vertices' in entity_component_dict):
            triangles = entity_component_dict['triangles']
            vertices = entity_component_dict['vertices']
            kwargs['vertices'] = vertices
            kwargs['triangles'] = triangles
        elif 'vert_mesh' in entity_component_dict:
            vert_mesh = entity_component_dict['vert_mesh']
            kwargs['vert_mesh'] = vert_mesh
        if 'do_texture' in entity_component_dict:
            do_texture = entity_component_dict['do_texture']
            kwargs['do_texture'] = do_texture
        if 'texture' in entity_component_dict:
            texture = entity_component_dict['texture']
            kwargs['texture'] = texture
        if 'offset' in entity_component_dict:
            offset = entity_component_dict['offset']
            kwargs['offset'] = offset
        cdef VertMeshComponent new_component
        new_component = VertMeshComponent.__new__(VertMeshComponent, 
            vert_data_count, vert_count, tri_count, **kwargs)
        
        self.draw_vert_mesh(new_component)
        return new_component

    def redraw_entity(self, int entity_id):
        cdef object gameworld = self.gameworld
        cdef list entities = gameworld.entities
        cdef str system_id = self.system_id
        cdef object entity = entities[entity_id]
        cdef VertMeshComponent vert_comp = getattr(entity, system_id)
        self.remove_vert_mesh(vert_comp)
        self.draw_vert_mesh(vert_comp)

    def draw_vert_mesh(self, VertMeshComponent vert_comp):
        cdef CMesh cmesh
        cdef VertMesh vert_mesh = vert_comp._vert_mesh
        vert_mesh.generate_gl_verts()
        vert_mesh.generate_gl_indices()
        with self.canvas:
            cmesh = CMesh(fmt=self.vertex_format,
                mode='triangles')
        if vert_comp._do_texture:
            cmesh.source = vert_comp._tex_name
        cmesh._vertices = vert_mesh._gl_verts
        cmesh._indices = vert_mesh._gl_indices
        cmesh.vcount = vert_mesh.vert_count * vert_mesh._real_count
        cmesh.icount = vert_mesh.tri_count * 3
        cmesh.flag_update()
        vert_comp._cmesh = cmesh

    def remove_vert_mesh(self, VertMeshComponent vert_comp):
        cdef CMesh cmesh = vert_comp._cmesh
        self.canvas.remove(cmesh)
        vert_comp._cmesh = None

    def remove_entity(self, int entity_id):
        cdef object gameworld = self.gameworld
        cdef list entities = gameworld.entities
        cdef str system_id = self.system_id
        cdef object entity = entities[entity_id]
        cdef VertMeshComponent vert_comp = getattr(entity, system_id)
        self.remove_vert_mesh(vert_comp)
        super(StaticVertMeshRenderer, self).remove_entity(entity_id)




cdef class RenderComponent:
    cdef bool _render
    cdef bool _on_screen
    cdef str _texture
    cdef float _width
    cdef float _height

    def __cinit__(self, bool render, bool on_screen, str texture, 
        float width, float height):
        self._render = render
        self._on_screen = on_screen
        self._texture = texture
        self._width = width
        self._height = height

    property texture:
        def __get__(self):
            return self._texture
        def __set__(self, str value):
            self._texture = value

    property render:
        def __get__(self):
            return self._render
        def __set__(self, bool value):
            self._render = value

    property on_screen:
        def __get__(self):
            return self._on_screen
        def __set__(self, bool value):
            self._on_screen = value

    property width:
        def __get__(self):
            return self._width
        def __set__(self, float value):
            self._width = value

    property height:
        def __get__(self):
            return self._height
        def __set__(self, float value):
            self._height = value

cdef class CRenderer:
    cdef void* frame_info_ptr
    cdef void* indice_info_ptr
    cdef long i_count
    cdef long v_count

    def __dealloc__(self):
        frame_info = <float *>self.frame_info_ptr
        if frame_info != NULL:
            free(frame_info)
            frame_info = NULL
        indice_info = <unsigned short *>self.indice_info_ptr
        if indice_info != NULL:
            free(indice_info)
            indice_info = NULL


class Renderer(GameSystem):
    '''The basic KivEnt renderer it draws every entity every frame.

    **Attributes:**
        **do_rotate** (BooleanProperty): Determines whether or not vertex 
        format will have a float for rotate

        **do_color** (BooleanProperty): Determines whether or not vertex 
        format will have 4 floats for rgba color

        **do_scale** (BooleanProperty): Determines whether or not vertex 
        format will have a float for scale

        **mesh** (ObjectProperty): reference to the active CMesh instruction 
        for the Renderer

        **atlas_dir** (StringProperty): Path to the directory containing the 
        .atlas this renderer will lookup texture data from.

        **atlas** (StringProperty): Name of the .atlas to be used, do not 
        include the '.atlas' in the name.

        **shader_source** (StringProperty): Path to the .glsl to be used, do 
        include '.glsl' in the name. You must ensure that your shader matches 
        your vertex format or you will have problems

        **redraw** (Clock Trigger): A trigger that can be used to request a 
        redraw of canvas next frame, will never be called more than once a 
        frame. 

        **vertex_format** (dict): describes format of data sent to shaders,
        generated automatically based on do_rotate, do_scale, do_color

        **redraw_mesh** (bool): Used internally to determine whether or not to 
        recreate mesh

        **crenderer** (object): cython renderer used internally to hold c data

        **uv_dict** (dict): dictionary containing information about texture 
        uv information

        **on_screen_last_frame** (list): Used to cache data about what was on 
        screen last frame. Only used for DynamicRenderer at the moment
    '''
    system_id = StringProperty('renderer')
    updateable = BooleanProperty(True)
    renderable = BooleanProperty(True)
    do_rotate = BooleanProperty(False)
    do_color = BooleanProperty(False)
    do_scale = BooleanProperty(False)
    mesh = ObjectProperty(None, allownone=True)
    atlas_dir = StringProperty(None)
    atlas = StringProperty(None)
    shader_source = StringProperty('positionshader.glsl')


    def __init__(self, **kwargs):
        self.canvas = RenderContext(
            use_parent_projection=True)
        if 'shader_source' in kwargs:
            self.canvas.shader.source = kwargs.get('shader_source')
        super(Renderer, self).__init__(**kwargs)
        self.redraw = Clock.create_trigger(self.trigger_redraw)
        self.vertex_format = self.calculate_vertex_format()
        self.redraw_mesh = True
        self.crenderer = CRenderer()
        self.uv_dict = {}
        self.on_screen_last_frame = []

    def on_shader_source(self, instance, value):
        self.canvas.shader.source = value

    def on_atlas(self, instance, value):
        if value and self.atlas_dir:
            self.uv_dict = self.return_uv_coordinates(
                value + '.atlas', value + '-0.png', self.atlas_dir)

    def on_atlas_dir(self, instance, value):
        if value and self.atlas:
            self.uv_dict = self.return_uv_coordinates(
                self.atlas + '.atlas', self.atlas + '-0.png', value)

    def on_do_rotate(self, instance, value):
        self.vertex_format = self.calculate_vertex_format()

    def on_do_scale(self, instance, value):
        self.vertex_format = self.calculate_vertex_format()

    def on_do_color(self, instance, value):
        self.vertex_format = self.calculate_vertex_format()

    def return_uv_coordinates(self, atlas_name, atlas_page, atlas_dir):
        '''Function used internally to load the uv_dict informations
        will return a list of [u0, v0, u1, v1, texture_width, texture_height] 
        for key of texture_name'''
        uv_dict = {}
        uv_dict['main_texture'] = atlas = CoreImage(
            atlas_dir + atlas_page).texture
        size = atlas.size
        uv_dict['atlas_size'] = atlas_size = (float(size[0]), float(size[1]))
        w, h = atlas_size
        with open(atlas_dir + atlas_name, 'r') as fd:
            atlas_data = json.load(fd)
        atlas_content = atlas_data[atlas_page]
        for texture_name in atlas_content:
            data = atlas_content[texture_name]
            x1, y1 = data[0], data[1]
            x2, y2 = x1 + data[2], y1 + data[3]
            uv_dict[
                texture_name] = x1/w, 1.-y1/h, x2/w, 1.-y2/h, data[2], data[3]
        return uv_dict

    def calculate_vertex_format(self):
        '''Function used internally to calculate the vertex_format'''
        vertex_format = [
            ('vPosition', 2, 'float'),
            ('vTexCoords0', 2, 'float'),
            ('vCenter', 2, 'float')
            ]
        if self.do_rotate:
            vertex_format.append(('vRotation', 1, 'float'))
        if self.do_color:
            vertex_format.append(('vColor', 4, 'float'))
        if self.do_scale:
            vertex_format.append(('vScale', 1, 'float'))
        self.redraw()
        return vertex_format

    def trigger_redraw(self, dt):
        self.clear_mesh()
        cdef list entity_ids = self.update_render_state()
        self.draw_mesh(entity_ids)

    def draw_mesh(self, list entities_to_draw):
        '''Function used internally to draw mesh'''
        cdef object gameworld = self.gameworld
        cdef list entities = gameworld.entities
        cdef str system_id = self.system_id
        cdef list entity_ids = entities_to_draw
        cdef CRenderer cr = self.crenderer
        cdef CMesh cmesh
        cdef bool do_color = self.do_color
        cdef bool do_scale = self.do_scale
        cdef bool do_rotate = self.do_rotate
        cdef object entity
        cdef RenderComponent system_data
        vertex_format = self.vertex_format
        cdef int vert_data_count = 6
        if do_scale:
            vert_data_count += 1
        if do_rotate:
            vert_data_count += 1
        if do_color:
            vert_data_count += 4
        cdef int num_elements = len(entity_ids)
        cdef int i
        cdef int entity_id
        cdef void* indices_ptr
        cdef float* frame_info
        cdef unsigned short * indice_info
        frame_info = <float *>cr.frame_info_ptr
        if frame_info != NULL:
            free(frame_info)
            frame_info = NULL
        indice_info = <unsigned short *>cr.indice_info_ptr
        if indice_info != NULL:
            free(indice_info)
            indice_info = NULL
        cr.indice_info_ptr = indices_ptr = <void *>malloc(
            sizeof(unsigned short) * num_elements * 6)
        cdef void* frame_ptr
        cr.frame_info_ptr = frame_ptr = <void *>malloc(sizeof(float) * 
            num_elements * 4 * vert_data_count)
        if not frame_ptr or not indices_ptr:
            raise MemoryError()
        cdef unsigned short * indices_info = <unsigned short *>indices_ptr
        frame_info = <float *>frame_ptr
        cdef dict uv_dict = self.uv_dict
        cdef int offset 
        cdef int indice_offset
        cr.v_count = <long>num_elements * 4 * vert_data_count
        cr.i_count = <long>num_elements * 6
        cdef int index
        cdef float rotate
        cdef float x, y
        cdef float x0, y0, x1, y1
        cdef float w, h
        cdef int fr_index
        cdef ColorComponent color_comp
        cdef PositionComponent pos_comp
        cdef ScaleComponent scale_comp
        cdef RotateComponent rot_comp
        cdef float scale
        cdef float r, g, b, a
        for i in range(num_elements):
            entity_id = entity_ids[i]
            entity = entities[entity_id]
            offset = 4 * i
            indice_offset = i*6
            index = 4 * vert_data_count * i
            indices_info[indice_offset] = 0 + offset
            indices_info[indice_offset+1] = 1 + offset
            indices_info[indice_offset+2] = 2 + offset
            indices_info[indice_offset+3] = 2 + offset
            indices_info[indice_offset+4] = 3 + offset
            indices_info[indice_offset+5] = 0 + offset
            system_data = getattr(entity, system_id)
            if system_data._render:
                pos_comp = entity.position
                tex_choice = system_data._texture
                uv = uv_dict[tex_choice]
                w = system_data._width
                h = system_data._height
                x0, y0 = uv[0], uv[1]
                x1, y1 = uv[2], uv[3]
                x, y = pos_comp._x, pos_comp._y
                frame_info[index] = -w
                frame_info[index+1] = -h
                frame_info[index+2] = x0
                frame_info[index+3] = y0
                frame_info[index+4] = x
                frame_info[index+5] = y
                frame_info[index+vert_data_count] = w
                frame_info[index+vert_data_count+1] = -h
                frame_info[index+vert_data_count+2] = x1
                frame_info[index+vert_data_count+3] = y0
                frame_info[index+vert_data_count+4] = x
                frame_info[index+vert_data_count+5] = y
                frame_info[index+2*vert_data_count] = w
                frame_info[index+2*vert_data_count+1] = h
                frame_info[index+2*vert_data_count+2] = x1
                frame_info[index+2*vert_data_count+3] = y1
                frame_info[index+2*vert_data_count+4] = x
                frame_info[index+2*vert_data_count+5] = y
                frame_info[index+3*vert_data_count] = -w
                frame_info[index+3*vert_data_count+1] = h
                frame_info[index+3*vert_data_count+2] = x0
                frame_info[index+3*vert_data_count+3] = y1
                frame_info[index+3*vert_data_count+4] = x
                frame_info[index+3*vert_data_count+5] = y
                fr_index = 6
                if do_rotate:
                    rot_comp = entity.rotate
                    rotate = rot_comp._r
                    frame_info[index+fr_index] = rotate
                    frame_info[index+vert_data_count+fr_index] = rotate
                    frame_info[index+2*vert_data_count+fr_index] = rotate
                    frame_info[index+3*vert_data_count+fr_index] = rotate
                    fr_index += 1
                if do_color:
                    color_comp = entity.color
                    r = color_comp._r
                    g = color_comp._g
                    b = color_comp._b
                    a = color_comp._a
                    frame_info[index+fr_index] = r
                    frame_info[index+vert_data_count+fr_index] = r
                    frame_info[index+2*vert_data_count+fr_index] = r
                    frame_info[index+3*vert_data_count+fr_index] = r
                    fr_index += 1
                    frame_info[index+fr_index] = g
                    frame_info[index+vert_data_count+fr_index] = g
                    frame_info[index+2*vert_data_count+fr_index] = g
                    frame_info[index+3*vert_data_count+fr_index] = g
                    fr_index += 1
                    frame_info[index+fr_index] = b
                    frame_info[index+vert_data_count+fr_index] = b
                    frame_info[index+2*vert_data_count+fr_index] = b
                    frame_info[index+3*vert_data_count+fr_index] = b
                    fr_index += 1
                    frame_info[index+fr_index] = a
                    frame_info[index+vert_data_count+fr_index] = a
                    frame_info[index+2*vert_data_count+fr_index] = a
                    frame_info[index+3*vert_data_count+fr_index] = a
                    fr_index += 1
                if do_scale:
                    scale_comp = entity.scale
                    scale = scale_comp._s
                    frame_info[index+fr_index] = scale
                    frame_info[index+vert_data_count+fr_index] = scale
                    frame_info[index+2*vert_data_count+fr_index] = scale
                    frame_info[index+3*vert_data_count+fr_index] = scale
                    fr_index += 1
        if self.redraw_mesh:
            with self.canvas:
                cmesh = CMesh(fmt=vertex_format,
                    mode='triangles',
                    texture=uv_dict['main_texture'])
                self.mesh = cmesh
                self.redraw_mesh = False
        cmesh = self.mesh
        cmesh._vertices = cr.frame_info_ptr
        cmesh._indices = cr.indice_info_ptr
        cmesh.vcount = cr.v_count
        cmesh.icount = cr.i_count
        cmesh.flag_update()

    def update(self, dt):
        cdef list entity_ids = self.update_render_state()
        self.draw_mesh(entity_ids)

    def update_render_state(self):
        '''Returns a list of entity_ids to draw for the current screen'''
        cdef list entity_ids = self.entity_ids
        return entity_ids

    def clear_mesh(self):
        '''Used internally when redraw is called'''
        if self.mesh is not None and not self.redraw_mesh:
            self.canvas.remove(self.mesh)
            self.redraw_mesh = True

    def remove_entity(self, int entity_id):
        super(Renderer, self).remove_entity(entity_id)
        self.redraw()

    def create_component(self, object entity, args):
        super(Renderer, self).create_component(
            entity, args)
        self.redraw()

    def generate_component(self, dict entity_component_dict):
        '''Renderers take in a dict containing a string 'texture' corresponding
        to the name of the texture in the atlas, and a size tuple of width, 
        height. RenderComponent's have a texture string, a render boolean 
        that controls whether or not they will be drawn, an on_screen boolean.
        on_screen returns True always for Renderer and StaticQuadRenderer.
        For DynamicRenderer, on_screen only returns True if that entity is
        within Window bounds.'''
        texture = entity_component_dict['texture']
        size = entity_component_dict['size']
        new_component = RenderComponent.__new__(RenderComponent, True, True, 
            texture, size[0], size[1])
        return new_component


class DynamicRenderer(Renderer):
    '''DynamicRenderer is designed to work with the cymunk_physics system,
    and used queries of the physics to determine which entities to draw
    rather than drawing everything. If you query your RenderComponent
    for a DynamicRenderer the on_screen property will return True only if
    that entity is currently within the Window bounds.

    **Attributes:**
        **physics_system** (StringProperty): You must provide the system_id 
        for your physics system.

    '''
    system_id = StringProperty('dynamic_renderer')
    do_rotate = BooleanProperty(True)
    physics_system = StringProperty('cymunk_physics')



    def update_render_state(self):
        cdef object parent = self.gameworld
        cdef dict systems = parent.systems
        cdef list entities = parent.entities
        cdef str system_id = self.system_id
        cdef list entity_ids = self.entity_ids
        cdef object physics_system
        cdef list on_screen
        cdef set last_on_screen
        last_on_screen = set(self.on_screen_last_frame)
        if self.physics_system in systems:
            physics_system = systems[self.physics_system]
            on_screen = [x for x in physics_system.on_screen_result]
        else:
            on_screen = []
        set_on_screen = set(on_screen)
        new_to_screen = set_on_screen - last_on_screen
        left_screen = last_on_screen - set_on_screen
        cdef object entity
        cdef RenderComponent system_data
        cdef list to_render = []
        tr_a = to_render.append
        for entity_id in new_to_screen:
            entity = entities[entity_id]
            try:
                system_data = getattr(entity, system_id)
                system_data._on_screen = True
            except:
                continue
        for entity_id in left_screen:
            entity = entities[entity_id]
            try:
                system_data = getattr(entity, system_id)
                system_data._on_screen = False
            except:
                continue
        for entity_id in on_screen:
            entity = entities[entity_id]
            try:
                system_data = getattr(entity, system_id)
                if system_data._render:
                    tr_a(entity_id)
            except:
                continue
        self.on_screen_last_frame = on_screen
        return to_render


class StaticQuadRenderer(Renderer):
    '''The StaticQuadRenderer has no update function, and does not render
    except for when entities are added or removed from the System. This is 
    perfect for static objects.'''
    
    system_id = StringProperty('static_renderer')
    shader_source = StringProperty('positionshader.glsl')
    updateable = BooleanProperty(False)

    def update(self, dt):
        pass


class QuadRendererNoTextures(Renderer):
    '''This renderer renders colored quads without textures.'''

    def calculate_vertex_format(self):
        vertex_format = [
            ('vPosition', 2, 'float'),
            ('vCenter', 2, 'float'),
            ('vColor', 4, 'float')
            ]
        self.redraw()
        return vertex_format

    def generate_component(self, dict entity_component_dict):
        size = entity_component_dict['size']
        new_component = RenderComponent.__new__(RenderComponent, True, True, None,
            size[0], size[1])
        return new_component

    def draw_mesh(self, list entities_to_draw):
        cdef object gameworld = self.gameworld
        cdef list entities = gameworld.entities
        cdef str system_id = self.system_id
        cdef list entity_ids = entities_to_draw
        cdef CRenderer cr = self.crenderer
        cdef CMesh cmesh
        cdef object entity
        cdef RenderComponent system_data
        vertex_format = self.vertex_format
        cdef int vert_data_count = 8
        cdef int num_elements = len(entity_ids)
        cdef int i
        cdef int entity_id
        cdef void* indices_ptr
        cdef float* frame_info
        cdef unsigned short * indice_info
        frame_info = <float *>cr.frame_info_ptr
        if frame_info != NULL:
            free(frame_info)
            frame_info = NULL
        indice_info = <unsigned short *>cr.indice_info_ptr
        if indice_info != NULL:
            free(indice_info)
            indice_info = NULL
        cr.indice_info_ptr = indices_ptr = <void *>malloc(
            sizeof(unsigned short) * num_elements * 6)
        cdef void* frame_ptr
        cr.frame_info_ptr = frame_ptr = <void *>malloc(sizeof(float) * 
            num_elements * 4 * vert_data_count)
        if not frame_ptr or not indices_ptr:
            raise MemoryError()
        cdef unsigned short * indices_info = <unsigned short *>indices_ptr
        frame_info = <float *>frame_ptr
        cdef int offset 
        cdef int indice_offset
        cr.v_count = <long>num_elements * 4 * vert_data_count
        cr.i_count = <long>num_elements * 6
        cdef int index
        cdef float rotate
        cdef float x, y
        cdef float w, h
        cdef int fr_index
        cdef PositionComponent position
        cdef ColorComponent color
        cdef float r, g, b, a
        for i in range(num_elements):
            entity_id = entity_ids[i]
            entity = entities[entity_id]
            offset = 4 * i
            indice_offset = i*6
            index = 4 * vert_data_count * i
            indices_info[indice_offset] = 0 + offset
            indices_info[indice_offset+1] = 1 + offset
            indices_info[indice_offset+2] = 2 + offset
            indices_info[indice_offset+3] = 2 + offset
            indices_info[indice_offset+4] = 3 + offset
            indices_info[indice_offset+5] = 0 + offset
            system_data = getattr(entity, system_id)
            if system_data._render:
                position = entity.position
                w, h = system_data._width, system_data._height
                x, y = position._x, position._y
                frame_info[index] = -w
                frame_info[index+1] = -h
                frame_info[index+2] = x
                frame_info[index+3] = y
                frame_info[index+vert_data_count] = w
                frame_info[index+vert_data_count+1] = -h
                frame_info[index+vert_data_count+2] = x
                frame_info[index+vert_data_count+3] = y
                frame_info[index+2*vert_data_count] = w
                frame_info[index+2*vert_data_count+1] = h
                frame_info[index+2*vert_data_count+2] = x
                frame_info[index+2*vert_data_count+3] = y
                frame_info[index+3*vert_data_count] = -w
                frame_info[index+3*vert_data_count+1] = h
                frame_info[index+3*vert_data_count+2] = x
                frame_info[index+3*vert_data_count+3] = y
                fr_index = 4
                color = entity.color
                r = color._r
                g = color._g
                b = color._b
                a = color._a
                frame_info[index+fr_index] = r
                frame_info[index+vert_data_count+fr_index] = r
                frame_info[index+2*vert_data_count+fr_index] = r
                frame_info[index+3*vert_data_count+fr_index] = r
                fr_index += 1
                frame_info[index+fr_index] = g
                frame_info[index+vert_data_count+fr_index] = g
                frame_info[index+2*vert_data_count+fr_index] = g
                frame_info[index+3*vert_data_count+fr_index] = g
                fr_index += 1
                frame_info[index+fr_index] = b
                frame_info[index+vert_data_count+fr_index] = b
                frame_info[index+2*vert_data_count+fr_index] = b
                frame_info[index+3*vert_data_count+fr_index] = b
                fr_index += 1
                frame_info[index+fr_index] = a
                frame_info[index+vert_data_count+fr_index] = a
                frame_info[index+2*vert_data_count+fr_index] = a
                frame_info[index+3*vert_data_count+fr_index] = a
                fr_index += 1
        mesh = self.mesh
        if mesh == None:
            with self.canvas:
                cmesh = CMesh(fmt=vertex_format,
                    mode='triangles')
                self.mesh = cmesh
        cmesh = self.mesh
        cmesh._vertices = cr.frame_info_ptr
        cmesh._indices = cr.indice_info_ptr
        cmesh.vcount = cr.v_count
        cmesh.icount = cr.i_count
        cmesh.flag_update()