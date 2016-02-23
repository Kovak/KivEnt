from cython cimport bint
from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)

include "particle_config.pxi"


cdef class ParticleEmitter:
    cdef str _effect_name
    cdef str _texture
    cdef float _emit_angle_offset
    cdef float _emit_angle
    cdef float[2] _pos
    cdef float[2] _pos_offset
    cdef float _life_span
    cdef bint _paused
    cdef list active_particles
    cdef int _emitter_type
    cdef int _number_of_particles
    cdef int _current_particles
    cdef float _frame_time
    cdef float[2] _gravity
    cdef float[2] _pos_variance
    cdef float _start_scale
    cdef float _emission_rate
    cdef float _start_scale_variance
    cdef float _end_scale
    cdef float _end_scale_variance
    cdef float _emit_angle_variance
    cdef float _start_rotation
    cdef float _start_rotation_variance
    cdef float _end_rotation
    cdef float _end_rotation_variance
    cdef float _life_span_variance
    cdef float _speed
    cdef float _speed_variance
    cdef float _radial_acceleration
    cdef float _radial_acceleration_variance
    cdef float _tangential_acceleration
    cdef float _tangential_acceleration_variance
    cdef float _max_radius
    cdef float _max_radius_variance
    cdef float _min_radius
    cdef float _rotate_per_second
    cdef float _rotate_per_second_variance
    cdef unsigned char[4] _start_color
    cdef unsigned char[4] _start_color_variance
    cdef unsigned char[4] _end_color
    cdef unsigned char[4] _end_color_variance


ctypedef struct EmitterStruct:
    unsigned int entity_id
    void* emitters[MAX_EMITTERS]


cdef class EmitterComponent(MemComponent):
    cdef list _emitters


cdef class EmitterSystem(StaticMemGameSystem):
    cdef dict _emitter_prototypes
    cdef list attributes_to_save
    cdef dict editor_fields
    cdef str subobject_field
    cdef str editor_type
    cdef str subobject_name_field
    cdef dict panels

    cdef int insert_effect_into_component(self, ParticleEmitter effect, 
        EmitterComponent py_component) except -1
    cdef void copy_effect(self, ParticleEmitter from_emitter, 
        ParticleEmitter to_emitter)
