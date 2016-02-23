# cython: profile=True
# cython: embedsignature=True
from cymunk.cymunk cimport (
    GearJoint, PivotJoint, Vec2d, cpVect, cpv,
    cpFloat, cpBool, cpvunrotate, cpvrotate, cpvdot, cpvsub, cpvnear,
    cpBody, cpvmult, cpvlerp, Space, cpvforangle, cpvadd, cpvlength,
    cpvnormalize,
    )
from kivy.properties import (
    ListProperty, NumericProperty, BooleanProperty,
    StringProperty, ObjectProperty
    )
from kivent_cymunk.physics cimport (
    PhysicsComponent, PhysicsStruct, CymunkPhysics
    )
from kivent_core.systems.staticmemgamesystem cimport (
    StaticMemGameSystem, MemComponent
    )
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from kivent_core.systems.position_systems cimport (PositionComponent2D, 
    PositionStruct2D)
from kivent_core.systems.rotate_systems cimport RotateComponent2D
cimport cython
from kivent_core.entity cimport Entity
from kivy.factory import Factory
from libc.math cimport atan2, pow as cpow
from math import radians
from random import uniform
from kivent_core.managers.system_manager cimport SystemManager


cdef class CymunkTouchComponent(MemComponent):
    '''
    The CymunkTouchComponent keeps track of a PivotJoint and a Body that has 
    not been added to the cymunk Space in order to control physics objects 
    actually added to the world. The PivotJoint is bound to the **touch_body**
    of this component and the Body of the touched Entity.


    **Attributes:**
        **entity_id** (unsigned int): The entity_id this component is currently
        associated with. Will be <unsigned int>-1 if the component is 
        unattached.

        **touch_body** (Body): This is a rogue body (unattached to the space)
        that influences another Body through a cymunk.constraint interaction.

        **pivot** (PivotJoint): The constraint that acts on this body and the 
        one it is attached to. 

        **max_force** (float): Maximum force the joint can exert on the 
        attached body.

        **error_bias** (float): The rate at which the joint is corrected.

    '''

    def __cinit__(self, MemoryBlock memory_block, unsigned int index,
            unsigned int offset):
        self._touch_body = None
        self._pivot = None

    property entity_id:
        def __get__(self):
            cdef CymunkTouchStruct* data = <CymunkTouchStruct*>self.pointer
            return data.entity_id

    property max_force:
        def __get__(self):
            return self._pivot.max_force
        def __set__(self, float force):
            self._pivot.max_force = force

    property error_bias:
        def __get__(self):
            return self._pivot.error_bias
        def __set__(self, float error_bias):
            self._pivot.error_bias = error_bias

    property touch_body:
        def __get__(self):
            return self._touch_body
        def __set__(self, Body body):
            self._touch_body = body

    property pivot:
        def __get__(self):
            return self._pivot
        def __set__(self, PivotJoint pivot):
            self._pivot = pivot

