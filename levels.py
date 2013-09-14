from kivy.properties import (StringProperty, NumericProperty, BooleanProperty)
import random
import math
from kivent_cython import (GameSystem)
from kivy.atlas import Atlas
from kivy.clock import Clock
from functools import partial

class AsteroidsLevel(GameSystem):
    system_id = StringProperty('asteroids_level')
    current_level_id = NumericProperty(0)
    do_asteroids = BooleanProperty(False)
    do_probes = BooleanProperty(False)
    do_enemies = BooleanProperty(False)
    number_of_enemies_to_spawn = NumericProperty(0)

    def on_current_level_id(self, instance, value):
        if value >= 5:
            self.current_level_id = 0

    def generate_new_level(self, dt):
        level_win_conditions = [(True, False, False), (False, True, False), 
        (False, False, True), (False, True, True), (False, False, True)]
        level_number_of_enemies = [0, 0, 1, 2, 3]
        self.number_of_enemies_to_spawn = level_number_of_enemies[
            self.current_level_id]
        current_level_win_conditions = level_win_conditions[
            self.current_level_id]
        self.do_asteroids = current_level_win_conditions[0]
        self.do_probes = current_level_win_conditions[1]
        self.do_enemies = current_level_win_conditions[2]
        dust_choices_gold = [
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust1.atlas', 
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust4.atlas',
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust7.atlas',
            ] 
        dust_choices_green = [
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust2.atlas', 
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust5.atlas',
            ]
        dust_choices_purple = [
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust3.atlas',
            ]
        dust_choices_blue = [
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust6.atlas', 
        'assets/prerendered_backgrounds/stardust_backgrounds/stardust8.atlas',
            ]
        star_choice_gold = ['assets/background_objects/star3.png', 
            'assets/background_objects/star7.png']
        star_choice_green = ['assets/background_objects/star5.png', 
            'assets/background_objects/star8.png']
        star_choice_blue = ['assets/background_objects/star1.png', 
            'assets/background_objects/star2.png']
        star_choice_purple = ['assets/background_objects/star4.png', 
            'assets/background_objects/star6.png']
        color_choice = [star_choice_gold, star_choice_green, 
            star_choice_purple, star_choice_blue]
        first_color_choice = random.choice(color_choice)
        second_color_choice = random.choice(color_choice)
        num_star_1 = random.randint(0, 25)
        num_star_2 = random.randint(0, 15)
        num_star_3 = random.randint(0, 10)
        num_star_4 = random.randint(0, 10)
        self.generate_stars(first_color_choice[0], first_color_choice[1], 
            second_color_choice[0], second_color_choice[1], 
            num_star_1, num_star_2, num_star_3, num_star_4)
        #generate background
        chance_of_dust = random.random()
        chance_of_dust = 1.0
        if chance_of_dust >= .4:
            if first_color_choice == star_choice_gold:
                bg_choice = random.choice(dust_choices_gold)
            if first_color_choice == star_choice_green:
                bg_choice = random.choice(dust_choices_green)
            if first_color_choice == star_choice_blue:
                bg_choice = random.choice(dust_choices_blue)
            if first_color_choice == star_choice_purple:
                bg_choice = random.choice(dust_choices_purple)
            bg_choice = 'assets/prerendered_backgrounds/stardust_backgrounds/stardust4.atlas'
            self.generate_prerendered_background(bg_choice, (512, 512))
        self.choose_damping()
        self.choose_gravity()
        self.spawn_probes()
        

    def begin_spawning_of_ai(self):
        if self.number_of_enemies_to_spawn > 0:
            time_to_ship_spawn = random.random()*10.0
            Clock.schedule_once(self.spawn_ai_ship, time_to_ship_spawn)


    def spawn_ai_ship(self, dt):
        self.number_of_enemies_to_spawn -= 1
        character_system = self.gameworld.systems['ship_system']
        ship_choice = random.choice(['ship_1', 'ship_2', 'ship_3', 
            'ship_4', 'ship_5', 'ship_6'])
        rand_x = random.randint(0, self.gameworld.currentmap.map_size[0])
        rand_y = random.randint(0, self.gameworld.currentmap.map_size[1])
        character_system.spawn_ship_with_dict(
            character_system.ship_dicts[ship_choice], False, (rand_x, rand_y))
        if self.number_of_enemies_to_spawn > 0:
            time_to_ship_spawn = random.random()*10.0
            Clock.schedule_once(self.spawn_ai_ship, time_to_ship_spawn)

    def spawn_probes(self):
        systems = self.gameworld.systems
        probe_system = systems['probe_system']
        number_of_probes_to_spawn = [0, 5, 0, 10, 0]
        for x in range(number_of_probes_to_spawn[self.current_level_id]):
            rand_x = random.randint(0, self.gameworld.currentmap.map_size[0])
            rand_y = random.randint(0, self.gameworld.currentmap.map_size[1])
            probe_system.spawn_probe_with_dict(
                probe_system.probe_dict['probe1'], (rand_x, rand_y))

    def choose_gravity(self):
        #'x', 'y', 'xy', '
        choice = random.choice(['none', 'none', 'none', 'none'])
        systems = self.gameworld.systems
        physics_system = systems['cymunk-physics']
        if choice == 'none':
            physics_system.gravity = (0, 0)
        if choice == 'x':
            x_grav = random.randrange(-100, 100)
            physics_system.gravity = (x_grav, 0)
        if choice == 'y':
            y_grav = random.randrange(-100, 100)
            physics_system.gravity = (0, y_grav)
        if choice == 'xy':
            y_grav = random.randrange(-100, 100)
            x_grav = random.randrange(-100, 100)
            physics_system.gravity = (x_grav, y_grav)

    def choose_damping(self):
        systems = self.gameworld.systems
        level_damping = [.75, .75, .80, .9, 1.0]
        physics_system = systems['cymunk-physics']
        #damping_factor = .75 + .25*random.random()
        physics_system.damping = level_damping[self.current_level_id]

    def clear_level(self):
        for entity_id in self.entity_ids:
            Clock.schedule_once(partial(
                self.gameworld.timed_remove_entity, entity_id))

    def generate_stars(self, first_star_choice1, first_star_choice2, 
        second_star_choice1, second_star_choice2, num_star_1, 
        num_star_2, num_star_3, num_star_4):
        for x in range(num_star_1):
            self.generate_star(first_star_choice1, (14, 14))
        for x in range(num_star_2):
            self.generate_star(first_star_choice2, (8, 8))
        for x in range(num_star_3):
            self.generate_star(second_star_choice1, (14, 14))
        for x in range(num_star_4):
            self.generate_star(second_star_choice2, (8, 8))

    def generate_star(self, star_graphic, star_size):
        rand_x = random.randint(0, self.gameworld.currentmap.map_size[0])
        rand_y = random.randint(0, self.gameworld.currentmap.map_size[1])
        create_component_dict = {'position': {'position': (rand_x, rand_y)}, 
        'quadtree_renderer': {'texture': star_graphic, 'size': star_size}, 
        'asteroids_level': {'level_id': self.current_level_id}}
        component_order = ['position', 'quadtree_renderer', 'asteroids_level']
        self.gameworld.init_entity(create_component_dict, component_order)

    
    def generate_prerendered_background(self, atlas_address, atlas_size):
        stardust_atlas = Atlas(atlas_address)
        num_tiles = len(stardust_atlas.textures)
        map_to_use = self.gameworld.systems['default_map']
        map_size = map_to_use.map_size
        side_length_x = math.sqrt(num_tiles)
        side_length_y = side_length_x
        scale_x = map_size[0]/atlas_size[0]
        scale_y = map_size[1]/atlas_size[1]
        x_distance = map_size[0]/side_length_x
        y_distance = map_size[1]/side_length_y
        position_dict = {}
        index = 0
        size = (x_distance, y_distance)
        for y in range(int(side_length_y)):
            for x in range(int(side_length_x)):
                position_dict[index] = (x * x_distance + x_distance *.5, 
                    y * y_distance + y_distance*.5)
                index += 1
        for num in range(num_tiles):
            create_component_dict = {'position': {
            'position': position_dict[num], 
            'scale_x': scale_x, 'scale_y': scale_y}, 
            'background_renderer': {'texture': atlas_address, 
            'texture_key': str(num+1), 'size': size}, 
            'asteroids_level': {'level_id': self.current_level_id}}
            component_order = ['position', 'background_renderer', 
                'asteroids_level']
            self.gameworld.init_entity(create_component_dict, component_order)

