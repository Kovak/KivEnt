from kivent_core.managers.resource_managers cimport ModelManager
from kivent_core.managers.animation_manager cimport AnimationManager
from kivent_core.managers.game_manager cimport GameManager
from kivent_core.memory_handlers.block cimport MemoryBlock


cdef class MapManager(GameManager):
    cdef MemoryBlock maps_block
    cdef ModelManager model_manager
    cdef AnimationManager animation_manager
    cdef unsigned int allocation_size
    cdef dict _maps
