from kivy.properties import (StringProperty, ListProperty, 
NumericProperty, BooleanProperty, DictProperty)
from kivent_cython import (GameSystem)
from kivy.clock import Clock
from functools import partial
from kivy.vector import Vector
import math

class ShipAISystem(GameSystem):
    updateable = BooleanProperty(True)
    cycles_to_skip = NumericProperty(5)
    cycle_count = NumericProperty(0)
    number_of_enemies = NumericProperty(0)

    def remove_entity(self, entity_id):
        super(ShipAISystem, self).remove_entity(entity_id)
        self.number_of_enemies -= 1

    def create_component(self, entity_id, entity_component_dict):
        self.number_of_enemies += 1
        entity_component_dict['distance_to_target'] = 0.
        entity_component_dict['angle_tolerance'] = 10.
        entity_component_dict['follow_distance'] = 300
        entity_component_dict['site_distance'] = 650
        entity_component_dict['ai_state'] = 'follow'
        entity_component_dict['ready_to_fire'] = True
        entity_component_dict['rockets_ready'] = True
        entity_component_dict['attack_delay'] = .25
        entity_component_dict['rocket_delay'] = 6.5
        entity_component_dict['burst_number'] = 5
        entity_component_dict['burst_delay'] = 5.
        entity_component_dict['shot_count'] = 0
        super(ShipAISystem, self).create_component(entity_id, entity_component_dict)


    def query_physics_bb(self, position, radius):
        physics_system = self.gameworld.systems['cymunk-physics']
        bb_list = [position[0] - radius, position[1] - radius, position[0] + radius, position[1] + radius]
        in_radius = physics_system.query_bb(bb_list)
        return in_radius
    

    def calculate_desired_vector(self, target, location, ship_data, ship_ai_data):
        g_map = self.gameworld.systems['default_map']
        map_size_x = g_map.map_size[0]/1.9
        map_size_y = g_map.map_size[1]/1.9
        dist_x = math.fabs(target[0] - location[0])
        dist_y = math.fabs(target[1] - location[1])
        ship_ai_data['distance_to_target'] = Vector(target).distance2(location)
        max_speed = ship_data['max_speed']
        v = Vector(target) - Vector(location)
        v = v.normalize()
        v *= max_speed
        if ship_ai_data['ai_state'] == 'flee':
            v *= -1
        if dist_x > map_size_x:
            v[0] *=-1
        if dist_y > map_size_y:
            v[1] *=-1
        return v

    def calculate_desired_angle_delta(self, target_vector, unit_vector):
        desired_angle_delta = Vector(unit_vector).angle((target_vector[0], 
            target_vector[1]))
        return desired_angle_delta

    def do_turning(self, target_vector, unit_vector, ship_data, ship_ai_data, physics_body):
        desired_angle_change = self.calculate_desired_angle_delta(
            target_vector, unit_vector)
        turn_speed = ship_data['ang_accel']
        desired_multiplier = math.fabs(
            desired_angle_change / math.degrees(turn_speed))
        ship_data['turn_speed_multiplier'] = min(1.0, desired_multiplier)
        angle_tolerance = ship_ai_data['angle_tolerance']
        if desired_angle_change < -angle_tolerance:
            ship_data['is_turning'] = 'left'
        if desired_angle_change > angle_tolerance:
            ship_data['is_turning'] = 'right'
        if -angle_tolerance <= desired_angle_change <= angle_tolerance:
            ship_data['is_turning'] = 'zero'
            physics_body.angular_velocity = 0
        return desired_angle_change

    def query_view(self, position, unit_vector, site_distance):
        unit_vector = Vector(unit_vector)
        physics_system = self.gameworld.systems['cymunk-physics']
        vec_start = Vector(position) + unit_vector
        vec_end = Vector(position) + unit_vector*site_distance
        in_view = physics_system.query_segment(vec_start, vec_end)
        return in_view


    def avoid_obstacles_vector(self, entity_id, position):
        entities = self.gameworld.entities
        obstacles_to_avoid = self.query_physics_bb(position, 100)
        sum_avoidance = Vector(0, 0)
        ob_count = 0
        for obstacle in obstacles_to_avoid:
            if obstacle != entity_id:
                obstacle = entities[obstacle]
                ob_location = obstacle['cymunk-physics']['position']
                dist = Vector(ob_location).distance(position)
                scale_factor = (150.-dist)/150.
                avoidance_vector = Vector(position) - Vector(ob_location)
                avoidance_vector = avoidance_vector.normalize()
                avoidance_vector *= scale_factor
                sum_avoidance += avoidance_vector
                ob_count += 1
        if ob_count > 0:
            sum_avoidance /= float(ob_count)
        sum_avoidance *= entities[entity_id]['ship_system']['max_speed']
        return sum_avoidance

    def do_thrusting(self, ship_data, entity_engine_effect, 
        desired_angle, ship_ai_data):
        follow_distance = ship_ai_data['follow_distance'] * ship_ai_data['follow_distance']
        max_speed = ship_data['max_speed']
        max_speed2 = max_speed * max_speed
        distance_to_target = ship_ai_data['distance_to_target']
        desired_multiplier = 1.0
        if ship_ai_data['ai_state'] == 'follow':
            if distance_to_target < follow_distance:
                desired_multiplier = math.fabs((distance_to_target-follow_distance)/(max_speed2))
        ship_data['engine_speed_multiplier'] = min(1.0, desired_multiplier)
        if distance_to_target > follow_distance or ship_ai_data['ai_state'] == 'flee':
            if -45 <= desired_angle <= 45 and not None:
                ship_data['fire_engines'] = True
                entity_engine_effect['particle_system_on'] = True
            else: 
                ship_data['fire_engines'] = False
                entity_engine_effect['particle_system_on'] = False
        else: 
            ship_data['fire_engines'] = False
            entity_engine_effect['particle_system_on'] = False

    def reset_ship_fire_status(self, entity_id, dt):
        entities = self.gameworld.entities
        entity = entities[entity_id]
        if 'ship_ai_system' in entity:
            entity['ship_ai_system']['ready_to_fire'] = True

    def reset_rockets_ready(self, entity_id, dt):
        entities = self.gameworld.entities
        entity = entities[entity_id]
        if 'ship_ai_system' in entity:
            entity['ship_ai_system']['rockets_ready'] = True

    def fire_weapons(self, entity_id):
        systems = self.gameworld.systems
        ship_system = systems['ship_system']
        ship_system.fire_projectiles(entity_id)

    def determine_fire_weapons(self, position, unit_vector, ship_ai_data, ship_data, entity_id):
        gameworld = self.gameworld
        systems = gameworld.systems
        in_view = self.query_view(position, unit_vector, ship_ai_data['site_distance'])
        if in_view != [] and ship_ai_data['ready_to_fire']:
            entities_in_view = zip(*in_view)[0]
            current_player_character_id = systems['player_character'].current_character_id
            if current_player_character_id in entities_in_view:
                projectile_system = systems['projectile_system']
                weapon_type = ship_data['projectile_type'] + ship_data['current_projectile_type']
                delay = projectile_system.projectiles_dict[weapon_type]['cooldown'] + ship_ai_data['attack_delay']
                fired_rocket = False
                if ship_ai_data['rockets_ready']:
                    ship_ai_data['rockets_ready'] = False
                    fired_rocket = True
                    ship_data['current_projectile_type'] = '_rocket'
                    Clock.schedule_once(partial(self.reset_rockets_ready, entity_id), ship_ai_data['rocket_delay'])
                self.fire_weapons(entity_id)
                if fired_rocket:
                    ship_data['current_projectile_type'] = '_bullet'
                ship_ai_data['ready_to_fire'] = False
                if ship_ai_data['shot_count'] < ship_ai_data['burst_number']:
                    ship_ai_data['shot_count'] += 1
                    Clock.schedule_once(partial(self.reset_ship_fire_status, entity_id), delay)
                else:
                    ship_ai_data['shot_count'] = 0
                    Clock.schedule_once(partial(self.reset_ship_fire_status, entity_id), ship_ai_data['burst_delay'])

    def update(self, dt):
        if self.cycle_count < self.cycles_to_skip:
            self.cycle_count += 1
        else:
            self.cycle_count = 0
            gameworld = self.gameworld
            entities = gameworld.entities

            for entity_id in self.entity_ids:
                entity = entities[entity_id]
                physics_data = entity['cymunk-physics']
                ship_data = entity['ship_system']
                ship_ai_data = entity['ship_ai_system']
                velocity = physics_data['body'].velocity
                position = physics_data['position']
                follow_distance = ship_ai_data['follow_distance']
                unit_vector = physics_data['unit_vector']
                target_position = self.target_player(dt)
                self.determine_fire_weapons(position, unit_vector, 
                    ship_ai_data, ship_data, entity_id)
                if target_position == None:
                    target_position = position
                dist = Vector(target_position).distance(position)
                if dist > follow_distance and ship_ai_data['ai_state'] == 'flee': 
                    ship_ai_data['ai_state'] = 'follow'
                if dist < 100 and ship_ai_data['ai_state'] == 'follow':
                    ship_ai_data['ai_state'] = 'flee'
                desired_vector = self.calculate_desired_vector(target_position, 
                    position, ship_data, ship_ai_data)
                desired_vector *= 1.5
                avoidance_vector = self.avoid_obstacles_vector(entity_id, position)
                avoidance_vector *= .25
                desired_vector = (desired_vector + avoidance_vector)
                steering_vector = desired_vector - Vector(velocity)
                self.steer(steering_vector, entity)


    def steer(self, target_vector, entity):
        physics_data = entity['cymunk-physics']
        ship_data = entity['ship_system']
        unit_vector = physics_data['unit_vector']
        entity_engine_effect = entity['particle_manager']['engine_effect']
        ship_ai_data = entity['ship_ai_system']
        desired_angle = self.do_turning(target_vector, unit_vector, 
            ship_data, ship_ai_data, physics_data['body'])
        self.do_thrusting(ship_data, entity_engine_effect, 
            desired_angle, ship_ai_data)

    def target_player(self, dt):
        gameworld = self.gameworld
        entities = gameworld.entities
        character_system = gameworld.systems['player_character']
        current_player_character_id = character_system.current_character_id
        if current_player_character_id:
            current_player_character = entities[current_player_character_id]
            target_physics_data = current_player_character['cymunk-physics']
            target_position = Vector(target_physics_data['position'])
            velocity = Vector(target_physics_data['body'].velocity)
            velocity *= dt *self.cycles_to_skip
            target_position+= velocity
            return target_position
        else:
            return None

            
