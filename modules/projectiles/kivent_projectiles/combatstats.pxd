from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)

ctypedef struct CombatStatsStruct:
    unsigned int entity_id
    float health
    float armor
    float max_health


cdef class CombatStatsComponent(MemComponent):
    cdef object _destruction_callback
    cdef object _on_hit_callback


cdef class CombatStatsSystem(StaticMemGameSystem):
    pass