cdef class CymunkTouchSystem(StaticMemGameSystem):
    '''
    Processing Depends On: PositionSystem2D, CymunkTouchSystem

    The CymunkTouchSystem provides a way to interact with the entities in a 
    CymunkPhysics GameSystem, either through touches or mouse clicks. Touched 
    entities will be 'dragged'. This system will generate new entities when 
    receiving an on_touch_down event that collides with an entity in the 
    space of the CymunkPhysics GameSystem with system_id: **physics_system**.

    The entities will be generated in zone **zone_to_use** so make sure to set 
    this up appropriately. This zone should not need more than 100 entities 
    unless you are planning on receiving very many simultaneous touches.

    This system will be dependent on its own component and a 
    PositionComponent2D (default system_id: 'position') for processing.

    **Attributes:**
        **physics_system** (StringProperty): Name (system_id) of the physics 
        system to use with this system. Defaults to 'cymunk_physics'.

        **touch_radius** (NumericProperty): Size of the touch query to see 
        which entities we are touching. Defaults to 20.

        **max_force** (NumericProperty): Maximum force the PivotJoint will be 
        able to exert. Defaults to 2500000.

        **max_bias** (NumericProperty): The rate at which the joints for 
        touch entities will be corrected. Defaults to 10000.

        **ignore_groups** (ListProperty): List of collision_type (int) to 
        ignore when performing the collision query in on_touch_down. Defaults 
        to [].

        **zone_to_use** (StringProperty): Name of the zone to create entities 
        in. Defaults to 'touch'.

    '''
    system_id = StringProperty('cymunk_touch')
    physics_system = StringProperty('cymunk_physics')
    updateable = BooleanProperty(True)
    touch_radius = NumericProperty(20.)
    max_force = NumericProperty(2500000.)
    max_bias = NumericProperty(10000.)
    ignore_groups = ListProperty([])
    processor = BooleanProperty(True)
    type_size = NumericProperty(sizeof(CymunkTouchStruct))
    component_type = ObjectProperty(CymunkTouchComponent)
    zone_to_use = StringProperty('touch')
    system_names = ListProperty(['cymunk_touch','position'])


    def init_component(self, unsigned int component_index, 
        unsigned int entity_id, str zone, dict args):
        '''
        The entities for this system are typically generated by its 
        on_touch_down event. However, if you do need to create a component 
        the args dict looks like: 

        You will also definitely want to look over how this GameSystem 
        manipulates its components in the on_touch_down, on_touch_move,
        and on_touch_up event handling.

        Args:

            component_index (unsigned int): Index of the component to be 
            initialized. 

            entity_id (usigned int): Identity of the entity we will be 
            adding this component to.

            zone (str): Name of the zone this entities memory will use.

            args (dict): Contains the arguments for creating the PivotJoint.
            Described below.

        Args dict looks like:

        .. code-block:: python

            args = {
                'touch_pos': (float, float), 
                #Tuple of the position this touch is occuring at

                'touched_ent': (unsigned int), 
                #The id of the entity that was touched.

                'max_bias': float,
                #The error correction rate for this connection

                'max_force': float,
                #The maximum amount of force this joint can generate.
                }

        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef CymunkTouchComponent py_component = self.components[
            component_index]
        cdef CymunkTouchStruct* component = <CymunkTouchStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        gameworld = self.gameworld
        cdef SystemManager system_manager = gameworld.system_manager
        cdef str physics_id = self.physics_system
        cdef object physics_system = system_manager[physics_id]
        cdef Body touch_body = Body(None, None)
        cdef IndexedMemoryZone entities = gameworld.entities
        cdef tuple touch_pos = args['touch_pos']
        cdef unsigned int touched_ent = args['touched_ent']
        touched_entity = entities[touched_ent]
        cdef PhysicsComponent physics_data = getattr(
            touched_entity, physics_id)
        cdef Body body = physics_data.body
        cdef cpVect body_local = body.world_to_local(touch_pos)
        cdef tuple body_pos = (body_local.x, body_local.y)
        cdef PivotJoint pivot = PivotJoint(touch_body, body, (0., 0.), 
            body_pos)
        touch_body._body.p = cpv(touch_pos[0], touch_pos[1])
        pivot.max_bias = args['max_bias']
        pivot.error_bias = cpow(1.0 - 0.15, 60.0)
        pivot.max_force = args['max_force']
        cdef Space space = physics_system.space
        py_component._touch_body = touch_body
        py_component._pivot = pivot
        space.add(pivot)
        component.touch_body = touch_body._body
        component.pivot = pivot._pivotjoint
        return self.entity_components.add_entity(entity_id, zone)

    def clear_component(self, unsigned int component_index):
        '''
        Clears the component at **component_index**. We must set the 
        pointers in the C struct to empty and the references in the 
        CymunkTouchComponent to None.

        Args:

            component_index (unsigned int): Component to remove.

        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef CymunkTouchStruct* pointer = <CymunkTouchStruct*>(
            memory_zone.get_pointer(component_index))
        pointer.entity_id = -1
        pointer.touch_body = NULL
        pointer.pivot = NULL
        cdef CymunkTouchComponent py_component = self.components[
            component_index]
        py_component._pivot = None
        py_component._touch_body = None

    def remove_component(self, unsigned int component_index):
        '''
        Before we clear the component we perform some cleanup on the 
        physics objects, removing the _pivot PivotJoint from our Space. We 
        also remove our entity from the **entity_components** aggregator at 
        this time.

        Args:

            component_index (unsigned int): Component to remove.
            
        '''
        cdef CymunkTouchComponent component = self.components[component_index]
        self.entity_components.remove_entity(component.entity_id)
        gameworld = self.gameworld
        cdef str physics_id = self.physics_system
        cdef SystemManager system_manager = gameworld.system_manager
        physics_system = system_manager[physics_id]
        cdef Space space = physics_system.space
        space.remove(component._pivot)
        super(CymunkTouchSystem, self).remove_component(component_index)
    
    def on_touch_down(self, touch):
        '''
        The touch down handling for the CymunkTouchSystem queries the 
        CymunkPhysics GameSystem with system_id: **physics_system** to see 
        if any touches occur withtin a square of x +- **touch_radius**, y +-
        **touch_radius**. 

        If we do collide with an entity, we will take the first one and 
        bind a new rogue body (unattached from the physics Space) together 
        with the touched entity's physics Body by creating a PivotJoint.
        The new entity representing the PivotJoint will be created in zone: 
        **zone_to_use**.  

        '''
        cdef object gameworld = self.gameworld
        cdef SystemManager system_manager = gameworld.system_manager
        cdef object physics_system = system_manager[self.physics_system]
        cdef float tx = touch.x 
        cdef float ty = touch.y
        cdef str system_id = self.system_id
        cdef float max_force = self.max_force
        cdef float max_bias = self.max_bias
        cdef float radius = self.touch_radius
        cdef list touch_box = [tx-radius, ty-radius, tx+radius, ty+radius]
        cdef list touched_ids = physics_system.query_bb(touch_box,
            ignore_groups=self.ignore_groups)
        if len(touched_ids) > 0:
            entity_id = touched_ids[0]
            creation_dict = {system_id: 
                {'touched_ent': entity_id, 'touch_pos': (tx, ty),
                'max_force': max_force, 'max_bias':max_bias}, 
                'position': (tx, ty)}
            touch_ent = gameworld.init_entity(creation_dict, ['position', 
                system_id], zone=self.zone_to_use)
            touch.ud['ent_id'] = touch_ent
            touch.ud['touched_ent_id'] = entity_id
            return True
        else:
            return False

    def on_touch_move(self, touch):
        '''
        The touch move handling keeps track of the touch entity generated in 
        on_touch_down, updating its position to the new position of the touch.
        '''

        cdef object gameworld 
        cdef SystemManager system_manager
        cdef object gameview
        cdef IndexedMemoryZone entities
        cdef tuple camera_pos
        cdef tuple touch_pos = (touch.x, touch.y)
        cdef float camera_scale 
        cdef tuple converted_pos 
        cdef unsigned int entity_id
        cdef object entity
        cdef PositionComponent2D pos_comp
        if 'ent_id' in touch.ud:
            gameworld = self.gameworld
            system_manager = gameworld.system_manager
            entities = gameworld.entities
            entity_id = touch.ud['ent_id']
            entity = entities[entity_id]
            pos_comp = entity.position
            pos_comp.pos = touch_pos

    def on_touch_up(self, touch):
        '''
        On touch up, if we have previously set the ud['ent_id'] in 
        on_touch_down we will remove this entity from the GameWorld as the 
        touch is now over.
        '''
        if 'ent_id' in touch.ud:
            self.gameworld.remove_entity(touch.ud['ent_id'])

    def update(self, float dt):
        gameworld = self.gameworld
        cdef CymunkTouchStruct* system_component 
        cdef PositionStruct2D* pos_comp
        cdef cpBody* body
        cdef cpVect p_position
        cdef cpVect body_pos
        cdef cpVect new_vel
        cdef cpVect new_point
        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index

        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            pos_comp = <PositionStruct2D*>component_data[real_index+1]
            system_component = <CymunkTouchStruct*>component_data[real_index]
            body = system_component.touch_body
            body_pos = body.p
            new_point = cpvlerp(body_pos, cpv(pos_comp.x, pos_comp.y), .25)
            new_vel = cpvmult(cpvsub(new_point, body_pos),  60.)
            body.v = new_vel
            body.p = new_point


