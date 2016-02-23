from cymunk.cymunk cimport Body, cpBody, Space
from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)


cdef class PhysicsComponent(MemComponent):
    cdef Body _body
    cdef list _shapes
    cdef str _shape_type

ctypedef struct PhysicsStruct:
    unsigned int entity_id
    cpBody* body


cdef class CymunkPhysics(StaticMemGameSystem):
    cdef Space space
    cdef list bb_query_result
    cdef list on_screen_result
    cdef list segment_query_result
    cdef int collision_type_count
    cdef dict collision_type_index

    cdef unsigned int _init_component(self, unsigned int component_index, 
        unsigned int entity_id, cpBody* body, str zone_name) except -1
    cdef int _clear_component(self, unsigned int component_index) except 0




