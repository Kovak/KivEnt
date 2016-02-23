from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)
from kivy.properties import (StringProperty, BooleanProperty, ListProperty,
    NumericProperty, ObjectProperty)
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivy.factory import Factory


cdef class LifespanComponent(MemComponent):

    property entity_id:
        def __get__(self):
            cdef LifespanStruct* data = <LifespanStruct*>self.pointer
            return data.entity_id

    property current_time:
        def __get__(self):
            cdef LifespanStruct* data = <LifespanStruct*>self.pointer
            return data.current_time
        def __set__(self, float value):
            cdef LifespanStruct* data = <LifespanStruct*>self.pointer
            data.current_time = value

    property lifespan:
        def __get__(self):
            cdef LifespanStruct* data = <LifespanStruct*>self.pointer
            return data.lifespan
        def __set__(self, float value):
            cdef LifespanStruct* data = <LifespanStruct*>self.pointer
            data.lifespan = value

    property paused:
        def __get__(self):
            cdef LifespanStruct* data = <LifespanStruct*>self.pointer
            return data.paused
        def __set__(self, bint value):
            cdef LifespanStruct* data = <LifespanStruct*>self.pointer
            data.paused = value


cdef class LifespanSystem(StaticMemGameSystem):
    system_id = StringProperty('lifespan')
    updateable = BooleanProperty(True)
    processor = BooleanProperty(True)
    type_size = NumericProperty(sizeof(LifespanStruct))
    component_type = ObjectProperty(LifespanComponent)
    system_names = ListProperty(['lifespan'])

    def init_component(self, unsigned int component_index, 
        unsigned int entity_id, str zone_name, dict args):
        '''
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef LifespanStruct* component = <LifespanStruct*>(
            memory_zone.get_pointer(component_index)
            )
        component.entity_id = entity_id
        component.lifespan = args.get('lifespan', 5.)
        component.current_time = 0.0
        component.paused = args.get('paused', 0)
        return self.entity_components.add_entity(entity_id, zone_name)

    def clear_component(self, unsigned int component_index):
        '''
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef LifespanStruct* component = <LifespanStruct*>(
            memory_zone.get_pointer(component_index)
            )
        component.entity_id = -1
        component.current_time = 0.0
        component.paused = 0

    def remove_component(self, unsigned int component_index):
        cdef LifespanComponent component = self.components[component_index]
        self.entity_components.remove_entity(component.entity_id)
        super(LifespanSystem, self).remove_component(component_index)

    def update(self, dt):
        cdef LifespanStruct* system_comp
        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index
        remove_entity = self.gameworld.remove_entity

        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            system_comp = <LifespanStruct*>component_data[real_index]
            if not system_comp.paused:
                system_comp.current_time += dt
            if system_comp.current_time >= system_comp.lifespan:
                remove_entity(system_comp.entity_id)


Factory.register('LifespanSystem', cls=LifespanSystem)