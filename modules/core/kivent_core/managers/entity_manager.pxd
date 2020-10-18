from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from kivent_core.managers.game_manager cimport GameManager

cdef class EntityManager(GameManager):
    cdef IndexedMemoryZone memory_index
    cdef unsigned int system_count

    cdef void clear_entity(self, unsigned int entity_id)
    cdef int set_component(self, unsigned int entity_id,
        unsigned int component_id, unsigned int system_id) except 0
    cdef unsigned int generate_entity(self, str zone) except -1
    cdef void remove_entity(self, unsigned int entity_id)
    cdef void set_entity_active(self, unsigned int entity_id)
    cdef unsigned int get_size(self)
    cpdef unsigned int get_active_entity_count(self)
    cpdef unsigned int get_active_entity_count_in_zone(self, str zone) except <unsigned int>-1