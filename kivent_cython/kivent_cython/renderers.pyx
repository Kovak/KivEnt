from kivy.uix.widget import Widget
from kivy.properties import (StringProperty, ListProperty, NumericProperty, 
DictProperty, BooleanProperty, ObjectProperty)
from kivy.graphics import (PushMatrix, PopMatrix, Translate, Quad, Instruction, 
Rotate, Color, Scale, Point, Callback)
from kivy.core.image import Image as CoreImage
import math
from kivy.atlas import Atlas
from quadtree import QuadTree
from kivy.clock import Clock



class PointRenderer(GameSystem):
    system_id = StringProperty('point_sprite_renderer')
    render_information_from = StringProperty('position')
    context_information_from = StringProperty(None)
    updateable = BooleanProperty(True)
    renderable = BooleanProperty(True)
    do_rotate = BooleanProperty(False)
    do_color = BooleanProperty(False)
    do_scale = BooleanProperty(False)
    image_mode = StringProperty('image')
    textures = DictProperty(None)

    def __init__(self, **kwargs):
        super(PointRenderer, self).__init__(**kwargs)

    def generate_component_data(self, dict entity_component_dict):
        entity_component_dict['translate'] = None
        entity_component_dict['point'] = None
        if self.do_scale:
            entity_component_dict['scale'] = None
        if self.do_rotate:
            entity_component_dict['rotate'] = None
        if self.do_color:
            entity_component_dict['color'] = None
        
        return entity_component_dict

    def load_texture(self, str texture_str):
        textures = self.textures
        if texture_str not in textures:
            textures[texture_str] = CoreImage(texture_str).texture
        texture = textures[texture_str]
        return texture

    def load_texture_from_atlas(self, str atlas_address, str key):
        textures = self.textures
        if atlas_address not in textures:
            textures[atlas_address] = Atlas(atlas_address)
        texture = textures[atlas_address]
        return texture[key]

    def generate_entity_component_dict(self, int entity_id):
        entity = self.gameworld.entities[entity_id]
        entity_system_dict = entity[self.system_id]
        entity_component_dict = {'texture': entity_system_dict['texture'], 
        'render': entity_system_dict['render']}
        return entity_component_dict

    def remove_entity_from_canvas(self, int entity_id):
        self.canvas.remove_group(str(entity_id))
        entity = self.gameworld.entities[entity_id]
        system_data = entity[self.system_id]
        system_data['render'] = False

    def draw_entity(self, int entity_id):
        cdef object parent = self.gameworld
        cdef dict entity = parent.entities[entity_id]
        cdef dict system_data = entity[self.system_id]
        cdef dict render_information = entity[self.render_information_from]
        cdef dict context_information
        if self.do_scale or self.do_color:
            context_information = entity[self.context_information_from]
        if self.image_mode == 'image':
            texture = self.load_texture(system_data['texture'])
        elif self.image_mode == 'atlas':
            texture = self.load_texture_from_atlas(system_data['texture'], 
                system_data['texture_key'])
        cdef tuple size = (texture.size[0] * .5, texture.size[1] *.5)
        
        if self.do_scale:
            system_data['size'] = (size[0] * context_information['scale_x'], 
                size[1] * context_information['scale_y'])
        else:
            system_data['size'] = size
        camera_pos = parent.systems[self.viewport].camera_pos
        with self.canvas:
            group_id = str(entity_id)
            PushMatrix(group=group_id)
            system_data['translate'] = Translate(group=group_id)
            if self.do_rotate:
                system_data['rotate'] = Rotate(group=group_id)
                system_data['rotate'].angle = render_information['angle']
            if self.do_scale:
                system_data['scale'] = Scale(group=group_id)
                system_data['scale'].x = context_information['scale_x'] * size[0]
                system_data['scale'].y = context_information['scale_y'] * size[1]
            if self.do_color:
                system_data['color'] = Color(group=group_id)
                system_data['color'].rgba = context_information['color']
            system_data['point'] = Point(texture = texture, points = (0, 0), 
                pointsize=size[0], group=group_id)
            system_data['translate'].xy = (render_information['position'][0] + camera_pos[0], 
            render_information['position'][1] + camera_pos[1])

            PopMatrix(group=group_id)
        system_data['render'] = True

    def update_render_state(self):
        cdef object parent = self.gameworld
        cdef object viewport = parent.systems[self.viewport]
        camera_pos = viewport.camera_pos
        camera_size = viewport.size
        pos = self.pos
        cdef str system_id = self.system_id
        cdef list entities = parent.entities
        cdef dict system_data
        cdef dict render_information
        cdef tuple size
        cdef tuple position
        cdef dict entity
        for entity_id in self.entity_ids:
            entity = entities[entity_id]
            system_data = entity[system_id]
            render_information = entity[self.render_information_from]
            size = system_data['size']
            if size == None:
                print 'problem'
            position = render_information['position']
            if (position[0] + size[0] > pos[0] - camera_pos[0] and position[0] 
                - size[0] < pos[0] - camera_pos[0] + camera_size[0]):
                if (position[1] + size[1] > pos[1] - camera_pos[1] and position[1] - 
                size[1] < pos[1] - camera_pos[1] + camera_size[1]):
                    if not system_data['render']:
                        self.draw_entity(entity_id)
                else:
                    if system_data['render']:
                        self.remove_entity_from_canvas(entity_id)
            else:
                if system_data['render']:                  
                    self.remove_entity_from_canvas(entity_id)

    def render(self):
        cdef object parent = self.gameworld
        cdef list entities = parent.entities
        cdef str system_id = self.system_id
        do_color = self.do_color
        do_scale = self.do_scale
        do_rotate = self.do_rotate
        camera_pos = parent.systems[self.viewport].camera_pos
        cdef str render_information_from = self.render_information_from
        cdef str context_information_from
        if do_scale or do_color:
            context_information_from = self.context_information_from

        cdef dict entity
        cdef dict system_data
        cdef dict render_information
        cdef dict context_information

        for entity_id in self.entity_ids:
            entity = entities[entity_id]
            if system_id not in entity:
                continue
            system_data = entity[system_id]
            if system_data['render']:
                render_information = entity[render_information_from]
                if do_scale or do_color:
                    context_information = entity[context_information_from]
                system_data['translate'].xy = (render_information['position'][0] + 
                camera_pos[0], render_information['position'][1] + camera_pos[1])
                if do_rotate:
                    system_data['rotate'].angle = render_information['angle']
                if do_scale:
                    system_data['scale'].x = context_information['scale_x']
                    system_data['scale'].y = context_information['scale_y']
                if do_color:
                    system_data['color'].rgba = context_information['color']
            
    def update(self, dt):
        self.update_render_state()
        self.render()
        
    def remove_entity(self, int entity_id):
        self.remove_entity_from_canvas(entity_id)
        super(PointRenderer, self).remove_entity(entity_id)