class AsteroidSystem(GameSystem):
    system_id = StringProperty('asteroid_system')
    updateable = BooleanProperty(True)
    number_of_asteroids = NumericProperty(0)

    def generate_asteroids(self, dt):
        current_level_id = self.gameworld.systems[
            'asteroids_level'].current_level_id
        level_asteroids = [(0, 5), (5, 15), (5, 20), (10, 0), (5,20)]
        if current_level_id <= 4:
            num_small_asteroids = level_asteroids[current_level_id][1]
            num_big_asteroids = level_asteroids[current_level_id][0]
        if current_level_id > 4:
            num_big_asteroids = (current_level_id - 1) * 5
            num_small_asteroids = (current_level_id + 1) * 5
        #small asteroids
        for x in range(num_small_asteroids):
            rand_x = random.randint(0, self.gameworld.currentmap.map_size[0])
            rand_y = random.randint(0, self.gameworld.currentmap.map_size[1])
            self.create_asteroid_1((rand_x, rand_y))
        #big asteroids
        for x in range(num_big_asteroids):
            rand_x = random.randint(0, self.gameworld.currentmap.map_size[0])
            rand_y = random.randint(0, self.gameworld.currentmap.map_size[1])
            self.create_asteroid_2((rand_x, rand_y))


    def clear_asteroids(self):
        for entity_id in self.entity_ids:
            Clock.schedule_once(partial(
                self.gameworld.timed_remove_entity, entity_id))

    def create_asteroid_2(self, pos):
        x_vel = random.randint(-75, 75)
        y_vel = random.randint(-75, 75)
        angle = math.radians(random.randint(-360, 360))
        angular_velocity = math.radians(random.randint(-150, -150))
        shape_dict = {'inner_radius': 0, 'outer_radius': 43, 'mass': 150, 
        'offset': (0, 0)}
        col_shape = {'shape_type': 'circle', 'elasticity': .5, 
        'collision_type': 1, 'shape_info': shape_dict, 'friction': 1.0}
        col_shapes = [col_shape]
        physics_component = {'main_shape': 'circle', 
        'velocity': (x_vel, y_vel), 
        'position': (pos[0], pos[1]), 'angle': angle, 
        'angular_velocity': angular_velocity,
        'vel_limit': 200, 
        'ang_vel_limit': math.radians(150), 
        'mass': 100, 'col_shapes': col_shapes}
        asteroid_component = {'health': 30, 'damage': 15, 
        'asteroid_size': 2, 'pending_destruction': False}
        create_component_dict = {'cymunk-physics': physics_component, 
        'physics_renderer': {'texture': 
            'assets/background_objects/asteroid2.png'}, 
        'asteroid_system': asteroid_component}
        component_order = ['cymunk-physics', 'physics_renderer', 
            'asteroid_system']
        self.gameworld.init_entity(create_component_dict, component_order)

    def create_asteroid_1(self, pos):
        x = pos[0]
        y = pos[1]
        x_vel = random.randint(-100, 100)
        y_vel = random.randint(-100, 100)
        angle = math.radians(random.randint(-360, 360))
        angular_velocity = math.radians(random.randint(-150, -150))
        shape_dict = {'inner_radius': 0, 'outer_radius': 32, 
        'mass': 50, 'offset': (0, 0)}
        col_shape = {'shape_type': 'circle', 'elasticity': .5, 
        'collision_type': 1, 'shape_info': shape_dict, 'friction': 1.0}
        col_shapes = [col_shape]
        physics_component = {'main_shape': 'circle', 
        'velocity': (x_vel, y_vel), 
        'position': (x, y), 'angle': angle, 
        'angular_velocity': angular_velocity, 
        'vel_limit': 250, 
        'ang_vel_limit': math.radians(200), 
        'mass': 50, 'col_shapes': col_shapes}
        asteroid_component = {'health': 15, 'damage': 5, 
        'asteroid_size': 1, 'pending_destruction': False}
        create_component_dict = {'cymunk-physics': physics_component, 
        'physics_renderer': {'texture': 
            'assets/background_objects/asteroid1.png'}, 
        'asteroid_system': asteroid_component}
        component_order = ['cymunk-physics', 'physics_renderer', 
            'asteroid_system']
        self.gameworld.init_entity(create_component_dict, component_order)

    def create_component(self, entity_id, entity_component_dict):
        super(AsteroidSystem, self).create_component(entity_id, 
            entity_component_dict)
        self.number_of_asteroids += 1

    def remove_entity(self, entity_id):
        super(AsteroidSystem, self).remove_entity(entity_id)
        self.number_of_asteroids -= 1

    def update(self, dt):
        system_id = self.system_id
        entities = self.gameworld.entities
        for entity_id in self.entity_ids:
            entity = entities[entity_id]
            if system_id not in entity:
                continue
            system_data = entity[system_id]
            if (system_data['health'] <= 0 and 
                not system_data['pending_destruction']):
                system_data['pending_destruction'] = True
                if system_data['asteroid_size'] == 2:
                    for x in range(4):
                        position = entity['cymunk-physics']['position']
                        self.create_asteroid_1(position)
                Clock.schedule_once(partial(
                    self.gameworld.timed_remove_entity, entity_id))
                
    def damage(self, entity_id, damage):
        system_id = self.system_id
        entities = self.gameworld.entities
        entity = entities[entity_id]
        system_data = entity[system_id]
        system_data['health'] -= damage

    def collision_begin_asteroid_asteroid(self, space, arbiter):
        gameworld = self.gameworld
        entities = gameworld.entities
        asteroid1_id = arbiter.shapes[0].body.data
        asteroid2_id = arbiter.shapes[1].body.data
        asteroid1 = entities[asteroid1_id]
        asteroid2 = entities[asteroid2_id]
        if (asteroid1['physics_renderer']['on_screen'] or 
            asteroid2['physics_renderer']['on_screen']):
            sound_system = gameworld.systems['sound_system']
            sound_system.play('asteroidhitasteroid')
        return True