from kivent_core.systems.staticmemgamesystem cimport (
    StaticMemGameSystem, MemComponent
    )
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivy.factory import Factory
from kivent_core.entity cimport Entity
from kivy.properties import StringProperty, ObjectProperty, NumericProperty
import math
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivent_core.managers.sound_manager cimport SoundManager
include "projectile_config.pxi"

cdef class ProjectileTemplate:

    def __init__(self, float damage, float armor_pierce, int projectile_type,
                 str texture, str model, float width, float height, float mass,
                 int collision_type, float speed, float rot_speed,
                 str main_effect, str tail_effect, float lifespan,
                 int hit_sound, object destruction_callback):
        self.damage = damage
        self.armor_pierce = armor_pierce
        self.projectile_type = projectile_type
        self.texture = texture
        self.model = model
        self.width = width
        self.height = height
        self.mass = mass
        self.collision_type = collision_type
        self.speed = speed
        self.main_effect = main_effect
        self.tail_effect = tail_effect
        self.rot_speed = rot_speed
        self.lifespan = lifespan
        self.hit_sound = hit_sound
        self.destruction_callback = destruction_callback

cdef class ProjectileComponent(MemComponent):

    property entity_id:
        def __get__(self):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            return data.entity_id

    property damage:
        def __get__(self):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            return data.damage
        def __set__(self, float value):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            data.damage = value

    property armor_pierce:
        def __get__(self):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            return data.armor_pierce
        def __set__(self, float value):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            data.armor_pierce = value

    property projectile_type:
        def __get__(self):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            return data.projectile_type
        def __set__(self, int value):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            data.projectile_type = value

    property origin_entity:
        def __get__(self):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            return data.origin_entity
        def __set__(self, unsigned int value):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            data.origin_entity = value

    property hit_sound:
        def __get__(self):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            return data.hit_sound
        def __set__(self, int value):
            cdef ProjectileStruct* data = <ProjectileStruct*>self.pointer
            data.hit_sound = value


