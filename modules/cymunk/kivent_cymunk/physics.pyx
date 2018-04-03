# cython: profile=True
# cython: embedsignature=True
from kivy.properties import (StringProperty, ListProperty, ObjectProperty,
BooleanProperty, NumericProperty)
import cymunk
from kivent_core.systems.position_systems cimport (PositionStruct2D,
    PositionSystem2D)
from kivent_core.systems.rotate_systems cimport RotateStruct2D, RotateSystem2D
from kivent_core.entity cimport Entity
from cymunk.cymunk cimport (Space, BB, Body, Shape, Circle, BoxShape,
    Vec2d, Poly, Segment, cpBody, cpVect)
from libc.math cimport M_PI_2
cimport cython
from kivy.factory import Factory
from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem,
    MemComponent)
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from kivent_core.managers.system_manager cimport SystemManager
from collections import Iterable


cdef class PhysicsComponent(MemComponent):
    '''
    The PhysicsComponent mainly exposes the ability to retrieve cymunk
    objects. You will want to review the documentation for the various parts of
    cymunk (and `Chipmunk2D's documentation <https://chipmunk-physics.net/>`_)
    to properly use this system.

    **Attributes:**
        **entity_id** (unsigned int): The entity_id this component is currently
        associated with. Will be <unsigned int>-1 if the component is
        unattached.

        **body** (Body): returns the `cymunk.Body` for your physics component.
        Only set this if you are handling the adding and removal of your
        physics body from the cymunk.Space yourself.

        **unit_vector** (tuple): Returns the current unit_vector describing
        the heading of your physics body. Does not support setting only
        getting.

        **shapes** (list): Returns a list of the shapes attached to the body.
        Be careful when setting to appropriately handle the shapes being
        added or removed from the **body**.


        **shape_type** (str): The type of shape this components **body**
        was initialized with. Only set if you have been modifying your **body**
        manually and you know what you're doing.
    '''

    def __cinit__(self, MemoryBlock memory_block, unsigned int index,
            unsigned int offset):
        self._body = None
        self._shapes = []
        self._shape_type = 'None'

    property entity_id:
        def __get__(self):
            cdef PhysicsStruct* data = <PhysicsStruct*>self.pointer
            return data.entity_id

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