class QuadRenderer(GameSystem):
    system_id = StringProperty('position_renderer')
    render_information_from = StringProperty('position')
    context_information_from = StringProperty(None)
    updateable = BooleanProperty(True)
    renderable = BooleanProperty(True)
    do_rotate = BooleanProperty(False)
    do_color = BooleanProperty(False)
    do_scale = BooleanProperty(False)
    image_mode = StringProperty('image')
    textures = DictProperty(None)

    def __init__(self, **kwargs):
        super(QuadRenderer, self).__init__(**kwargs)

    def generate_component_data(self, dict entity_component_dict):
        entity_component_dict['translate'] = None
        entity_component_dict['quad'] = None
        if self.do_rotate:
            entity_component_dict['rotate'] = None
        if self.do_color:
            entity_component_dict['color'] = None
        if self.do_scale:
            entity_component_dict['scale'] = None
        return entity_component_dict

    def load_texture(self, str texture_str):
        textures = self.textures
        if texture_str not in textures:
            textures[texture_str] = CoreImage(texture_str).texture
        texture = textures[texture_str]
        return texture

    def load_texture_from_atlas(self, str atlas_address, str key):
        textures = self.textures
        if atlas_address not in textures:
            textures[atlas_address] = Atlas(atlas_address)
        texture = textures[atlas_address]
        return texture[key]

    def generate_entity_component_dict(self, int entity_id):
        entity = self.gameworld.entities[entity_id]
        entity_system_dict = entity[self.system_id]
        entity_component_dict = {'texture': entity_system_dict['texture'], 
        'render': entity_system_dict['render']}
        return entity_component_dict

    def remove_entity_from_canvas(self, int entity_id):
        self.canvas.remove_group(str(entity_id))
        entity = self.gameworld.entities[entity_id]
        system_data = entity[self.system_id]
        system_data['render'] = False

    def draw_entity(self, int entity_id):
        cdef object parent = self.gameworld
        cdef dict entity = parent.entities[entity_id]
        cdef dict system_data = entity[self.system_id]
        cdef dict render_information = entity[self.render_information_from]
        cdef dict context_information
        if self.do_scale or self.do_color:
            context_information = entity[self.context_information_from]
        if self.image_mode == 'image':
            texture = self.load_texture(system_data['texture'])
        elif self.image_mode == 'atlas':
            texture = self.load_texture_from_atlas(system_data['texture'], system_data['texture_key'])
        cdef tuple size = (texture.size[0] * .5, texture.size[1] *.5)
        if self.do_scale:
            system_data['size'] = (size[0] * context_information['scale_x'], size[1] * context_information['scale_y'])
        else:
            system_data['size'] = size

        camera_pos = parent.systems[self.viewport].camera_pos
        with self.canvas:
            group_id = str(entity_id)
            PushMatrix(group=group_id)
            system_data['translate'] = Translate(group=group_id)
            if self.do_rotate:
                system_data['rotate'] = Rotate(group=group_id)
                system_data['rotate'].angle = render_information['angle']
            if self.do_scale:
                system_data['scale'] = Scale(group=group_id)
                system_data['scale'].x = context_information['scale_x']
                system_data['scale'].y = context_information['scale_y']
            if self.do_color:
                system_data['color'] = Color(group=group_id)
                system_data['color'].rgba = context_information['color']
            system_data['quad'] = Quad(texture = texture, points = (-size[0], 
                -size[1], size[0], -size[1],
                size[0], size[1], -size[0], size[1]), group=group_id)
            system_data['translate'].xy = (render_information['position'][0] + camera_pos[0], 
            render_information['position'][1] + camera_pos[1])

            PopMatrix(group=group_id)
        system_data['render'] = True

    def update_render_state(self):
        cdef object parent = self.gameworld
        cdef object viewport = parent.systems[self.viewport]
        camera_pos = viewport.camera_pos
        camera_size = viewport.size
        pos = self.pos
        cdef str system_id = self.system_id
        cdef list entities = parent.entities
        cdef dict system_data
        cdef dict render_information
        cdef tuple size
        cdef tuple position
        cdef dict entity
        for entity_id in self.entity_ids:
            entity = entities[entity_id]
            system_data = entity[system_id]
            render_information = entity[self.render_information_from]
            size = system_data['size']
            if size == None:
                print 'problem'
            position = render_information['position']
            if (position[0] + size[0] > pos[0] - camera_pos[0] and position[0] 
                - size[0] < pos[0] - camera_pos[0] + camera_size[0]):
                if (position[1] + size[1] > pos[1] - camera_pos[1] and position[1] - 
                size[1] < pos[1] - camera_pos[1] + camera_size[1]):
                    if not system_data['render']:
                        self.draw_entity(entity_id)
                else:
                    if system_data['render']:
                        self.remove_entity_from_canvas(entity_id)
            else:
                if system_data['render']:                  
                    self.remove_entity_from_canvas(entity_id)

    def render(self):
        cdef object parent = self.gameworld
        cdef list entities = parent.entities
        cdef str system_id = self.system_id
        do_color = self.do_color
        do_scale = self.do_scale
        do_rotate = self.do_rotate
        camera_pos = parent.systems[self.viewport].camera_pos
        cdef str render_information_from = self.render_information_from
        cdef str context_information_from
        if do_scale or do_color:
            context_information_from = self.context_information_from

        cdef dict entity
        cdef dict system_data
        cdef dict render_information
        cdef dict context_information

        for entity_id in self.entity_ids:
            entity = entities[entity_id]
            if system_id not in entity:
                continue
            system_data = entity[system_id]
            if system_data['render']:
                render_information = entity[render_information_from]
                if do_scale or do_color:
                    context_information = entity[context_information_from]
                system_data['translate'].xy = (render_information['position'][0] + 
                camera_pos[0], render_information['position'][1] + camera_pos[1])
                if do_rotate:
                    system_data['rotate'].angle = render_information['angle']
                if do_scale:
                    system_data['scale'].x = context_information['scale_x']
                    system_data['scale'].y = context_information['scale_y']
                if do_color:
                    system_data['color'].rgba = context_information['color']
            
    def update(self, dt):
        self.update_render_state()
        self.render()
        
    def remove_entity(self, int entity_id):
        self.remove_entity_from_canvas(entity_id)
        super(QuadRenderer, self).remove_entity(entity_id)