class ShipSystem(GameSystem):
    ship_dicts = DictProperty(None)
    updateable = BooleanProperty(True)

    def __init__(self, **kwargs):
        super(ShipSystem, self).__init__(**kwargs)
        self.setup_ship_dicts()

    def update_death_animation(self, entity_id, dt):
        entity = self.gameworld.entities[entity_id]
        entity['physics_renderer']['render'] = False
        entity['particle_manager']['explosion_effect']['particle_system'].emitter_type = 0

    def do_death(self, entity_id):
        gameworld = self.gameworld
        sound_system = gameworld.systems['sound_system']
        entity = gameworld.entities[entity_id]
        entity['particle_manager']['engine_effect']['particle_system_on'] = False
        entity['particle_manager']['explosion_effect']['particle_system_on'] = True
        sound_system.play('shipexplosion')
        Clock.schedule_once(partial(self.update_death_animation, entity_id), .5)
        Clock.schedule_once(partial(self.gameworld.timed_remove_entity, 
            entity_id), 2.0)
        if 'player_character' in entity:
            Clock.schedule_once(self.gameworld.parent.player_lose, 4.0)


    def spawn_player_character(self, character_to_spawn):
        self.spawn_ship_with_dict(self.ship_dicts[character_to_spawn], True, (500, 500))

    def setup_ship_dicts(self):
        ship_dicts = self.ship_dicts
        ship_dicts['ship_1'] = {'name': 'Bulldog','health': 180, 'mass': 250, 'max_speed': 150, 
        'max_turn_speed': 90, 'accel': 15000,'angular_accel': 45, 'caliber': '14px', 
        'num_weapons': 2, 'texture': 'assets/ships/ship1-1.png', 'price': 1000,
        'width': 108, 'height': 96, 'offset_distance': 50, 'color': 'green',
        'engine_effect': 'assets/pexfiles/engine_burn_effect3.pex', 'engine_offset': 65,
        'explosion_effect': 'assets/pexfiles/ship_explosion1.pex',
        'hard_points': [(46, 59), (-46, 59)], 
        'total_rocket_ammo': 40, 'total_bullet_ammo': 200}
        ship_dicts['ship_2'] = {'name': 'Falcon','health': 150, 'mass': 175,'max_speed': 190, 
        'max_turn_speed': 100, 'accel': 20000,'angular_accel': 75, 'caliber': '6px', 
        'num_weapons': 4, 'texture': 'assets/ships/ship3.png', 'price': 1000,
        'width': 130, 'height': 70, 'offset_distance': 50, 'color': 'orange',
        'engine_effect': 'assets/pexfiles/engine_burn_effect4.pex', 'engine_offset': 30,
        'explosion_effect': 'assets/pexfiles/ship_explosion1.pex',
        'hard_points': [(38, 30), (-38, 30), (52, 30), (-52, 30)], 
        'total_rocket_ammo': 60, 'total_bullet_ammo': 400}
        ship_dicts['ship_3'] = {'name': 'Monarch','health': 165, 'mass': 220,'max_speed': 180, 
        'max_turn_speed': 130, 'accel': 25000,'angular_accel': 100, 'caliber': '8px', 
        'num_weapons': 2, 'texture': 'assets/ships/ship2-1.png', 'price': 1000,
        'width': 90, 'height': 104, 'offset_distance': 50, 'color': 'blue',
        'engine_effect': 'assets/pexfiles/engine_burn_effect2.pex', 'engine_offset': 50,
        'explosion_effect': 'assets/pexfiles/ship_explosion1.pex',
        'hard_points': [(28, 51), (-28, 51)],
        'total_rocket_ammo': 30, 'total_bullet_ammo': 240}
        ship_dicts['ship_4'] = {'name': 'Archon','health': 130, 'mass': 140,'max_speed': 200, 
        'max_turn_speed': 110, 'accel': 18000,'angular_accel': 50, 'caliber': '14px', 
        'num_weapons': 1, 'texture': 'assets/ships/ship5.png', 'price': 1000,
        'width': 62, 'height': 100, 'offset_distance': 50, 'color': 'orange',
        'engine_effect': 'assets/pexfiles/engine_burn_effect6.pex', 'engine_offset': 27,
        'explosion_effect': 'assets/pexfiles/ship_explosion1.pex',
        'hard_points': [(-18, 63)], 'total_rocket_ammo': 15, 'total_bullet_ammo': 150}
        ship_dicts['ship_5'] = {'name': 'Cavalier','health': 110, 'mass': 120,'max_speed': 220, 
        'max_turn_speed': 125, 'accel': 22000,'angular_accel': 45, 'caliber': '8px', 
        'num_weapons': 1, 'texture': 'assets/ships/ship6.png', 'price': 1000,
        'width': 66, 'height': 80, 'offset_distance': 50, 'color': 'green',
        'engine_effect': 'assets/pexfiles/engine_burn_effect8.pex', 'engine_offset': 47,
        'explosion_effect': 'assets/pexfiles/ship_explosion1.pex',
        'hard_points': [(0, 47)], 'total_rocket_ammo': 12, 'total_bullet_ammo': 200}
        ship_dicts['ship_6'] = {'name': 'Shield','health': 150, 'mass': 160,'max_speed': 180, 
        'max_turn_speed': 150, 'accel': 25000,'angular_accel': 115, 'caliber': '6px', 
        'num_weapons': 2, 'texture': 'assets/ships/ship7.png', 'price': 1000,
        'width': 76, 'height': 80, 'offset_distance': 50, 'color': 'blue',
        'engine_effect': 'assets/pexfiles/engine_burn_effect9.pex', 'engine_offset': 45,
        'explosion_effect': 'assets/pexfiles/ship_explosion1.pex',
        'hard_points': [(-6, 47), (6, 47)], 'total_rocket_ammo': 30, 'total_bullet_ammo': 200}
        
    def get_ship_values(self, ship_name):
        if ship_name in self.ship_dicts:
            return self.ship_dicts[ship_name] 
        else:
            print 'ship: ', ship_name, 'does not exist'

    def clear_ships(self):
        for entity_id in self.entity_ids:
            Clock.schedule_once(partial(self.gameworld.timed_remove_entity, entity_id))

    def fire_projectiles(self, entity_id):
        gameworld = self.gameworld
        is_character = False
        player_character_system = gameworld.systems['player_character']
        if entity_id == player_character_system.current_character_id:
            is_character = True
        character = gameworld.entities[entity_id]
        projectile_system = gameworld.systems['projectile_system']
        sound_system = gameworld.systems['sound_system']
        ship_system_data = character['ship_system']
        current_projectile_type = ship_system_data['current_projectile_type']
        current_bullet_ammo = ship_system_data['current_bullet_ammo']
        current_rocket_ammo = ship_system_data['current_rocket_ammo']
        projectiles_dict = projectile_system.projectiles_dict
        projectile_type = ship_system_data['projectile_type']+current_projectile_type
        projectile_width = projectiles_dict[projectile_type]['width']
        projectile_height = projectiles_dict[projectile_type]['height']
        character_physics = character['cymunk-physics']
        character_position = character_physics['position']
        number_of_shots = len(ship_system_data['hard_points'])
        if ((current_projectile_type == '_bullet' and current_bullet_ammo - number_of_shots >= 0) or 
            (current_projectile_type == '_rocket' and current_rocket_ammo - number_of_shots >= 0)):
            for hard_point in ship_system_data['hard_points']:
                position_offset = hard_point[0], hard_point[1] + projectile_height*.5
                position_offset_rotated = Vector(position_offset).rotate(character_physics['angle'])
                location = (character_position[0] + position_offset_rotated[0],
                    character_position[1] + position_offset_rotated[1])
                angle = character_physics['body'].angle
                projectile_system.spawn_projectile(projectile_type, location, 
                    angle, ship_system_data['color'])
            if current_projectile_type == '_bullet':
                ship_system_data['current_bullet_ammo'] -= number_of_shots
                if is_character:
                    Clock.schedule_once(partial(sound_system.schedule_play, 'bulletfire'))
                    player_character_system.current_bullet_ammo = ship_system_data['current_bullet_ammo']
            if current_projectile_type == '_rocket':
                ship_system_data['current_rocket_ammo'] -= number_of_shots
                if is_character:
                    Clock.schedule_once(partial(sound_system.schedule_play, 'rocketfire'))
                    player_character_system.current_rocket_ammo = ship_system_data['current_rocket_ammo']
                    

    def update(self, dt):
        for entity_id in self.entity_ids:
            character = self.gameworld.entities[entity_id]
            physics_data = character['cymunk-physics']
            physics_body = physics_data['body']
            system_data = character[self.system_id]
            if system_data['fire_engines'] and 'unit_vector' in physics_data:   
                unit_vector = physics_data['unit_vector']
                offset = (system_data['offset_distance'] * -unit_vector[0], 
                system_data['offset_distance'] * -unit_vector[1])
                force = (system_data['engine_speed_multiplier'] * system_data['accel']*dt * unit_vector[0], 
                system_data['engine_speed_multiplier'] * system_data['accel']*dt * unit_vector[1])
                physics_body.apply_impulse(force, offset)
            if physics_body.is_sleeping:
                physics_body.activate()
            turning = system_data['is_turning']
            if turning == 'left':
                physics_body.angular_velocity += system_data['turn_speed_multiplier']*system_data['ang_accel']*dt
            elif turning == 'right':
                physics_body.angular_velocity -= system_data['turn_speed_multiplier']*system_data['ang_accel']*dt
            if system_data['health'] <= 0 and not system_data['character_dying']:
                self.do_death(entity_id)
                system_data['character_dying'] = True
                
    def damage(self, entity_id, damage):
        system_id = self.system_id
        entities = self.gameworld.entities
        entity = entities[entity_id]
        system_data = entity[system_id]
        system_data['health'] -= damage
        if system_data['health'] < 0:
            system_data['health'] = 0
        player_character_system = self.gameworld.systems['player_character']
        if entity_id == player_character_system.current_character_id:
            player_character_system.current_health = system_data['health']

    def collision_begin_ship_probe(self, space, arbiter):
        gameworld = self.gameworld
        systems = gameworld.systems
        entities = gameworld.entities
        character_id = systems['player_character'].current_character_id
        probe_id = arbiter.shapes[1].body.data
        ship_id = arbiter.shapes[0].body.data
        if ship_id == character_id:
            probe = entities[probe_id]
            ship = entities[ship_id]
            ship['ship_system']['current_probes'] += 1
            sound_system = systems['sound_system']
            Clock.schedule_once(partial(sound_system.schedule_play, 'probepickup'))
            Clock.schedule_once(partial(gameworld.timed_remove_entity, probe_id))
            return False
        else:
            return True

    def collision_begin_ship_asteroid(self, space, arbiter):
        gameworld = self.gameworld
        systems = gameworld.systems
        entities = gameworld.entities
        character_id = systems['player_character'].current_character_id
        asteroid_id = arbiter.shapes[1].body.data
        ship_id = arbiter.shapes[0].body.data
        asteroid = entities[asteroid_id]
        asteroid_damage = asteroid['asteroid_system']['damage']
        self.damage(ship_id, asteroid_damage)
        if ship_id == character_id:
            sound_system = systems['sound_system']
            Clock.schedule_once(partial(sound_system.schedule_play, 'asteroidhitship'))
        return True



    def spawn_ship_with_dict(self, ship_dict, is_player_character, position):
        box_dict = {'width': ship_dict['width'], 'height': ship_dict['height'],
         'mass': ship_dict['mass']}
        col_shape_dict = {'shape_type': 'box', 'elasticity': .5, 
        'collision_type': 2, 'shape_info': box_dict, 'friction': 1.0}
        physics_component_dict = { 'main_shape': 'box', 
        'velocity': (0, 0), 'position': position, 'angle': 0, 
        'angular_velocity': 0, 'mass': ship_dict['mass'], 'vel_limit': ship_dict['max_speed'], 
        'ang_vel_limit': math.radians(ship_dict['max_turn_speed']), 'col_shapes': [col_shape_dict]}
        ship_system_dict = {'health': ship_dict['health'], 
        'max_speed': ship_dict['max_speed'], 'accel': ship_dict['accel'], 
        'offset_distance': ship_dict['offset_distance'], 'color': ship_dict['color'],
        'ang_accel': math.radians(ship_dict['angular_accel']), 'hard_points': ship_dict['hard_points'], 
        'projectile_type': ship_dict['caliber'], 'is_turning': 'zero', 'fire_engines': False, 
        'turn_speed_multiplier': 0, 'engine_speed_multiplier': 0, 'character_dying': False,
        'current_projectile_type': '_bullet', 'current_probes': 0, 
        'total_rocket_ammo': ship_dict['total_rocket_ammo'], 
        'current_rocket_ammo': ship_dict['total_rocket_ammo'],
        'total_bullet_ammo': ship_dict['total_bullet_ammo'],
        'current_bullet_ammo': ship_dict['total_bullet_ammo']}
        particle_system1 = {'particle_file': ship_dict['engine_effect'], 
        'offset': ship_dict['engine_offset']}
        particle_system2 = {'particle_file': ship_dict['explosion_effect'], 'offset': 0}
        particle_systems = {'engine_effect': particle_system1, 'explosion_effect': particle_system2}
        create_component_dict = {'cymunk-physics': physics_component_dict, 
        'physics_renderer': {'texture': ship_dict['texture']}, 
        'ship_system': ship_system_dict,
        'particle_manager': particle_systems}
        component_order = ['cymunk-physics', 'physics_renderer', 'ship_system',
         'particle_manager']
        if is_player_character:
            player_character_system = self.gameworld.systems['player_character']
            create_component_dict['player_character'] = {}
            component_order.append('player_character')
            player_character_system.current_bullet_ammo = ship_system_dict['current_bullet_ammo']
            player_character_system.current_rocket_ammo = ship_system_dict['current_rocket_ammo']
        else:
            create_component_dict['ship_ai_system'] = {}
            component_order.append('ship_ai_system')
            Clock.schedule_once(partial(self.gameworld.systems['sound_system'].schedule_play, 'enemyshipenterarea'))
        self.gameworld.init_entity(create_component_dict, component_order)