cdef class CymunkPhysics(StaticMemGameSystem):
    '''
    Processing Depends On: 
    :class:`~kivent_core.systems.position_systems.PositionSystem2D`,
    :class:`~kivent_core.systems.rotate_systems.RotateSystem2D`,
    :class:`~kivent_cymunk.physics.CymunkPhysics`

    CymunkPhysics is a **GameSystem** that interacts with the
    Cymunk Port of the `Chipmunk2d Physics Engine
    <https://chipmunk-physics.net/>`_.  Check the `docs for Chipmunk2d
    <https://chipmunk-physics.net/documentation.php>`_ to get an
    overview of how to work with Cymunk.

    This GameSystem is dependent on the
    :class:`~kivent_core.systems.position_systems.PositionComponent2D`
    and :class:`~kivent_core.systems.rotate_systems.RotateComponent2D`
    in addition to its own component. It will write out the position
    and rotation of the `cymunk.Body` associated with your entity every
    frame to these components.


    **Attributes:**
        **space** (ObjectProperty): The Cymunk Space the physics system is
        using

        **gravity** (ListProperty): The (x, y) gravity vector for the space.

        **iterations** (NumericProperty): Number of solving iterations
        for the Space

        **sleep_time_threshold** (NumericProperty): How long a Body is
        inactive in order to be slept in the space

        **collision_slop** (NumericProperty): Collision_slop for the Space;
        i.e. how much collisions can overlap.

        **damping** (NumericProperty): Damping for the Space. This is sort of
        like a global kind of friction. All velocities will be reduced to
        ``damping*initial_velocity`` every update tick.
        
        **cymunk_layers** (ListProperty): List of layer names to register.
        
        **layers** (LayerHelper): Helper to register/change layer names plus
        helper functions to convert between the internal used bitset and 
        the layer names.

    '''
    system_id = StringProperty('cymunk_physics')
    gravity = ListProperty((0, 0))
    updateable = BooleanProperty(True)
    iterations = NumericProperty(2)
    sleep_time_threshold = NumericProperty(5.0)
    collision_slop = NumericProperty(.25)
    damping = NumericProperty(1.0)
    type_size = NumericProperty(sizeof(PhysicsStruct))
    component_type = ObjectProperty(PhysicsComponent)
    processor = BooleanProperty(True)
    ignore_groups = ListProperty([])
    system_names = ListProperty(['cymunk_physics','position', 'rotate'])
    cymunk_layers = ListProperty([])
    

    property space:
        def __get__(self):
            return self.space


    def __init__(self, **kwargs):
        super(CymunkPhysics, self).__init__(**kwargs)
        self.layers = LayerHelper(self.cymunk_layers)
        self.bb_query_result = []
        self.segment_query_result = []
        self.init_physics()
        self.collision_type_count = 0
        self.collision_type_index = {}

    def register_collision_type(self, str type_name):
        count = self.collision_type_count
        self.collision_type_index[type_name] = count
        self.collision_type_count += 1
        return count

    def add_collision_handler(self, int type_a, int type_b, begin_func=None,
                              pre_solve_func=None, post_solve_func=None,
                              separate_func=None):
        '''
        Args:
            type_a (int): the collision_type for the first Shape in the
            collision

            type_b (int): the collision_type for the second Shape in the
            collision

        Kwargs:

            begin_func (function): called (once) when collision between 2 
            shapes first begins

            pre_solve_func (function): called before every solve of the physics
            space where a collision persists

            post_solve_func (function): called after every solve of the physics
            space where a collision persists

            separate_func (function): called (once) when collision between 2
            shapes ends.

        Function to add collision handlers for collisions between
        pairs of collision_type. Collision functions
        for begin_func and pre_solve_func should return True if you want
        the collision to be solved, and False if you want the collisions
        to be ignored

        Functions should accept args: space, arbiter
        You can then retrieve the ``entity_id``'s of the colliding shapes with:

        .. code-block:: python

            first_id = arbiter.shapes[0].body.data
            second_id = arbiter.shapes[1].body.data

        '''
        if isinstance(type_a, str):
            type_a = self.collision_type_index[type_a]
        if isinstance(type_b, str):
            type_b = self.collision_type_index[type_b]
        cdef Space space = self.space
        space.add_collision_handler(
            type_a, type_b,
            begin_func, pre_solve_func,
            post_solve_func, separate_func
            )

    def on_cymunk_layers(self, instance, value):
        '''Event handler that updates the cymunk layer mapping.'''
        self.layers.set_layers(value)

    def on_gravity(self, instance, value):
        '''Event handler that sets the gravity of **space**.'''
        self.space.gravity = value

    def on_damping(self, instance, value):
        '''Event handler that sets the damping of **space**.'''
        self.space.damping = value

    def init_physics(self):
        '''Internal function that handles initalizing the Cymunk Space'''
        self.space = space = Space()
        space.iterations = self.iterations
        space.gravity = self.gravity
        space.damping = self.damping
        space.sleep_time_threshold = self.sleep_time_threshold

        space.collision_slop = self.collision_slop
        space.register_bb_query_func(self._bb_query_func)
        space.register_segment_query_func(self._segment_query_func)

    def _bb_query_func(self, Shape shape):
        '''Internal callback used as part of a bounding box query, will be
        used as part of **query_bb**. It is registered as part of
        **init_physics**.'''
        ignore_groups = self.ignore_groups
        if not shape.collision_type in ignore_groups:
            self.bb_query_result.append(shape.body.data)

    def _segment_query_func(self, object shape, float t, dict n):
        '''Internal callback used as part of a segment query, will be used as
        part of **query_segment**. It is registered as part of
        **init_phyiscs**.
        '''
        self.segment_query_result.append((shape.body.data, t, n))

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
        self.ignore_groups = ignore_groups
        bb = BB(
            box_to_query[0], box_to_query[1], box_to_query[2], box_to_query[3])
        self.bb_query_result = []
        space.space_bb_query(bb)
        return self.bb_query_result


    cdef unsigned int _init_component(self, unsigned int component_index,
        unsigned int entity_id, cpBody* body, str zone_name) except -1:
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef PhysicsStruct* component = <PhysicsStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        component.body = body
        return self.entity_components.add_entity(entity_id, zone_name)

    cdef int _clear_component(self, unsigned int component_index) except 0:
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef PhysicsStruct* pointer = <PhysicsStruct*>memory_zone.get_pointer(
            component_index)
        pointer.entity_id = -1
        pointer.body = NULL
        return 1

    def init_component(self, unsigned int component_index,
        unsigned int entity_id, str zone_name, dict args):
        '''
        Args:

            args (dict): dict containing the kwargs required in order to
            initialize a Cymunk Body with one or more Shape attached. Shape
            types supported are 'box', 'circle', 'poly', and 'segment'.

        The args dict looks like:

        .. code-block:: python

            args = {
                'velocity': (x, y),
                'vel_limit': float,
                'position': (x, y),
                'angle': radians,
                'angular_velocity': radians,
                'ang_vel_limit': float,
                'mass': float,
                'col_shapes': [col_shape_dicts],
                'moment': float
                }

        moment (if not specified) will be computed from component shapes

        The col_shape_dicts look like:

        .. code-block:: python

            col_shape_dict = {
                'shape_type': string_shape_name,
                'elasticity': float,
                'shape_info': shape_specific_dict,
                # Can be used to filter collision using custom collision_handlers.
                'collision_type': int, 
                # OPTIONAL. Fast collision filter.
                # Shapes with the same group never collide.
                'group': int,
                # OPTIONAL. Fast collision filter.
                # If set shapes will only collide if at least one layer is set in both shapes.
                # Internal represented as bitset.
                # Can be number (bitset) or iterable containing layer names from **cymunk_layers**.
                'layers': int or iterable
                }

        shape_info dicts looke like this, depending on their shape:

        .. code-block:: python

            box = {
                'width': float,
                'height': float,
                'mass': float,
                # OPTIONAL
                'offset': (float, float)
                }

            circle = {
                'inner_radius': float,
                'outer_radius': float,
                'mass': float,
                # OPTIONAL
                'offset': (float, float)
                }

            poly = {
                'mass': float,
                'vertices': list,
                # OPTIONAL
                'offset': (float, float)}

            segment = {
                'mass': float,
                'a': (float, float),
                'b': (float, float),
                'radius': float (beveling radius for segment),
                }

            If you want a solid circle set inner_radius to 0.

        '''
        cdef unsigned int index = component_index
        cdef PhysicsComponent component = self.components[index]
        cdef dict shape = args['col_shapes'][0]
        cdef list cshapes = args['col_shapes']
        cdef float moment
        cdef Body body
        cdef Space space
        cdef list shapes
        cdef Shape new_shape
        cdef unsigned int layers
        space = self.space
        if 'moment' in args.keys():
            moment = args['moment']
        else:
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
                elif a_shape['shape_type'] == 'segment':
                    moment += cymunk.moment_for_segment(
                        shape_info['mass'],
                        shape_info['a'],
                        shape_info['b'])
                else:
                    print('error: shape ', a_shape['shape_type'], 
                          'not supported')
        if args['mass'] == 0:
            body = Body(None, None)
        else:
            body = Body(args['mass'], moment)
            body.velocity = args['velocity']
            body.angular_velocity = args['angular_velocity']
            if 'vel_limit' in args:
                body.velocity_limit = args['vel_limit']
            if 'ang_vel_limit' in args:
                body.angular_velocity_limit = args['ang_vel_limit']
        body.data = entity_id
        body.angle = args['angle']
        body.position = args['position']
        if args['mass'] != 0:
            space.add(body)
        shapes = []
        for shape in args['col_shapes']:
            shape_info = shape['shape_info']
            offset = shape_info['offset'] if 'offset' in shape_info else (0,0)
            if shape['shape_type'] == 'circle':
                new_shape = Circle(body, shape_info['outer_radius'],
                    offset)
            elif shape['shape_type'] == 'box':
                new_shape = BoxShape(body, shape_info['width'],
                     shape_info['height'], offset)
            elif shape['shape_type'] == 'poly':
                new_shape = Poly(body, shape_info['vertices'],
                    offset=offset)
            elif shape['shape_type'] == 'segment':
                new_shape = Segment(body, shape_info['a'], shape_info['b'],
                    shape_info['radius'])
            else:
                raise ValueError("Invalid shape_type: '%s'" % shape['shape_type'])
            new_shape.friction = shape['friction']
            new_shape.elasticity = shape['elasticity']
            new_shape.collision_type = shape['collision_type']
            if 'group' in shape:
                new_shape.group = shape['group']
            if 'layers' in shape:
                if isinstance(shape['layers'], Iterable):
                    layers = self.layers.calculate_layerset(shape['layers'])
                else:
                    layers = int(shape['layers'])
                new_shape.layers = layers
            shapes.append(new_shape)
            space.add(new_shape)
            space.reindex_shape(new_shape)

        shape_type = args['col_shapes'][0]['shape_type']
        component._body = body
        component._shapes = shapes
        component._shape_type = shape_type
        self._init_component(index, entity_id, body._body, zone_name)

    def clear_component(self, unsigned int component_index):
        cdef PhysicsComponent component = self.components[component_index]
        component._body = None
        component._shapes = []
        component._shape_type = 'None'
        self._clear_component(component_index)

    def create_component(self, unsigned int entity_id, str zone_name, args):
        component_index = super(CymunkPhysics, self).create_component(
            entity_id, zone_name, args)
        gameworld = self.gameworld
        cdef RotateSystem2D rotate_system
        cdef PositionSystem2D position_system
        cdef IndexedMemoryZone entities = gameworld.entities
        cdef SystemManager system_manager = gameworld.system_manager
        rotate_system = system_manager['rotate']
        position_system = system_manager['position']
        cdef unsigned int rotate_index = system_manager.get_system_index(
            'rotate')
        cdef unsigned int pos_index = system_manager.get_system_index(
            'position')
        cdef unsigned int phys_index = system_manager.get_system_index(
            self.system_id)
        cdef MemoryZone entity_memory = entities.memory_zone
        cdef MemoryZone pos_memory = position_system.imz_components.memory_zone
        cdef MemoryZone rot_memory = rotate_system.imz_components.memory_zone
        cdef MemoryZone physics_memory = self.imz_components.memory_zone
        cdef unsigned int* entity = <unsigned int*>(
            entity_memory.get_pointer(entity_id))
        cdef unsigned int pos_comp_index = entity[pos_index+1]
        cdef unsigned int rot_comp_index = entity[rotate_index+1]
        cdef unsigned int physics_comp_index = entity[phys_index+1]
        cdef PositionStruct2D* pos_comp = (
            <PositionStruct2D*>pos_memory.get_pointer(pos_comp_index))
        cdef RotateStruct2D* rot_comp = (
            <RotateStruct2D*>rot_memory.get_pointer(rot_comp_index))
        cdef PhysicsStruct* physics_comp = <PhysicsStruct*>(
            physics_memory.get_pointer(component_index))
        cdef cpBody* body = physics_comp.body
        rot_comp.r = body.a
        cdef cpVect p_position = body.p
        pos_comp.x = p_position.x
        pos_comp.y = p_position.y
        return component_index

    def remove_component(self, unsigned int component_index):
        cdef Space space = self.space
        cdef PhysicsComponent component = self.components[component_index]
        cdef Shape shape
        cdef Body body = component._body
        for shape in component._shapes:
            space.remove(shape)
        if not body.is_static:
            space.remove(body)
        self.entity_components.remove_entity(component.entity_id)
        super(CymunkPhysics, self).remove_component(component_index)

    def update(self, dt):
        '''Handles update of the cymunk space and updates the component data
        for position and rotate components. '''

        self.space.step(dt)

        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index
        cdef PositionStruct2D* pos_comp
        cdef RotateStruct2D* rot_comp
        cdef PhysicsStruct* physics_comp
        cdef cpBody* body
        cdef cpVect p_position

        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            physics_comp = <PhysicsStruct*>component_data[real_index]
            pos_comp = <PositionStruct2D*>component_data[real_index+1]
            rot_comp = <RotateStruct2D*>component_data[real_index+2]
            body = physics_comp.body
            rot_comp.r = body.a
            p_position = body.p
            pos_comp.x = p_position.x
            pos_comp.y = p_position.y



