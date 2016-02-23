from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem,
                                                     MemComponent)
from cymunk.cymunk cimport (
    GearJoint, PivotJoint, Vec2d, cpVect, cpv,
    cpFloat, cpBool, cpvunrotate, cpvrotate, cpvdot, cpvsub, cpvnear,
    cpBody, cpvmult, cpvlerp, Space, cpvforangle, cpvadd, cpvlength,
    cpvnormalize,
    )
from kivent_cymunk.physics cimport (
    PhysicsComponent, PhysicsStruct, CymunkPhysics
    )
from kivy.properties import (ListProperty, NumericProperty, BooleanProperty,
                            StringProperty, ObjectProperty)
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivy.factory import Factory
from kivent_projectiles.weapons cimport ProjectileWeaponStruct
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from math import radians

cdef class WeaponAIComponent: 

    property entity_id:
        def __get__(self):
            cdef WeaponAIStruct* data = <WeaponAIStruct*>self.pointer
            return data.entity_id

    property target_id:
        def __get__(self):
            cdef WeaponAIStruct* data = <WeaponAIStruct*>self.pointer
            return data.target_id

        def __set__(self, unsigned int value):
            cdef WeaponAIStruct* data = <WeaponAIStruct*>self.pointer
            data.target_id = value

    property line_of_sight:
        def __get__(self):
            cdef WeaponAIStruct* data = <WeaponAIStruct*>self.pointer
            return data.line_of_sight

        def __set__(self, float value):
            cdef WeaponAIStruct* data = <WeaponAIStruct*>self.pointer
            data.line_of_sight = value

    property cone_size:
        def __get__(self):
            cdef WeaponAIStruct* data = <WeaponAIStruct*>self.pointer
            return data.cone_size

        def __set__(self, float value):
            cdef WeaponAIStruct* data = <WeaponAIStruct*>self.pointer
            data.cone_size = value


cdef class WeaponAISystem(StaticMemGameSystem):
    system_id = StringProperty('weapon_ai')
    updateable = BooleanProperty(True)
    processor = BooleanProperty(True)
    type_size = NumericProperty(sizeof(WeaponAIStruct))
    component_type = ObjectProperty(WeaponAIComponent)
    system_names = ListProperty(['weapon_ai','cymunk_physics', 
                                'projectile_weapons'])
    physics_system = ObjectProperty(None)

    def init_component(self, unsigned int component_index, 
                       unsigned int entity_id, str zone, dict args):
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef WeaponAIStruct* component = <WeaponAIStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        component.line_of_sight = args.get('line_of_sight', 1000.)
        component.team = args.get('team', -1)
        component.active = args.get('active', True)
        component.cone_size = args.get('cone_size', 10.)
        component.target_id = args.get('target_id', -1)
        return self.entity_components.add_entity(entity_id, zone)


    def update(self, dt):
        gameworld = self.gameworld
        cdef IndexedMemoryZone entities = gameworld.entities
        cdef WeaponAIStruct* ai_component 
        cdef PhysicsStruct* physics_component
        cdef ProjectileWeaponStruct* weapons_component
        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index
        cdef CymunkPhysics physics_system = self.physics_system
        cdef object query_segment = physics_system.query_segment
        cdef list in_sight
        cdef set entities_in_sight
        cdef cpBody* body
        cdef cpVect unit_vector, sight_end, unit2, unit3
        cdef cpVect sight_end2, sight_end3
        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            ai_component = <WeaponAIStruct*>component_data[real_index]
            physics_component = <PhysicsStruct*>component_data[real_index+1]
            weapons_component = <ProjectileWeaponStruct*>component_data[
                real_index+2]
            if not ai_component.active:
                continue
            body = physics_component.body
            unit2 = cpvforangle(body.a + radians(ai_component.cone_size))
            unit3 = cpvforangle(body.a + radians(-ai_component.cone_size))
            sight_end2 = cpvadd(cpvmult(
                unit2, ai_component.line_of_sight), body.p)
            sight_end3 = cpvadd(cpvmult(
                unit3, ai_component.line_of_sight), body.p)
            sight_end = cpvadd(cpvmult(
                body.rot, ai_component.line_of_sight), body.p)
            in_sight = query_segment((body.p.x, body.p.y),
                                     (sight_end.x, sight_end.y))
            in_sight2 = query_segment((body.p.x, body.p.y),
                                      (sight_end2.x, sight_end2.y))
            in_sight3 = query_segment((body.p.x, body.p.y),
                                      (sight_end3.x, sight_end3.y))
            entities_in_sight = set(
                [element[0] for element in in_sight + in_sight2 + in_sight3])
            if ai_component.target_id in entities_in_sight:
                weapons_component.firing = True




    def clear_component(self, unsigned int component_index):
        '''
        Clears the component at **component_index**. We must set the 
        pointers in the C struct to empty and the references in the 
        CymunkTouchComponent to None.

        Args:

            component_index (unsigned int): Component to remove.

        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef WeaponAIStruct* component = <WeaponAIStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = -1
        component.line_of_sight = 1000.
        component.team = -1
        component.active = False
        component.target_id = -1



    def remove_component(self, unsigned int component_index):
        cdef WeaponAIComponent py_component = self.components[
            component_index]
        self.entity_components.remove_entity(py_component.entity_id)
        super(WeaponAISystem, self).remove_component(component_index)
        
Factory.register('WeaponAISystem', cls=WeaponAISystem)