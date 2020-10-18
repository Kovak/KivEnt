from kivent_core.systems.staticmemgamesystem cimport MemComponent
from kivent_core.managers.system_manager cimport SystemManager

cdef class Entity(MemComponent):
    cdef list _load_order
    cdef SystemManager system_manager
    cdef int set_component(self, unsigned int component_id,
        unsigned int system_index) except 0
    cpdef unsigned int get_component_index(self, str name)
    cdef unsigned int get_component_index_c(self, unsigned int system_index)