Factory.register('CymunkPhysics', cls=CymunkPhysics)


class LayerException(Exception):
    pass
class LayerCountException(LayerException):
    pass
class LayerDuplicateException(LayerException):
    pass
class LayerNotFoundException(LayerException):
    pass

cdef class LayerHelper:
    '''
    The LayerHelper helps in using cymunks layers.
    Layers in cymunk (chipmunk) can be used to filter collisions.
    Collsisions will only occur if both shapes share at least one layer.
    
    Layers are represented as bitsets in cymunk.
    This class provides a more pythonic way to map these bitsets.
    
    The amount of supported layers (size of the bitset) depends on your system
    and/or how you compiled cymunk.
    The default size is <unsigned int> which should be at least 32 bits large.
    To change it compile cymunk AND this module with a define like:
    -DCP_LAYERS_TYPE=uint32_t (64bit numbers need a cymunk patch atm)
    
    See the **max_layers** property for the currently available size.
    
    **Attributes:**
        **layers** (tuple(str, str,...)): All registered layers in the order
        of their corresponding bit.
        
        **layer_count** (int): The count of the currently registered layers.
        
        **max_layers** (int): The maximum supported number of layers on this system. 
    '''
    def __init__(self, layers=None):
        self._max_size = sizeof(cpLayers) * 8
        self.layers = list()
        self._layer_ids = dict()
        if layers:
            for layer in layers:
                self.add_layer(layer)
        self.ALL_LAYERS = ~(<cpLayers>0)
        self.NO_LAYERS = 0

    property layers:
        def __get__(self):
            return tuple(self.layers)

    property layer_count:
        def __get__(self):
            return len(self.layers)

    property max_layers:
        def __get__(self):
            return self._max_size

    def add_layer(self, str layer_name):
        '''
        Add a new layer with a given name.
        
        May raise **LayerDuplicateException** or **LayerCountException**.
        '''
        if layer_name in self._layer_ids:
            raise LayerDuplicateException('Layer "%s" already present.' % layer_name)
        new_id = len(self.layers)
        if new_id >= self._max_size:
            raise LayerCountException("Only up to %i layers supported." % self._max_size)        
        self._layer_ids[layer_name] = new_id
        self.layers.append(layer_name)

    def clear(self):
        '''Removes all layer mappings.'''
        self.layers = []
        self._layer_ids = {}

    def set_layers(self, layers):
        '''
        Set the used layer names.
        Removes the old layer names.
        
        **Args:**
            **layers** (iterable): A list containing the new layer names
            
        May raise **LayerDuplicateException** or **LayerCountException**.
        '''
        self.clear()
        for layer in layers:
            self.add_layer(layer)

    def rename_layer(self, str old_name, str new_name):
        '''
        Rename a layer.
        
        May raise **LayerNotFoundException** or **LayerDuplicateException**.
        '''
        if not old_name in self._layer_ids:
            raise LayerNotFoundException('Layer "%s" not found..' % old_name)
        if new_name in self._layer_ids:
            raise LayerDuplicateException('Layer "%s" already present.' % new_name)
        cdef unsigned int layer_id = self._layer_ids[old_name]
        self._layer_ids[new_name] = layer_id
        self.layers[layer_id] = new_name

    cpdef cpLayers calculate_layerset(self, object used_layers) except *:
        '''
        Calculate the bitset for the given used layers.
        
        **Args:**
            **used_layers** (iterable): An iterable containing the layers to use.
        
        May raise **LayerNotFoundException**.
        '''
        cdef cpLayers num = 0
        cdef str layer
        cdef dict layer_ids = self._layer_ids
        for layer in used_layers:
            if not layer in layer_ids:
                raise LayerNotFoundException('Layer "%s" not found.' % layer)
            num |= 1 << layer_ids[layer]
        return num

    def get_layers_from_layerset(self, cpLayers layerset, ignore_missing=True):
        '''
        Get the names of all set layers in the given bitset.
        If **ignore_missing** is set ignores all bits for which no name is registered.
        Otherwise raise a **LayerCountException**.
        '''
        cdef list ret = list()
        cdef cpLayers remain = layerset;
        for i, layer in enumerate(self.layers):
            if (layerset & (1 << i)):
                ret.append(layer)
                remain -= 1 << i
        if not ignore_missing and remain > 0:
            raise LayerCountException()
        return ret

    def is_layer_set(self, str layer, cpLayers layerset):
        '''
        Returns if the given layer is set in the layerset.
        May raise **LayerNotFoundException**.
        '''
        if not layer in self._layer_ids:
            raise LayerNotFoundException('Layer "%s" not found.' % layer)
        cdef unsigned int layer_id = self._layer_ids[layer] 
        return bool(layerset & (1 << layer_id))

    def set_layer(self, str layer, cpLayers layerset = 0):
        '''
        Sets the given layer in the layerset.
        May raise **LayerNotFoundException**.
        '''
        if not layer in self._layer_ids:
            raise LayerNotFoundException('Layer "%s" not found.' % layer)
        cdef unsigned int layer_id = self._layer_ids[layer] 
        return layerset | (1 << layer_id)

    def unset_layer(self, str layer, cpLayers layerset):
        '''
        Removes the given layer from the given layerset.
        May raise **LayerNotFoundException**.
        '''
        if not layer in self._layer_ids:
            raise LayerNotFoundException('Layer "%s" not found.' % layer)
        cdef unsigned int layer_id = self._layer_ids[layer] 
        return layerset & (~(1 << layer_id))