class PlayerCharacter(GameSystem):
    current_character_id = NumericProperty(None, allownone=True)
    touch_values = ListProperty([])
    current_health = NumericProperty(1., allownone=True)
    current_projectile_type = StringProperty('_bullet')
    weapons_locked = BooleanProperty(False)
    total_health = NumericProperty(1., allownone=True)
    current_bullet_ammo = NumericProperty(0)
    current_rocket_ammo = NumericProperty(0)

    def __init__(self, **kwargs):
        super(PlayerCharacter, self).__init__(**kwargs) 

    def on_weapons_locked(self, instance, value):
        if value == True:
            gameworld = self.gameworld
            character = gameworld.entities[self.current_character_id]
            projectile_system = gameworld.systems['projectile_system']
            system_data = character[self.system_id]
            ship_system_data = character['ship_system']
            current_projectile_dict = projectile_system.projectiles_dict[
                ship_system_data['projectile_type']+self.current_projectile_type]
            cooldown = current_projectile_dict['cooldown']
            Clock.schedule_once(self.reset_weapon_lock, cooldown)

    def reset_weapon_lock(self, dt):
        self.weapons_locked = False

    def on_touch_values(self, instance, value):
        if not self.current_character_id == None:
            entity = self.gameworld.entities[self.current_character_id]
            ship_system_data = entity['ship_system']
            physics_body = entity['cymunk-physics']['body']
            if not value == []:

                if value[0] <= .33:
                    ship_system_data['is_turning'] = 'left'
                    ship_system_data['turn_speed_multiplier'] = 1 - value[0]/.33
                if value[0] >= .66:
                    ship_system_data['is_turning'] = 'right'
                    ship_system_data['turn_speed_multiplier'] = (value[0]-.66)/.33
                if .33 < value[0] < .66:
                    ship_system_data['is_turning'] = 'zero'
                    physics_body.angular_velocity = 0
                if value[1] >= .34:
                    ship_system_data['fire_engines'] = True
                    ship_system_data['engine_speed_multiplier'] = (value[1] - .33 )/ .66 
                    entity['particle_manager']['engine_effect']['particle_system_on'] = True
                if value[1] < .34: 
                    ship_system_data['fire_engines'] = False
                    entity['particle_manager']['engine_effect']['particle_system_on'] = False
            else:
                ship_system_data['is_turning'] = 'zero'
                ship_system_data['fire_engines'] = False

                physics_body.angular_velocity = 0
                entity['particle_manager']['engine_effect']['particle_system_on'] = False

    def create_component(self, entity_id, entity_component_dict):
        super(PlayerCharacter, self).create_component(entity_id, entity_component_dict)
        self.current_character_id = entity_id
        ship_dict = self.gameworld.entities[entity_id]['ship_system']
        self.gameworld.systems[self.viewport].entity_to_focus = entity_id
        self.total_health = ship_dict['health']
        self.current_health = ship_dict['health']


    def remove_entity(self, entity_id):
        self.current_character_id = None
        super(PlayerCharacter, self).remove_entity(entity_id)

    def fire_projectiles(self, dt):
        if not self.current_character_id == None:
            if not self.weapons_locked:
                ship_system = self.gameworld.systems['ship_system']
                ship_system.fire_projectiles(self.current_character_id)
                self.weapons_locked = True
                
    def spawn_projectile(self, state):
        if state == 'down':
            Clock.schedule_once(self.fire_projectiles)
        
    def on_current_projectile_type(self, instance, value):
        self.weapons_locked = True
        character = self.gameworld.entities[self.current_character_id]
        character['ship_system']['current_projectile_type'] = value