cdef class SteeringComponent: 

    def __cinit__(self, MemoryBlock memory_block, unsigned int index,
            unsigned int offset):
        self._pivot = None
        self._steering_body = None
        self._gear = None

    property entity_id:
        def __get__(self):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            return data.entity_id

    property steering_body:
        def __get__(self):
            return self._steering_body
        def __set__(self, Body body):
            self._steering_body = body

    property pivot:
        def __get__(self):
            return self._pivot
        def __set__(self, PivotJoint pivot):
            self._pivot = pivot

    property gear:
        def __get__(self):
            return self._gear
        def __set__(self, GearJoint gear):
            self._gear = gear

    property target:
        def __get__(self):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            return (data.target[0], data.target[1])
        def __set__(self, tuple target):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            data.target[0] = target[0]
            data.target[1] = target[1]

    property turn_speed:
        def __get__(self):
            return self._gear.max_bias
        def __set__(self, float turn_speed):
            self._gear.max_bias = turn_speed

    property active:
        def __get__(self):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            return data.active
        def __set__(self, bool new):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            data.active = new

    property speed:
        def __get__(self):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            return data.speed
        def __set__(self, float speed):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            data.speed = speed

    property stability:
        def __get__(self):
            return self._gear.max_force
        def __set__(self, float stability):
            self._gear.max_force = stability

    property max_force:
        def __get__(self):
            return self._pivot.max_force
        def __set__(self, float force):
            self._pivot.max_force = force

    property do_movement:
        def __get__(self):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            return data.do_movement
        def __set__(self, bool new):
            cdef SteeringStruct* data = <SteeringStruct*>self.pointer
            data.do_movement = new