class PhysicsPointRenderer(PointRenderer):
    system_id = StringProperty('physics_point_renderer')
    render_information_from = StringProperty('cymunk-physics')
    do_rotate = BooleanProperty(True)

    def update_render_state(self):
        cdef object parent = self.gameworld
        cdef list entities = parent.entities
        cdef str system_id = self.system_id
        cdef list entity_ids = self.entity_ids
        cdef object physics_system = parent.systems[self.render_information_from]
        cdef list on_screen = physics_system.query_on_screen()
        cdef dict entity
        cdef dict system_data

        for entity_id in entity_ids:
            entity = entities[entity_id]
            if system_id not in entity:
                continue
            system_data = entity[system_id]
            if not system_data['render'] and entity_id in on_screen:
                self.draw_entity(entity_id)
            if system_data['render'] and not entity_id in on_screen:
                self.remove_entity_from_canvas(entity_id)

class PhysicsRenderer(QuadRenderer):
    system_id = StringProperty('physics_renderer')
    render_information_from = StringProperty('cymunk-physics')
    do_rotate = BooleanProperty(True)

    def update_render_state(self):
        cdef object parent = self.gameworld
        cdef list entities = parent.entities
        cdef str system_id = self.system_id
        cdef list entity_ids = self.entity_ids
        cdef object physics_system = parent.systems[self.render_information_from]
        cdef list on_screen = physics_system.query_on_screen()
        cdef dict entity
        cdef dict system_data

        for entity_id in entity_ids:
            entity = entities[entity_id]
            if system_id not in entity:
                continue
            system_data = entity[system_id]
            if not system_data['render'] and entity_id in on_screen:
                self.draw_entity(entity_id)
            if system_data['render'] and not entity_id in on_screen:
                self.remove_entity_from_canvas(entity_id)

