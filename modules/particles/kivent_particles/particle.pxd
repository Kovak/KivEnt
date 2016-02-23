from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)
from kivent_particles.emitter cimport ParticleEmitter

ctypedef struct ParticleStruct:
    unsigned int entity_id
    float current_time
    float total_time
    float[2] start_pos
    float[2] velocity
    float radial_acceleration
    float tangential_acceleration
    float emit_radius
    float emit_radius_delta
    float emit_rotation
    float emit_rotation_delta
    float rotation_delta
    float scale_delta
    void* emitter
    float[4] color_delta
    float[4] color


cdef class ParticleComponent(MemComponent):
    pass


cdef class ParticleSystem(StaticMemGameSystem):
    cdef list _system_names
    cdef unsigned int create_particle(self, ParticleEmitter emitter) except -1