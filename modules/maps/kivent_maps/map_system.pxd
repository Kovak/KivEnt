from kivent_core.systems.staticmemgamesystem cimport StaticMemGameSystem, MemComponent


ctypedef struct MapStruct:
    unsigned int entity_id
    void* tile_map
    unsigned int pos_x
    unsigned int pos_y

cdef class MapComponent(MemComponent):
    pass

cdef class MapSystem(StaticMemGameSystem):
    pass