class QuadTreeQuadRenderer(QuadRenderer):
    system_id = StringProperty('quadtree_renderer')
    render_information_from = StringProperty('position')
    quadtree = ObjectProperty(None)
    quadtree_size = ListProperty((2000., 2000.))

    def __init__(self, **kwargs):
        super(QuadTreeQuadRenderer, self).__init__(**kwargs)
        Clock.schedule_once(self.setup_quadtree)

    def remove_entity(self, int entity_id):
        self.remove_entities_from_quadtree([entity_id])
        super(QuadTreeQuadRenderer, self).remove_entity(entity_id)

    def create_component(self, entity_id, entity_component_dict):
        super(QuadTreeQuadRenderer, self).create_component(entity_id, entity_component_dict)
        self.quadtree.add_items([entity_id], 7)

    def setup_quadtree(self, dt):
        self.quadtree = QuadTree(self.gameworld, self.render_information_from, self.system_id, 
            self.entity_ids, depth=7, bounding_rect=(0, 0, self.quadtree_size[0], self.quadtree_size[1]))

    def draw_entity(self, entity_id):
        super(QuadTreeQuadRenderer, self).draw_entity(entity_id)

    def remove_entities_from_quadtree(self, entity_id_list):
        print entity_id_list
        self.quadtree.remove_items(entity_id_list, 7)
        

    def update_render_state(self):
        cdef object parent = self.gameworld
        cdef list entities = parent.entities
        cdef str system_id = self.system_id
        cdef list entity_ids = self.entity_ids
        cdef set on_screen = self.query_on_screen()
        cdef dict entity
        cdef dict system_data
        for entity_id in entity_ids:
            entity = entities[entity_id]
            if system_id not in entity:
                continue
            system_data = entity[system_id]
            if not system_data['render'] and entity_id in on_screen:
                self.draw_entity(entity_id)
            if system_data['render'] and not entity_id in on_screen:
                self.remove_entity_from_canvas(entity_id)

    def query_on_screen(self):
        cdef object viewport = self.gameworld.systems[self.viewport]
        camera_pos = viewport.camera_pos
        size = viewport.size
        cdef list bb_list = [-camera_pos[0] + size[0], -camera_pos[0],  -camera_pos[1] + size[1], -camera_pos[1]]
        cdef set current_on_screen = self.quadtree.bb_hit(bb_list[0], bb_list[1], bb_list[2], bb_list[3])
        return current_on_screen

