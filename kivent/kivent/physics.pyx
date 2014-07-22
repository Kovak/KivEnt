from kivy.properties import (StringProperty, ListProperty, ObjectProperty, 
BooleanProperty, NumericProperty)
import cymunk
from cymunk import Poly
from cymunk cimport Space, BB, Body, Shape, Circle, BoxShape, Vec2d
from libc.math cimport M_PI_2


cdef class PhysicsComponent:
    cdef Body _body
    cdef list _shapes
    cdef str _shape_type

    def __cinit__(self, Body body, list shapes, str shape_type):
        self._body = body
        self._shapes = shapes
        self._shape_type = shape_type

    property body:
        def __get__(self):
            return self._body
        def __set__(self, Body value):
            self._body = value

    property unit_vector:
        def __get__(self):
            return self._body.rotation_vector

    property shapes:
        def __get__(self):
            return self._shapes
        def __set__(self, list value):
            self._shapes = value

    property shape_type:
        def __get__(self):
            return self._shape_type
        def __set__(self, str value):
            self._shape_type = value

class CymunkPhysics(GameSystem):
    '''CymunkPhysics is a GameSystem that interacts with the Cymunk Port of
    the Chipmunk2d Physics Engine. Check the docs for Chipmunk2d to get an
    overview of how to work with Cymunk. https://chipmunk-physics.net/

    **Attributes:**
        **space** (ObjectProperty): The Cymunk Space the physics system is 
        using

        **gravity** (ListProperty): The (x, y) gravity for the space.

        **iterations** (NumericProperty): Number of solving iterations 
        for the Space

        **sleep_time_threshold** (NumericProperty): How long a Body is 
        inactive in order to be slept in the space

        **collision_slop** (NumericProperty): Collision_slop for the Space 
        (how much collisions can overlap)

        **damping** (NumericProperty): Damping for the Space, this is sort of 
        like a global kind of friction, all velocities will be reduced to 
        damping*initial_velocity every update tick. 

        **on_screen_result** (list): Caches the entity_ids that were on 
        on_screen last update. Prefer to use this compared to query_on_screen

    '''
    system_id = StringProperty('cymunk_physics')
    space = ObjectProperty(None)
    gravity = ListProperty((0, 0))
    updateable = BooleanProperty(True)
    iterations = NumericProperty(2)
    sleep_time_threshold = NumericProperty(5.0)
    collision_slop = NumericProperty(.25)
    damping = NumericProperty(1.0)


    def __init__(self, **kwargs):
        cdef list bb_query_result
        cdef list on_screen_result
        cdef list segment_query_result
        super(CymunkPhysics, self).__init__(**kwargs)
        self.bb_query_result = list()
        self.segment_query_result = list()
        self.on_screen_result = list()
        self.init_physics()
        
    def add_collision_handler(self, int type_a, int type_b, begin_func=None, 
        pre_solve_func=None, post_solve_func=None, separate_func=None):
        '''
        Args:
            type_a (int): the collision_type for the first Shape in the 
            collision

            type_b (int): the collision_type for the second Shape in the
            collision

        Kwargs:

            begin_func (function): calledwhen collision between 2 shapes begins

            pre_solve_func (function): called before every solve of the physics 
            space where a collision persists

            post_solve_func (function): called after every solve of the physics 
            space where a collision persists

            separate_func (function): called when collision between 2 shapes 
            ends


        Function to add collision handlers for collisions between
        pairs of collision_type. Collision functions
        for begin_func and pre_solve_func should return True if you want
        the collision to be solved, and False if you want the collisions
        to be ignored

        Functions should accept args: space, arbiter
        You can then retrieve the entity_id's of the colliding shapes with:

        .. code-block:: python

            first_id = arbiter.shapes[0].body.data
            second_id = arbiter.shapes[1].body.data

        '''
        cdef Space space = self.space
        space.add_collision_handler(type_a, type_b, 
            begin_func, pre_solve_func, 
            post_solve_func, separate_func)

    def on_gravity(self, instance, value):
        self.space.gravity = value

    def on_damping(self, instance, value):
        self.space.damping = value

    def init_physics(self):
        '''Internal function that handles initalizing the Cymunk Space'''
        cdef Space space
        self.space = space = Space()
        space.iterations = self.iterations
        space.gravity = self.gravity
        space.damping = self.damping
        space.sleep_time_threshold = self.sleep_time_threshold
        
        space.collision_slop = self.collision_slop
        space.register_bb_query_func(self.bb_query_func)
        space.register_segment_query_func(self.segment_query_func)

    def bb_query_func(self, Shape shape):
        ignore_groups = self.ignore_groups
        if not shape.collision_type in ignore_groups:
            self.bb_query_result.append(shape.body.data)

    def segment_query_func(self, object shape, float t, dict n):
        self.segment_query_result.append((shape.body.data, t, n))

    def query_on_screen(self):
        '''Used internally to query entities on screen for a frame. Prefer to
        use on_screen_result to get this information as it caches this 
        information for performance'''
        cdef object viewport = self.gameworld.systems[self.viewport]
        camera_pos = viewport.camera_pos
        camera_scale = viewport.camera_scale
        size = (viewport.size[0]*camera_scale, viewport.size[1]*camera_scale)
        cdef list bb_list = [-camera_pos[0], -camera_pos[1], 
            -camera_pos[0] + size[0], -camera_pos[1] + size[1]]
        current_on_screen = self.query_bb(bb_list)
        return current_on_screen

    def query_segment(self, vect_start, vect_end):
        '''
        Args:
            vect_start (tuple): (x1, y1) start point of segment.

            vect_end (tuple): (x2, y2) end point of segment.

        Queries collisions between (x1, y1) and (x2, y2)'''
        self.segment_query_result = []
        self.space.space_segment_query(vect_start, vect_end)
        return self.segment_query_result

    def query_bb(self, list box_to_query, ignore_groups=[]):
        '''
        Args:
            box_to_query (list): should be a list of [x, y, x+w, y+h] where
            x, y is the bottom left hand corner of the box, and w, h is
            the width and height of the box.

        Kwargs:
            ignore_groups (list): list of collision_types to ignore during 
            this query.

        Queries collisions inside a box.
        '''
        cdef Space space = self.space
        self.ignore_groups=ignore_groups
        bb = BB(
            box_to_query[0], box_to_query[1], box_to_query[2], box_to_query[3])
        self.bb_query_result = []
        space.space_bb_query(bb)
        return self.bb_query_result

    def generate_component(self, dict entity_component_dict):
        '''
        Args:
            entity_component_dict (dict): dict containing the kwargs
            required in order to initialize a Cymunk Body with one or more 
            Shape attached.

        entity_component_dict of the form {
        'entity_id': id, 'main_shape': string_shape_name, 
        'velocity': (x, y), 'position': (x, y), 'angle': radians, 
        'angular_velocity': radians, 'mass': float, 
        col_shapes': [col_shape_dicts]}

        col_shape_dicts look like : {
        'shape_type': string_shape_name, 'elasticity': float, 
        'collision_type': int, 'shape_info': shape_specific_dict}

        shape_info:
        box: {'width': float, 'height': float, 'mass': float}
        circle: {'inner_radius': float, 'outer_radius': float, 
        'mass': float, 'offset': tuple}
        solid cirlces have an inner_radius of 0

        outputs RenderComponent with properties body, unit_vector, shapes,
        shape_type.

        '''
        cdef dict shape = entity_component_dict['col_shapes'][0]
        cdef list cshapes = entity_component_dict['col_shapes']
        cdef float moment
        cdef Body body
        cdef Space space
        cdef list shapes
        cdef Shape new_shape
        space = self.space
        moment = 0
        for a_shape in cshapes:
            shape_info = a_shape['shape_info']
            if a_shape['shape_type'] == 'circle':
                moment += cymunk.moment_for_circle(
                    shape_info['mass'], 
                    shape_info['inner_radius'], 
                    shape_info['outer_radius'], 
                    shape_info['offset'])
            elif a_shape['shape_type'] == 'box':
                moment += cymunk.moment_for_box(
                    shape_info['mass'], 
                    shape_info['width'], 
                    shape_info['height'])
            elif a_shape['shape_type'] == 'poly':
                moment += cymunk.moment_for_poly(
                    shape_info['mass'], 
                    shape_info['vertices'], 
                    shape_info['offset'])
                    
            else:
                print 'error: shape ', a_shape['shape_type'], 'not supported'
        if entity_component_dict['mass'] == 0:
            body = Body(None, None)
        else:
            body = Body(entity_component_dict['mass'], moment)
            body.velocity = entity_component_dict['velocity']
            body.angular_velocity = entity_component_dict[
                'angular_velocity']
            if 'vel_limit' in entity_component_dict:
                body.velocity_limit = entity_component_dict[
                'vel_limit']
            if 'ang_vel_limit' in entity_component_dict:
                body.angular_velocity_limit = entity_component_dict[
                'ang_vel_limit']
        body.data = entity_component_dict['entity_id']
        body.angle = entity_component_dict['angle']
        body.position = entity_component_dict['position']
        if entity_component_dict['mass'] != 0:
            space.add(body)
        shapes = []
        for shape in entity_component_dict['col_shapes']:
            shape_info = shape['shape_info']
            if shape['shape_type'] == 'circle':
                new_shape = Circle(body, shape_info['outer_radius']) 
            elif shape['shape_type'] == 'box':
                new_shape = BoxShape(
                    body, shape_info['width'], shape_info['height'])
            elif shape['shape_type'] == 'poly':
                new_shape = Poly(body, shape_info['vertices'], 
                    offset=shape_info['offset'])
            else:
                print 'shape not created'
            new_shape.friction = shape['friction']
            new_shape.elasticity = shape['elasticity']
            new_shape.collision_type = shape['collision_type']
            shapes.append(new_shape)
            space.add(new_shape)
            space.reindex_shape(new_shape)
            
        shape_type = entity_component_dict['col_shapes'][0]['shape_type']
        new_component = PhysicsComponent.__new__(PhysicsComponent, body, shapes, shape_type)
        return new_component

    def create_component(self, object entity, args):
        args['entity_id'] = entity.entity_id
        super(CymunkPhysics, self).create_component(
            entity, args)
        cdef str system_id = self.system_id
        cdef PhysicsComponent physics = getattr(entity, system_id)
        cdef PositionComponent position = entity.position
        cdef RotateComponent rotate = entity.rotate
        cdef Body body = physics._body
        rotate._r = body.angle - M_PI_2
        cdef Vec2d p_position = body.position
        position._x = p_position.x
        position._y = p_position.y

    def remove_entity(self, int entity_id):
        cdef Space space = self.space
        cdef list entities = self.gameworld.entities
        cdef object entity = entities[entity_id]
        cdef PhysicsComponent system_data = getattr(entity, self.system_id)
        cdef Shape shape
        cdef Body body = system_data._body
        for shape in system_data._shapes:
            space.remove(shape)
        if not body.is_static:
            space.remove(body)
        super(CymunkPhysics, self).remove_entity(entity_id)

    def update(self, dt):
        '''Handles update of the cymunk space and updates the rendering 
        component data for position and rotate components. '''
        cdef list entities = self.gameworld.entities
        space = self.space
        space.step(dt)
        cdef str system_id = self.system_id
        cdef object entity
        cdef PhysicsComponent system_data
        cdef RotateComponent rotate
        cdef PositionComponent position
        cdef Vec2d p_position
        cdef Body body
        cdef int i
        cdef list entity_ids = self.entity_ids
        for i in range(len(entity_ids)):
            entity_id = entity_ids[i]
            entity = entities[entity_id]
            system_data = getattr(entity, system_id)
            body = system_data._body
            position = entity.position
            rotate = entity.rotate
            rotate._r = body.angle
            p_position = body.position
            position._x = p_position.x
            position._y = p_position.y
        self.on_screen_result = self.query_on_screen()

