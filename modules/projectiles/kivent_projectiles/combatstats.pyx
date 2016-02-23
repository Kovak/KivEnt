from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)
from kivy.properties import (StringProperty, BooleanProperty, ListProperty,
    NumericProperty, ObjectProperty)
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivy.factory import Factory


cdef class CombatStatsComponent(MemComponent):

    def __cinit__(self, MemoryBlock memory_block, unsigned int index,
            unsigned int offset):
        self._destruction_callback = None
        self._on_hit_callback = None

    property destruction_callback:
        def __get__(self):
            return self._destruction_callback
        def __set__(self, new_callback):
            self._destruction_callback = new_callback

    property on_hit_callback:
        def __get__(self):
            return self._on_hit_callback
        def __set__(self, new_callback):
            self._on_hit_callback = new_callback

    property entity_id:
        def __get__(self):
            cdef CombatStatsStruct* data = <CombatStatsStruct*>self.pointer
            return data.entity_id

    property health:
        def __get__(self):
            cdef CombatStatsStruct* data = <CombatStatsStruct*>self.pointer
            return data.health
        def __set__(self, float value):
            cdef CombatStatsStruct* data = <CombatStatsStruct*>self.pointer
            data.health = value

    property armor:
        def __get__(self):
            cdef CombatStatsStruct* data = <CombatStatsStruct*>self.pointer
            return data.armor
        def __set__(self, float value):
            cdef CombatStatsStruct* data = <CombatStatsStruct*>self.pointer
            data.armor = value

    property max_health:
        def __get__(self):
            cdef CombatStatsStruct* data = <CombatStatsStruct*>self.pointer
            return data.max_health
        def __set__(self, float value):
            cdef CombatStatsStruct* data = <CombatStatsStruct*>self.pointer
            data.max_health = value


cdef class CombatStatsSystem(StaticMemGameSystem):
    system_id = StringProperty('combat_stats')
    updateable = BooleanProperty(True)
    processor = BooleanProperty(True)
    type_size = NumericProperty(sizeof(CombatStatsStruct))
    component_type = ObjectProperty(CombatStatsComponent)
    system_names = ListProperty(['combat_stats'])


    def damage_entity(self, unsigned int entity_id, float damage,
        float armor_pen):
        entity = self.gameworld.entities[entity_id]
        cdef CombatStatsComponent py_component = entity.combat_stats
        py_component.health -= (damage + armor_pen - py_component.armor)
        if py_component._on_hit_callback is not None:
            py_component._on_hit_callback(entity_id)

    def init_component(self, unsigned int component_index, 
        unsigned int entity_id, str zone_name, dict args):
        '''
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef CombatStatsStruct* component = <CombatStatsStruct*>(
            memory_zone.get_pointer(component_index)
            )
        cdef CombatStatsComponent py_component = (
            self.components[component_index]
            )
        component.entity_id = entity_id
        cdef float health = args.get('health', 100.)
        component.health = health
        component.max_health = health
        component.armor = args.get('armor', 0.)
        py_component._destruction_callback = args.get('destruction_callback',
            None)
        py_component._on_hit_callback = args.get('on_hit_callback',
            None)
        return self.entity_components.add_entity(entity_id, zone_name)

    def clear_component(self, unsigned int component_index):
        '''
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef CombatStatsStruct* component = <CombatStatsStruct*>(
            memory_zone.get_pointer(component_index))
        cdef CombatStatsComponent py_component = (
            self.components[component_index]
            )
        component.entity_id = -1
        py_component._destruction_callback = None
        py_component._on_hit_callback = None

    def remove_component(self, unsigned int component_index):
        cdef CombatStatsComponent component = self.components[component_index]
        if component._destruction_callback is not None:
            component._destruction_callback(component.entity_id)
        self.entity_components.remove_entity(component.entity_id)
        super(CombatStatsSystem, self).remove_component(component_index)

    def update(self, dt):
        cdef CombatStatsStruct* system_comp
        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index, x, bullet_ent
        remove_entity = self.gameworld.remove_entity

        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            system_comp = <CombatStatsStruct*>component_data[real_index]
            if system_comp.health <= 0.:
                remove_entity(system_comp.entity_id)

Factory.register('CombatStatsSystem', cls=CombatStatsSystem)