class ProbeSystem(GameSystem):
    updateable = BooleanProperty(True)
    number_of_probes = NumericProperty(0)

    def __init__(self, **kwargs):
        super(ProbeSystem, self).__init__(**kwargs)
        self.probe_dict = {}
        self.setup_probe_dict()

    def clear_probes(self):
        for entity_id in self.entity_ids:
            Clock.schedule_once(partial(self.gameworld.timed_remove_entity, entity_id))

    def update(self, dt):
        gameworld = self.gameworld
        entities = gameworld.entities
        for entity_id in self.entity_ids:
            entity = entities[entity_id]
            system_data = entity['probe_system']
            physics_data = entity['cymunk-physics']
            unit_vector = physics_data['unit_vector']
            system_data['position'] = (physics_data['position'][0] - unit_vector[0]*system_data['offset'],
                physics_data['position'][1] - unit_vector[1]*system_data['offset'])

            color = system_data['color']
            if color[3] >= 1.0:
                system_data['color_change'] = 'descending'
            if color[3] <= 0.:
                system_data['color_change'] = 'ascending'
            color_change = system_data['color_change']
            if color_change == 'ascending':
                new_alpha = color[3] + system_data['color_change_speed']*dt
                system_data['color'] = (color[0], color[1], color[2], new_alpha)
            if color_change == 'descending':
                new_alpha = color[3] - system_data['color_change_speed']*dt
                system_data['color'] = (color[0], color[1], color[2], new_alpha)

    def setup_probe_dict(self):
        self.probe_dict['probe1'] = {'inner_radius': 0, 'outer_radius': 16, 'mass': 100,
        'max_speed': 280, 'max_turn_speed': 180, 'texture': 'assets/ships/probe.png', 'offset': 5,
        'color': (0.788235294, 0.643137255, 1., 1.), 'color_change_speed': 1., 
        'lighting_texture': 'assets/ships/probelight.png'}

    def spawn_probe_with_dict(self, probe_dict, position):
        circle_dict = {'inner_radius': probe_dict['inner_radius'], 
        'outer_radius': probe_dict['outer_radius'], 'mass': probe_dict['mass'], 
        'offset': (0, 0)}
        col_shape_dict = {'shape_type': 'circle', 'elasticity': .5, 
        'collision_type': 4, 'shape_info': circle_dict, 'friction': 1.0}
        physics_component_dict = { 'main_shape': 'box', 
        'velocity': (0, 0), 'position': position, 'angle': 0, 
        'angular_velocity': 0, 'mass': probe_dict['mass'], 'vel_limit': probe_dict['max_speed'], 
        'ang_vel_limit': math.radians(probe_dict['max_turn_speed']), 'col_shapes': [col_shape_dict]}
        probe_system_dict = {'color': probe_dict['color'], 'offset': probe_dict['offset'], 
        'color_change_speed': probe_dict['color_change_speed'], 'color_change': 'ascending',
        'position': position}
        create_component_dict = {'cymunk-physics': physics_component_dict, 
        'physics_renderer': {'texture': probe_dict['texture']}, 
        'lighting_renderer': {'texture': probe_dict['lighting_texture'], 
        'size': (probe_dict['outer_radius']*2, probe_dict['outer_radius']*2)}, 
        'probe_system': probe_system_dict}
        component_order = ['cymunk-physics', 'physics_renderer', 'probe_system', 'lighting_renderer']
        self.gameworld.init_entity(create_component_dict, component_order)
        self.number_of_probes += 1

    def remove_entity(self, entity_id):
        super(ProbeSystem, self).remove_entity(entity_id)
        self.number_of_probes -= 1
    