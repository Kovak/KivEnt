from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)

ctypedef struct WeaponAIStruct:
    unsigned int entity_id
    float line_of_sight
    int team
    bint active
    unsigned int target_id
    float cone_size

cdef class WeaponAISystem(StaticMemGameSystem):
    pass

cdef class WeaponAIComponent(MemComponent):
    pass