cdef class SteeringSystem(StaticMemGameSystem):
    physics_system = StringProperty('cymunk_physics')
    system_id = StringProperty('steering')
    updateable = BooleanProperty(True)
    system_names = ListProperty(['steering','cymunk_physics'])
    processor = BooleanProperty(True)
    type_size = NumericProperty(sizeof(SteeringStruct))
    component_type = ObjectProperty(SteeringComponent)

    def init_component(self, unsigned int component_index, 
        unsigned int entity_id, str zone, dict args):

        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef SteeringComponent py_component = self.components[
            component_index]
        cdef SteeringStruct* component = <SteeringStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        gameworld = self.gameworld
        cdef SystemManager system_manager = gameworld.system_manager
        cdef str physics_id = self.physics_system
        cdef CymunkPhysics physics_system = system_manager[physics_id]
        cdef Body steering_body = Body(None, None)
        cdef IndexedMemoryZone entities = gameworld.entities
        cdef Entity entity = gameworld.entities[entity_id]
        cdef PhysicsComponent physics_data = getattr(entity, physics_id)
        cdef Body body = physics_data.body
        cdef PivotJoint pivot = PivotJoint(steering_body, body, (0, 0), (0, 0))
        cdef GearJoint gear = GearJoint(steering_body, body, 0.0, 1.0)
        gear.error_bias = args.get('gear_error_bias', 0.0)
        pivot.max_bias = args.get('pivot_max_bias', 0.0)
        pivot.error_bias = args.get('pivot_error_Bias', 0.0)
        gear.max_bias = args.get('turn_speed', 90.0)
        gear.max_force = args.get('stability', 360.0)
        pivot.max_force = args.get('max_force', 1000.0)
        cdef Space space = physics_system.space
        space.add(pivot)
        space.add(gear)
        component.gear = gear._gearjoint
        component.pivot = pivot._pivotjoint
        component.steering_body = steering_body._body
        component.do_movement = args.get('do_movement', 1)
        target = args.get('target', (0., 0.))
        component.target[0] = target[0]
        component.target[1] = target[1]
        component.speed = args.get('speed', 250.)
        component.arrived_radius = args.get('arrived_radius', 50.)
        py_component._steering_body = steering_body
        py_component._pivot = pivot
        py_component._gear = gear
        return self.entity_components.add_entity(entity_id, zone)

    def clear_component(self, unsigned int component_index):
        '''
        Clears the component at **component_index**. We must set the 
        pointers in the C struct to empty and the references in the 
        CymunkTouchComponent to None.

        Args:

            component_index (unsigned int): Component to remove.

        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef SteeringStruct* pointer = <SteeringStruct*>(
            memory_zone.get_pointer(component_index))
        cdef SteeringComponent py_component = self.components[
            component_index]
        pointer.entity_id = -1
        pointer.steering_body = NULL
        pointer.pivot = NULL
        pointer.gear = NULL
        pointer.target[0] = 0.
        pointer.target[1] = 0.
        pointer.do_movement = 0
        py_component._pivot = None
        py_component._steering_body = None
        py_component._gear = None

    def remove_component(self, unsigned int component_index):
        gameworld = self.gameworld
        cdef SteeringComponent py_component = self.components[
            component_index]
        cdef str physics_id = self.physics_system
        cdef CymunkPhysics physics_system = gameworld.system_manager[physics_id]
        cdef Space space = physics_system.space
        space.remove(py_component._pivot)
        space.remove(py_component._gear)
        self.entity_components.remove_entity(py_component.entity_id)
        super(SteeringSystem, self).remove_component(component_index)
        
    def update(self, dt):
        gameworld = self.gameworld
        cdef SteeringStruct* steering_component 
        cdef PhysicsStruct* physics_component
        cdef cpBody *body, *steering_body
        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index
        cdef cpVect target, body_pos, move_delta, v1, unrot, velocity_rot
        cdef float turn
        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            steering_component = <SteeringStruct*>component_data[real_index]
            physics_component = <PhysicsStruct*>component_data[real_index+1]
            if steering_component.active:
                body = physics_component.body
                steering_body = steering_component.steering_body

                target = cpv(
                    steering_component.target[0], steering_component.target[1]
                    )
                body_pos = body.p
                move_delta = cpvsub(target, body_pos)
                v1 = body.rot
                unrot = cpvunrotate(v1, move_delta)
                turn = atan2(unrot.y, unrot.x)
                steering_body.a = body.a - turn
                if not steering_component.do_movement:
                    steering_body.v = cpv(0., 0.)
                    continue
                if cpvnear(target, body_pos, steering_component.arrived_radius):
                    velocity_rot = cpv(0., 0.)
                    steering_component.active = False
                elif (turn <= -1.3 or turn >= 1.3):
                    velocity_rot = cpv(0., 0.)
                else:
                    velocity_rot = cpvrotate(
                        v1, cpv(steering_component.speed, 0.0)
                        )  
                steering_body.v = velocity_rot


cdef class SteeringAIComponent: 

    property entity_id:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.entity_id

    property target_id:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.target_id

        def __set__(self, unsigned int value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.target_id = value

    property desired_angle:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.desired_angle

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.desired_angle = value

    property desired_distance:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.desired_distance

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.desired_distance = value

    property angle_variance:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.angle_variance

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.angle_variance = value

    property distance_variance:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.distance_variance

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.distance_variance = value

    property base_distance:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.base_distance

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.base_distance = value

    property base_angle:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.base_angle

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.base_angle = value

    property current_time:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.current_time

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.current_time = value

    property recalculate_time:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.recalculate_time

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.recalculate_time = value

    property query_radius:
        def __get__(self):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            return data.query_radius

        def __set__(self, float value):
            cdef SteeringAIStruct* data = <SteeringAIStruct*>self.pointer
            data.query_radius = value

cdef class SteeringAISystem(StaticMemGameSystem):
    system_id = StringProperty("steering_ai")
    updateable = BooleanProperty(True)
    system_names = ListProperty(['steering_ai', 'steering', 'cymunk_physics'])
    processor = BooleanProperty(True)
    type_size = NumericProperty(sizeof(SteeringAIStruct))
    component_type = ObjectProperty(SteeringAIComponent)
    physics_system = ObjectProperty(None)

    def init_component(self, unsigned int component_index, 
                       unsigned int entity_id, str zone, dict args):
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef SteeringAIStruct* component = <SteeringAIStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        component.target_id = args.get('target', -1)
        component.desired_angle = args.get('desired_angle', radians(180.))
        component.desired_distance = args.get('desired_distance', 250.)
        component.angle_variance = args.get('angle_variance', radians(45.))
        component.distance_variance = args.get('distance_variance', 75.)
        component.base_distance = args.get('base_distance', 250.)
        component.base_angle = args.get('base_angle', radians(0.))
        component.current_time = 0.
        component.query_radius = args.get('query_radius', 150.)
        component.recalculate_time = args.get('recalculate_time', 30.)

        return self.entity_components.add_entity(entity_id, zone)

    cdef cpVect calculate_avoid_vector(self, list obstacles,
                                       PhysicsStruct* entity_physics,
                                       SteeringAIStruct* entity_ai):
        cdef cpVect avoid_vec
        cdef int ob_count = 0
        cdef unsigned int obstacle_id
        cdef IndexedMemoryZone entities = self.gameworld.entities
        cdef unsigned int entity_id = entity_physics.entity_id
        cdef Entity obstacle
        cdef float scale_factor, dist
        cdef PhysicsComponent obstacle_physics
        cdef PhysicsStruct* obst_pointer
        cdef cpVect avoidance_sum = cpVect(0., 0.)
        cdef cpBody *entity_body, *obst_body
        for obstacle_id in obstacles:
            if obstacle_id != entity_id:
                obstacle = entities[obstacle_id]
                obstacle_physics = obstacle.cymunk_physics
                obst_pointer = <PhysicsStruct*>obstacle_physics.pointer
                obst_body = obst_pointer.body
                entity_body = entity_physics.body
                dist = cpvlength(
                    cpvsub(entity_body.p, obst_body.p))
                scale_factor = (
                    (entity_ai.query_radius-dist)/entity_ai.query_radius)
                scale_factor *= (obst_body.m / entity_body.m)
                avoid_vec = cpvmult(
                    cpvnormalize(
                        cpvsub(obst_body.p, entity_body.p)
                        ),
                    scale_factor
                    )
                avoidance_sum = cpvadd(avoidance_sum, avoid_vec)
                ob_count += 1
        if ob_count > 0:
            avoidance_sum = cpvmult(avoidance_sum, 1./ob_count)
        return avoidance_sum

    def update(self, dt):
        gameworld = self.gameworld
        cdef IndexedMemoryZone entities = gameworld.entities
        cdef SteeringStruct* steering_component 
        cdef PhysicsStruct* physics_component
        cdef cpBody *body, *steering_body, *target_body
        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index
        cdef Entity target_entity, current_entity
        cdef PositionComponent2D target_position
        cdef PhysicsComponent target_physics
        cdef CymunkPhysics physics_system = self.physics_system
        cdef cpVect target_pos, unit_vector, actual_target, body_pos, avoid_vec
        cdef list touch_box, touched_ids
        cdef float radius
        cdef float distance_between
        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            ai_component = <SteeringAIStruct*>component_data[real_index]
            steering_component = <SteeringStruct*>component_data[real_index+1]
            physics_component = <PhysicsStruct*>component_data[real_index+2]
            current_entity = entities[ai_component.entity_id]
            body_pos = physics_component.body.p
            ai_component.current_time += dt
            if ai_component.current_time >= ai_component.recalculate_time:
                ai_component.current_time = 0.
                ai_component.desired_angle = uniform(
                    ai_component.base_angle - ai_component.angle_variance,
                    ai_component.base_angle + ai_component.angle_variance
                    )
                ai_component.desired_distance = uniform(
                    ai_component.base_distance - ai_component.distance_variance,
                    ai_component.base_distance + ai_component.distance_variance
                    )
            if ai_component.target_id != -1:
                target_entity = entities[ai_component.target_id]
                if not hasattr(target_entity, 'position'):
                    continue
                target_physics = target_entity.cymunk_physics
                target_body = target_physics._body._body
                target_pos = target_body.p
                unit_vector = cpvforangle(
                    ai_component.desired_angle +target_body.a)
                distance_between = cpvlength(cpvsub(target_pos, body_pos))
                actual_target = cpvadd(
                    cpvmult(
                        unit_vector, ai_component.desired_distance),
                        cpvadd(target_pos, 
                               cpvmult(target_body.v,
                               distance_between / steering_component.speed))
                    )
                radius = ai_component.query_radius
                touch_box = [
                    body_pos.x-radius, body_pos.y-radius,
                    body_pos.x+radius, body_pos.y+radius
                    ]
                touched_ids = physics_system.query_bb(touch_box)
                avoid_vec = cpvmult(
                    self.calculate_avoid_vector(
                        touched_ids, physics_component, ai_component),
                    steering_component.speed
                    )
                actual_target = cpvadd(actual_target, avoid_vec)
                steering_component.target[0] = actual_target.x
                steering_component.target[1] = actual_target.y
                desired_distance = ai_component.desired_distance
                distance_variance = ai_component.distance_variance
                if desired_distance - distance_variance <= distance_between \
                   <= desired_distance + distance_variance:
                    actual_target = target_body.p
                    #If we are near the goal, stop moving and just turn.
                    steering_component.do_movement = False
                else:

                    steering_component.do_movement = True
                steering_component.active = True

            else:
                steering_component.do_movement = False
                steering_component.active = False



    def clear_component(self, unsigned int component_index):
        '''
        Clears the component at **component_index**. We must set the 
        pointers in the C struct to empty and the references in the 
        CymunkTouchComponent to None.

        Args:

            component_index (unsigned int): Component to remove.

        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef SteeringAIStruct* component = <SteeringAIStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = -1
        component.target_id = -1
        component.desired_angle = 0.
        component.desired_distance = 0.
        component.angle_variance = 0.
        component.distance_variance = 0.
        component.base_distance = 0.
        component.base_angle = 0.
        component.current_time = 0.
        component.recalculate_time = 0.
        component.query_radius = 100.


    def remove_component(self, unsigned int component_index):
        cdef SteeringAIComponent py_component = self.components[
            component_index]
        self.entity_components.remove_entity(py_component.entity_id)
        super(SteeringAISystem, self).remove_component(component_index)
        


Factory.register('CymunkTouchSystem', cls=CymunkTouchSystem)
Factory.register('SteeringSystem', cls=SteeringSystem)
Factory.register('SteeringAISystem', cls=SteeringAISystem)