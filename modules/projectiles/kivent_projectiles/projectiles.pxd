from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)


cdef class ProjectileTemplate:
    cdef str texture
    cdef str model
    cdef str tail_effect
    cdef str main_effect
    cdef float damage
    cdef float armor_pierce
    cdef float width
    cdef float height
    cdef float mass
    cdef int projectile_type
    cdef int collision_type
    cdef float speed
    cdef float rot_speed
    cdef float lifespan
    cdef int hit_sound
    cdef object destruction_callback


ctypedef struct ProjectileStruct:
    unsigned int entity_id
    float damage
    float armor_pierce
    int projectile_type
    int main_effect
    int tail_effect
    int hit_sound
    unsigned int origin_entity


cdef class ProjectileComponent(MemComponent):
    pass


cdef class ProjectileSystem(StaticMemGameSystem):
    cdef dict projectile_templates
    cdef dict projectile_keys
    cdef dict collision_type_index
    cdef int projectile_count
    cdef unsigned int create_projectile(self, int ammo_type, tuple position,
        float rotation, unsigned int firing_entity)

