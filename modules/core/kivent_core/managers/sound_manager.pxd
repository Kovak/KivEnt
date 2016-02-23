from kivy._event cimport EventDispatcher

cdef class SoundManager(EventDispatcher):
    cdef dict sound_dict
    cdef dict sound_keys
    cdef int sound_count
    cdef dict music_dict
    cpdef play_direct(self, int sound_index, float volume)
    cpdef play_direct_loop(self, int sound_index, float volume)
    cpdef stop_direct(self, int sound_index)