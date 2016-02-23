from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)
from libc.stdlib cimport rand, RAND_MAX
from kivent_projectiles.projectiles cimport ProjectileSystem
from kivent_core.managers.sound_manager cimport SoundManager
from kivent_cymunk.physics cimport PhysicsStruct
include "projectile_config.pxi"


ctypedef struct ProjectileWeapon:
    float reload_time
    int projectile_type
    int ammo_count
    int shot_count
    float spread
    int current_shot
    float shot_timer
    float time_between_shots
    float rate_of_fire
    int in_clip
    int clip_size
    float[MAX_BARRELS*2] barrel_offsets
    float projectile_width
    float projectile_height
    int barrel_count
    int ammo_type
    float accel
    int reload_begin_sound
    int reload_end_sound
    int fire_sound
    int display_name_id


cdef class Weapon:
    cdef ProjectileWeapon *weapon_pointer


cdef class WeaponTemplate:
    cdef ProjectileWeapon weapon_data
    cdef Weapon weapon


ctypedef struct ProjectileWeaponStruct:
    unsigned int entity_id
    int current_weapon
    bint firing
    bint reloading
    float cooldown
    ProjectileWeapon[MAX_WEAPONS] weapons


cdef class ProjectileWeaponComponent(MemComponent):
    pass

cdef class ProjectileWeaponSystem(StaticMemGameSystem):
    cdef dict weapon_templates
    cdef list weapon_display_names
    cdef int weapon_count
    cdef void copy_template_to_weapon(self, str template_name, 
        ProjectileWeapon *weapon)
    cdef void fire_projectile(self, unsigned int entity_id, float accel)
    cdef void handle_multi_shot(self, ProjectileWeaponStruct* system_comp,
        ProjectileWeapon* weapon, PhysicsStruct* physics_comp, 
        SoundManager sound_manager, ProjectileSystem projectile_system,
        float dt)
    cdef void handle_single_shot(self, ProjectileWeaponStruct* system_comp,
        ProjectileWeapon* weapon, PhysicsStruct* physics_comp, 
        SoundManager sound_manager, ProjectileSystem projectile_system,
        float dt)
    cdef void handle_missle(self, ProjectileWeaponStruct* system_comp,
        ProjectileWeapon* weapon, PhysicsStruct* physics_comp, 
        SoundManager sound_manager, ProjectileSystem projectile_system,
        float dt)
    cdef void fire_missle(self, unsigned int entity_id, float accel)


cdef inline float cy_random():
    return <float>rand()/<float>RAND_MAX

cdef inline float random_variance(float base, float variance):
    return base + variance * (cy_random() * 2.0 - 1.0)