class QuadTreePointRenderer(PointRenderer):
    system_id = StringProperty('quadtree_point_renderer')
    render_information_from = StringProperty('position')
    quadtree = ObjectProperty(None, allownone=True)
    quadtree_size = ListProperty((2000., 2000.))

    def __init__(self, **kwargs):
        super(QuadTreePointRenderer, self).__init__(**kwargs)
        Clock.schedule_once(self.setup_quadtree)

    def remove_entity(self, int entity_id):
        print 'removing entity,', entity_id
        super(QuadTreePointRenderer, self).remove_entity(entity_id)

    def create_component(self, entity_id, entity_component_dict):
        super(QuadTreePointRenderer, self).create_component(entity_id, entity_component_dict)
        self.quadtree.add_items([entity_id], 7)

    def setup_quadtree(self, dt):
        self.quadtree = QuadTree(self.gameworld, self.render_information_from, self.system_id, 
            self.entity_ids, depth=7, bounding_rect=(0, 0, self.quadtree_size[0], self.quadtree_size[1]))
        print 'quadtree setup', self.quadtree

    def enter_delete_mode(self):
        self.paused = True
        self.quadtree = None
        

    def update_render_state(self):
        cdef object parent = self.gameworld
        cdef list entities = parent.entities
        cdef str system_id = self.system_id
        cdef list entity_ids = self.entity_ids
        cdef set on_screen = self.query_on_screen()
        cdef dict entity
        cdef dict system_data
        for entity_id in entity_ids:
            entity = entities[entity_id]
            if system_id not in entity:
                continue
            system_data = entity[system_id]
            if not system_data['render'] and entity_id in on_screen:
                self.draw_entity(entity_id)
            if system_data['render'] and not entity_id in on_screen:
                self.remove_entity_from_canvas(entity_id)

    def query_on_screen(self):
        cdef object viewport
        cdef list bb_list
        cdef set current_on_screen
        if not self.quadtree == None:
            viewport = self.gameworld.systems[self.viewport]
            camera_pos = viewport.camera_pos
            size = viewport.size
            bb_list = [-camera_pos[0] + size[0], -camera_pos[0],  -camera_pos[1] + size[1], -camera_pos[1]]
            current_on_screen = self.quadtree.bb_hit(bb_list[0], bb_list[1], bb_list[2], bb_list[3])
            return current_on_screen
        else:
            return set([])