cdef class ProjectileSystem(StaticMemGameSystem):
    system_id = StringProperty('projectiles')
    projectile_types =  {'NO_WEAPON': 0, 'SINGLESHOT': 1, 'MISSLE': 2,
        'MULTISHOT': 3}
    projectile_zone = StringProperty('projectiles')
    type_size = NumericProperty(sizeof(ProjectileStruct))
    component_type = ObjectProperty(ProjectileComponent)
    emitter_system = ObjectProperty(None)
    physics_system = ObjectProperty(None)
    combat_stats_system = ObjectProperty(None)
    player_system = ObjectProperty(None)

    def __init__(self, **kwargs):
        super(ProjectileSystem, self).__init__(**kwargs)
        self.projectile_templates = {}
        self.projectile_keys = {}
        self.projectile_count = 0
        self.collision_type_index = {}

    def allocate(self, Buffer master_buffer, dict reserve_spec):
        super(ProjectileSystem, self).allocate(master_buffer, reserve_spec)
        self.register_collision_types()
        self.setup_interprojectile_collisions()

    def register_collision_types(self):
        cdef dict projectile_types = self.projectile_types
        cdef dict collision_type_index = self.collision_type_index
        register_collision_type = self.physics_system.register_collision_type
        cdef int type_int
        cdef str type_key
        for type_key in projectile_types:
            type_int = projectile_types[type_key]
            collision_type_index[type_int] = register_collision_type(type_key)


    property projectile_templates:
        def __get__(self):
            return self.projectile_templates

    property projectile_keys:
        def __get__(self):
            return self.projectile_keys

    property collision_type_index:
        def __get__(self):
            return self.collision_type_index

    def register_projectile_template(self, str name, float damage,
        float armor_pierce, int projectile_type, str texture_key,
        str model_key, float width, float height, float mass,
        float speed, float rot_speed, str main_effect=None,
        str tail_effect=None, float lifespan=5.0, int hit_sound=-1,
        object destruction_callback=None):
        count = self.projectile_count
        self.projectile_keys[name] = count
        self.projectile_templates[count] = ProjectileTemplate(
            damage, armor_pierce, projectile_type, texture_key, model_key,
            width, height, mass, self.collision_type_index[projectile_type],
            speed, rot_speed, main_effect, tail_effect, lifespan, hit_sound,
            destruction_callback
            )
        self.projectile_count += 1
        return count

    def setup_interprojectile_collisions(self):
        type_index = self.collision_type_index
        singleshot_type = type_index[1]
        missle_type = type_index[2]
        multishot_type = type_index[3]
        physics_system = self.physics_system
        physics_system.add_collision_handler(singleshot_type, singleshot_type,
            begin_func=self.on_collision_begin_projectiles)
        physics_system.add_collision_handler(singleshot_type, missle_type,
            begin_func=self.on_collision_begin_projectiles)
        physics_system.add_collision_handler(singleshot_type, multishot_type,
            begin_func=self.on_collision_begin_projectiles)
        physics_system.add_collision_handler(missle_type, missle_type,
            begin_func=self.on_collision_begin_projectiles)
        physics_system.add_collision_handler(missle_type, multishot_type,
            begin_func=self.on_collision_begin_projectiles)
        physics_system.add_collision_handler(multishot_type, multishot_type,
            begin_func=self.on_collision_begin_projectiles)

    def add_custom_collision_type(self, int type_to_register, object callback):
        type_index = self.collision_type_index
        singleshot_type = type_index[1]
        missle_type = type_index[2]
        multishot_type = type_index[3]
        physics_system = self.physics_system
        physics_system.add_collision_handler(singleshot_type, type_to_register,
            begin_func=callback)
        physics_system.add_collision_handler(missle_type, type_to_register,
            begin_func=callback)
        physics_system.add_collision_handler(multishot_type, type_to_register,
            begin_func=callback)

    def add_origin_collision_type(self, int type_to_register):
        type_index = self.collision_type_index
        singleshot_type = type_index[1]
        missle_type = type_index[2]
        multishot_type = type_index[3]
        physics_system = self.physics_system
        physics_system.add_collision_handler(singleshot_type, type_to_register,
            begin_func=self.on_collision_begin_origin_entity)
        physics_system.add_collision_handler(missle_type, type_to_register,
            begin_func=self.on_collision_begin_origin_entity)
        physics_system.add_collision_handler(multishot_type, type_to_register,
            begin_func=self.on_collision_begin_origin_entity)

    def on_collision_begin_projectiles(self, space, arbiter):
        bullet_id = arbiter.shapes[0].body.data
        collision_id = arbiter.shapes[1].body.data
        entities = self.gameworld.entities
        projectile_entity = entities[bullet_id]
        collided_entity = entities[collision_id]
        cdef ProjectileComponent bullet_comp = projectile_entity.projectiles
        cdef ProjectileComponent bullet_comp2 = collided_entity.projectiles
        if bullet_comp.origin_entity != bullet_comp2.origin_entity:
            self.combat_stats_system.damage_entity(
                collision_id,
                bullet_comp.damage, bullet_comp.armor_pierce)
            self.combat_stats_system.damage_entity(
                bullet_id, bullet_comp.damage,
                bullet_comp.armor_pierce)
        return True

    def on_collision_begin_origin_entity(self, space, arbiter):
        bullet_id = arbiter.shapes[0].body.data
        collision_id = arbiter.shapes[1].body.data
        projectile_entity = self.gameworld.entities[bullet_id]
        cdef ProjectileComponent comp = projectile_entity.projectiles
        damage_entity = self.combat_stats_system.damage_entity
        cdef SoundManager sound_manager
        if comp.origin_entity != collision_id:
            damage_entity(collision_id, comp.damage, comp.armor_pierce)
            damage_entity(bullet_id, comp.damage, comp.armor_pierce)
            hit_sound = comp.hit_sound
            if hit_sound != -1:
                volume = self.player_system.get_distance_from_player_scalar(
                    projectile_entity.position.pos, max_distance=500.)
                sound_manager = self.gameworld.sound_manager
                sound_manager.play_direct(hit_sound, volume)
        return True

    cdef unsigned int create_projectile(self, int ammo_type, tuple position,
        float rotation, unsigned int firing_entity):
        cdef ProjectileTemplate template = self.projectile_templates[ammo_type]
        gameworld = self.gameworld
        box_dict = {
            'width': template.width, 
            'height': template.height,
            'mass': template.mass}
        col_shape_dict = {
            'shape_type': 'box', 'elasticity': .5, 
            'collision_type': template.collision_type,
            'shape_info': box_dict, 'friction': 1.0
            }
        physics_component_dict = {
            'main_shape': 'box', 
            'velocity': (0, 0), 'position': position, 'angle': rotation, 
            'angular_velocity': 0, 'mass': template.mass, 
            'vel_limit': template.speed, 
            'ang_vel_limit': math.radians(template.rot_speed), 
            'col_shapes': [col_shape_dict]}
        projectile_dict = {
            'damage': template.damage,
            'projectile_type': template.projectile_type,
            'armor_pierce': template.armor_pierce,
            'origin_entity': firing_entity,
            'hit_sound': template.hit_sound
        }
        create_component_dict = {
            'position': position,
            'rotate': rotation,
            'cymunk_physics': physics_component_dict,
            'projectiles': projectile_dict,
            'emitters': [],
            'lifespan': {'lifespan': template.lifespan},
            'combat_stats': {
                        'health': template.damage,
                        'destruction_callback': template.destruction_callback
                        },
            'rotate_renderer': {
                'model_key': template.model, 'texture': template.texture
                }
        }
        component_order = [
            'position', 'rotate', 'cymunk_physics',
            'rotate_renderer', 'emitters',  
            'projectiles', 'combat_stats', 'lifespan'
            ]
        if template.model is None and template.texture is None:
            component_order.remove('rotate_renderer')
        cdef unsigned int entity_id = gameworld.init_entity(
            create_component_dict, component_order, 
            zone=self.projectile_zone,
                )
        cdef Entity entity
        cdef ProjectileComponent component
        cdef ProjectileStruct* projectiles

        if template.main_effect is not None or template.tail_effect is not None:
            entity = gameworld.entities[entity_id]
            component = entity.projectiles
            projectiles = <ProjectileStruct*>component.pointer
            if template.main_effect is not None:
                projectiles.main_effect = self.emitter_system.add_effect(
                        entity_id, template.main_effect)
                    
            if template.tail_effect is not None:
                projectiles.tail_effect = self.emitter_system.add_effect(
                        entity_id, template.tail_effect)

        return entity_id


    def init_component(self, unsigned int component_index, 
        unsigned int entity_id, str zone_name, dict args):
        '''
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef ProjectileStruct* component = <ProjectileStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = entity_id
        component.damage = args.get('damage')
        component.projectile_type = args.get('projectile_type', NO_WEAPON)
        component.armor_pierce = args.get('armor_pierce', 0.)
        component.origin_entity = args.get('origin_entity', -1)
        component.hit_sound = args.get('hit_sound', -1)


    def clear_component(self, unsigned int component_index):
        '''
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef ProjectileStruct* component = <ProjectileStruct*>(
            memory_zone.get_pointer(component_index))
        component.entity_id = -1
        component.origin_entity = -1
        component.projectile_type = NO_WEAPON
        component.damage = 0.
        component.armor_pierce = 0.
        component.main_effect = -1
        component.tail_effect = -1
        component.hit_sound = -1


Factory.register('ProjectileSystem', cls=ProjectileSystem)