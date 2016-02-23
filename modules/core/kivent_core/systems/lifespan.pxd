from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)

ctypedef struct LifespanStruct:
    unsigned int entity_id
    float lifespan
    float current_time
    bint paused


cdef class LifespanComponent(MemComponent):
    pass

cdef class LifespanSystem(StaticMemGameSystem):
    pass