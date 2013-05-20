import kivy
kivy.require('1.6.0')
from kivy.app import App
from kivy.uix.widget import Widget
from kivy.properties import (StringProperty, ObjectProperty, ListProperty, 
NumericProperty, BooleanProperty)
from kivy.clock import Clock
from kivy.graphics import Line, Translate, PushMatrix, PopMatrix    
from kivent_cython import (GameWorld, GameScreenManager, GameScreen,
GameSystem, GameMap, GameView, ParticleManager, QuadRenderer, PhysicsRenderer, 
CymunkPhysics, PhysicsPointRenderer, QuadTreePointRenderer)
from kivy.atlas import Atlas
from kivy.vector import Vector
from kivy.graphics import Color, Line
import random
from kivyparticle import ParticleSystem
import math
from functools import partial
COLOR_HIGHLIGHT = (0.788235294, 0.643137255, 1)
COLOR_BACKGROUND = (0.349019608, 0.082352941, 0.658823529)
COLOR_BORDER = (0.643137255, 0.160784314, 1)

class CharacterInputPanel(Widget):
    current_touch = ListProperty([])
    touch_effect = StringProperty('assets/pexfiles/touch_input_effect.pex')
    particle_system = ObjectProperty(None)
    def __init__(self, **kwargs):
        super(CharacterInputPanel, self).__init__(**kwargs)
        self.create_touch_event_effect()

    def create_touch_event_effect(self):
        self.particle_system = ParticleSystem(self.touch_effect)

    def determine_touch_values(self, touch_x, touch_y):
        x_value = (touch_x - self.pos[0])/self.size[0]
        y_value = (touch_y - self.pos[1])/self.size[1]
        return (x_value, y_value)


    def on_current_touch(self, instance, value):
        player_character = self.gameworld.systems['player_character']
        if not value == []: 
            touch_values = self.determine_touch_values(value[0], value[1])
            particle_system = self.particle_system
            particle_system.pos = value
            particle_system.start_color = [touch_values[1], .3, .0, 1.]
            particle_system.end_color = [touch_values[1], .0, .5, 1.]
            player_character.touch_values = touch_values
        else:
            player_character.touch_values = value

            
    def on_touch_down(self, touch):
        if self.collide_point(touch.x, touch.y):
            self.current_touch = (touch.x, touch.y)
            particle_system = self.particle_system
            particle_system.start()
            if particle_system not in self.children:
                self.add_widget(particle_system)
    
    def on_touch_move(self, touch):
        if self.collide_point(touch.x, touch.y):
            self.current_touch = (touch.x, touch.y)
            

    def on_touch_up(self, touch):
        if self.collide_point(touch.x, touch.y):
            self.current_touch = []
            particle_system = self.particle_system
            particle_system.stop()
            if particle_system in self.children:
                self.remove_widget(particle_system)



class AsteroidSystem(GameSystem):
    system_id = StringProperty('asteroid_system')
    updateable = BooleanProperty(True)
    number_of_asteroids = NumericProperty(0)

    def create_asteroid_2(self, dt):
        rand_x = random.randint(0, self.gameworld.currentmap.map_size[0])
        rand_y = random.randint(0, self.gameworld.currentmap.map_size[1])
        x_vel = random.randint(-75, 75)
        y_vel = random.randint(-75, 75)
        angle = math.radians(random.randint(-360, 360))
        angular_velocity = math.radians(random.randint(-150, -150))
        shape_dict = {'inner_radius': 0, 'outer_radius': 43, 'mass': 150, 'offset': (0, 0)}
        col_shape = {'shape_type': 'circle', 'elasticity': .5, 
        'collision_type': 1, 'shape_info': shape_dict, 'friction': 1.0}
        col_shapes = [col_shape]
        physics_component = {'main_shape': 'circle', 'velocity': (x_vel, y_vel), 
        'position': (rand_x, rand_y), 'angle': angle, 'angular_velocity': angular_velocity, 
        'mass': 100, 'col_shapes': col_shapes}
        asteroid_component = {'health': 30, 'damage': 15, 'asteroid_size': 2, 'pending_destruction': False}
        create_component_dict = {'cymunk-physics': physics_component, 
        'physics_renderer': {'texture': 'assets/background_objects/asteroid2.png', 
        'render': False, 'size': (45, 45)}, 'asteroid_system': asteroid_component}
        component_order = ['cymunk-physics', 'physics_renderer', 'asteroid_system']
        self.gameworld.init_entity(create_component_dict, component_order)

    def create_asteroid_1(self, pos, dt):
        print 'creating small asteroid'
        x = pos[0]
        y = pos[1]
        x_vel = random.randint(-100, 100)
        y_vel = random.randint(-100, 100)
        angle = math.radians(random.randint(-360, 360))
        angular_velocity = math.radians(random.randint(-150, -150))
        shape_dict = {'inner_radius': 0, 'outer_radius': 32, 'mass': 50, 'offset': (0, 0)}
        col_shape = {'shape_type': 'circle', 'elasticity': .5, 
        'collision_type': 1, 'shape_info': shape_dict, 'friction': 1.0}
        col_shapes = [col_shape]
        physics_component = {'main_shape': 'circle', 'velocity': (x_vel, y_vel), 
        'position': (x, y), 'angle': angle, 'angular_velocity': angular_velocity, 
        'mass': 50, 'col_shapes': col_shapes}
        asteroid_component = {'health': 15, 'damage': 5, 'asteroid_size': 1, 'pending_destruction': False}
        create_component_dict = {'cymunk-physics': physics_component, 
        'physics_renderer': {'texture': 'assets/background_objects/asteroid1.png', 
        'render': False, 'size': (45, 45)}, 'asteroid_system': asteroid_component}
        component_order = ['cymunk-physics', 'physics_renderer', 'asteroid_system']
        self.gameworld.init_entity(create_component_dict, component_order)

    def create_component(self, entity_id, entity_component_dict):
        super(AsteroidSystem, self).create_component(entity_id, entity_component_dict)
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
            if system_data['health'] <= 0 and not system_data['pending_destruction']:
                system_data['pending_destruction'] = True
                if system_data['asteroid_size'] == 2:
                    print 'asteroid of size 2 destroyed'
                    for x in range(4):
                        Clock.schedule_once(partial(self.create_asteroid_1, entity['cymunk-physics']['position']))
                Clock.schedule_once(partial(self.gameworld.timed_remove_entity, entity_id))
                

    def damage(self, entity_id, damage):
        system_id = self.system_id
        entities = self.gameworld.entities
        entity = entities[entity_id]
        system_data = entity[system_id]
        system_data['health'] -= damage

class PlayerCharacter(GameSystem):
    current_character_id = NumericProperty(None, allownone=True)
    do_fire_engines = BooleanProperty(False)
    updateable = BooleanProperty(True)
    turning = StringProperty('zero')
    touch_values = ListProperty([])
    turn_speed_multiplier = NumericProperty(1.)
    engine_speed_multiplier = NumericProperty(1.)
    character_dying = BooleanProperty(False)

    def on_touch_values(self, instance, value):
        if not self.current_character_id == None:
            entity = self.gameworld.entities[self.current_character_id]
            if not value == []:

                if value[0] <= .33:
                    self.turning = 'left'
                    self.turn_speed_multiplier = 1 - value[0]/.33
                if value[0] >= .66:
                    self.turning = 'right'
                    self.turn_speed_multiplier = (value[0]-.66)/.33
                if .33 < value[0] < .66:
                    self.turning = 'zero'
                if value[1] >= .34:
                    self.do_fire_engines = True
                    self.engine_speed_multiplier = (value[1] - .33 )/ .66 
                    entity['particle_manager']['engine_effect']['particle_system_on'] = True
                if value[1] < .34: 
                    self.do_fire_engines = False
                    entity['particle_manager']['engine_effect']['particle_system_on'] = False
            else:
                self.turning = 'zero'
                self.do_fire_engines = False
                entity['particle_manager']['engine_effect']['particle_system_on'] = False

    def create_component(self, entity_id, entity_component_dict):
        super(PlayerCharacter, self).create_component(entity_id, entity_component_dict)
        self.current_character_id = entity_id
        self.gameworld.systems[self.viewport].entity_to_focus = entity_id


    def remove_entity(self, entity_id):
        self.current_character_id = None
        self.character_dying = False
        super(PlayerCharacter, self).remove_entity(entity_id)

    def fire_projectiles(self, dt):
        if not self.current_character_id == None:
            character = self.gameworld.entities[self.current_character_id]
            system_data = character[self.system_id]
            for projectile in system_data['projectiles']:
                projectile_dict = {}
                for data in projectile:
                    projectile_dict[data] = projectile[data].copy()
                physics_info = projectile_dict['cymunk-physics']
                position_offset = projectile_dict['projectile_system']['offset']
                character_physics = character['cymunk-physics']
                character_position = character_physics['position']
                position_offset_rotated = Vector(position_offset).rotate(character_physics['angle'])
                physics_info['position'] = (character_position[0] + position_offset_rotated[0],
                    character_position[1] + position_offset_rotated[1])
                physics_info['angle'] = character_physics['body'].angle
                component_order = ['cymunk-physics', 'physics_point_renderer', 'projectile_system']
                new_ent = self.gameworld.init_entity(projectile_dict, component_order)
                self.fire_projectile(new_ent)

    def spawn_projectile(self, state):
        if state == 'down':
            Clock.schedule_once(self.fire_projectiles)
            Clock.schedule_interval(self.fire_projectiles, .5)
        if state == 'normal':
            Clock.unschedule(self.fire_projectiles)
        
    def fire_projectile(self, entity_id):
        entities = self.gameworld.entities
        if not self.current_character_id == None:
            character = entities[self.current_character_id]
            system_data = character[self.system_id]
            bullet = entities[entity_id]
            physics_data = character['cymunk-physics']
            unit_vector = physics_data['unit_vector']
            bullet_accel = bullet['projectile_system']['accel']
            force = {'x': bullet_accel*-unit_vector['x'], 'y': bullet_accel*-unit_vector['y']}
            force_offset = {'x': -unit_vector['x'], 'y': -unit_vector['y']}
            bullet['cymunk-physics']['body'].apply_impulse(force, force_offset)

    def update(self, dt):
        if not self.current_character_id == None:
            character = self.gameworld.entities[self.current_character_id]
            physics_data = character['cymunk-physics']
            physics_body = physics_data['body']
            system_data = character[self.system_id]
            if self.do_fire_engines:   
                unit_vector = physics_data['unit_vector']
                offset = {'x': system_data['offset_distance'] * -unit_vector['x'], 
                'y': system_data['offset_distance'] * -unit_vector['y']}
                force = {'x': self.engine_speed_multiplier * system_data['accel']*dt * -unit_vector['x'], 
                'y': self.engine_speed_multiplier * system_data['accel']*dt * -unit_vector['y']}
                physics_body.apply_impulse(force, offset)
            if physics_body.is_sleeping:
                physics_body.activate()
            if self.turning == 'left':
                physics_body.angular_velocity += self.turn_speed_multiplier*system_data['ang_vel_accel']*dt
            elif self.turning == 'right':
                physics_body.angular_velocity -= self.turn_speed_multiplier*system_data['ang_vel_accel']*dt
            if system_data['health'] <= 0 and not self.character_dying:
                self.do_death()
                self.character_dying = True

    def update_death_animation(self, dt):
        print 'updating death animation'
        entity = self.gameworld.entities[self.current_character_id]
        self.gameworld.systems['physics_renderer'].canvas.remove(entity['physics_renderer']['quad'])
        entity['particle_manager']['explosion_effect']['particle_system'].emitter_type = 0

    def do_death(self):
        entity = self.gameworld.entities[self.current_character_id]
        entity['particle_manager']['engine_effect']['particle_system_on'] = False
        entity['particle_manager']['explosion_effect']['particle_system_on'] = True
        Clock.schedule_once(self.update_death_animation, 1.0)
        Clock.schedule_once(partial(self.gameworld.timed_remove_entity, self.current_character_id), 2.0)

    def on_turning(self, instance, value):
        if value == 'zero':
            if not self.current_character_id == None:
                character = self.gameworld.entities[self.current_character_id]
                physics_body = character['cymunk-physics']['body']
                physics_body.angular_velocity = 0

    def damage(self, entity_id, damage):
        system_id = self.system_id
        entities = self.gameworld.entities
        entity = entities[entity_id]
        system_data = entity[system_id]
        system_data['health'] -= damage

    def begin_collision_solve_asteroid_bullet(self, arbiter, space):
        gameworld = self.gameworld
        systems = gameworld.systems
        entities = gameworld.entities
        bullet_id = arbiter.shapes[1].body.data
        asteroid_id = arbiter.shapes[0].body.data
        bullet = entities[bullet_id]
        bullet_damage = bullet['projectile_system']['damage']
        systems['asteroid_system'].damage(asteroid_id, bullet_damage)
        Clock.schedule_once(partial(gameworld.timed_remove_entity, bullet_id))
        return True

    def collision_solve_ship_bullet(self, arbiter, space):
        gameworld = self.gameworld
        systems = gameworld.systems
        entities = gameworld.entities
        bullet_id = arbiter.shapes[1].body.data
        ship_id = arbiter.shapes[0].body.data
        bullet = entities[bullet_id]
        bullet_damage = bullet['projectile_system']['damage']
        self.damage(ship_id, bullet_damage)
        Clock.schedule_once(partial(gameworld.timed_remove_entity, bullet_id))
        return True

    def collision_solve_ship_asteroid(self, arbiter, space):
        gameworld = self.gameworld
        systems = gameworld.systems
        entities = gameworld.entities
        asteroid_id = arbiter.shapes[1].body.data
        ship_id = arbiter.shapes[0].body.data
        asteroid = entities[asteroid_id]
        asteroid_damage = asteroid['asteroid_system']['damage']
        print asteroid_damage
        self.damage(ship_id, asteroid_damage)
        return True

class DebugPanel(Widget):
    fps = StringProperty(None)

    def __init__(self, **kwargs):
        super(DebugPanel, self).__init__(**kwargs)
        Clock.schedule_once(self.update_fps)

    def update_fps(self,dt):
        self.fps = str(int(Clock.get_fps()))
        Clock.schedule_once(self.update_fps, .05)

class MainMenuScreen(GameScreen):
    name = StringProperty('main_menu')

class MainGameScreen(GameScreen):
    name = StringProperty('main_game')

class TestGame(Widget):
    gameworld = ObjectProperty(None)
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        Clock.schedule_once(self.init_game)

    def init_game(self, dt):
        try: 
            self._init_game(0)
        except:
            print 'failed: rescheduling init **this is not guaranteed to be ok**'
            Clock.schedule_once(self.init_game)

    def setup_states(self):
        self.gameworld.add_state(state_name='main_menu', systems_added=[], 
            systems_removed=['position_renderer', 'physics_renderer', 
            'background_renderer', 'quadtree_renderer', 'particle_manager', 'physics_point_renderer'], 
            systems_paused=['cymunk-physics', 'default_gameview', 'position_renderer', 
            'physics_renderer', 'background_renderer', 'quadtree_renderer', 'physics_point_renderer',
            'particle_manager', 'asteroid_system', 'player_character'], systems_unpaused=[],
            screenmanager_screen='main_menu')
        self.gameworld.add_state(state_name='main_game', systems_added=['background_renderer',
            'quadtree_renderer', 'position_renderer', 'physics_renderer', 
            'physics_point_renderer', 'cymunk-physics', 'default_map', 'particle_manager'], 
            systems_removed=[], systems_paused=[], 
            systems_unpaused=['cymunk-physics', 'default_gameview', 'position_renderer', 
            'physics_renderer', 'background_renderer', 'quadtree_renderer', 'particle_manager',
            'asteroid_system', 'player_character', 'physics_point_renderer'], screenmanager_screen='main_game')

    def set_main_menu_state(self):
        self.gameworld.state = 'main_menu'

    def setup_map(self):
        self.gameworld.currentmap = self.gameworld.systems['default_map']

    def setup_gameobjects(self):
        Clock.schedule_once(self.test_prerendered_background)
        for x in range(30):
            Clock.schedule_once(self.test_entity)
        for x in range(15):
            Clock.schedule_once(self.gameworld.systems['asteroid_system'].create_asteroid_2)
        Clock.schedule_once(self.test_player_character)

    def _init_game(self, dt):
        self.setup_states()
        self.setup_map()
        self.set_main_menu_state()
        self.setup_collision_callbacks()
        self.setup_gameobjects()
        Clock.schedule_interval(self.update, 1./60.)

    def update(self, dt):
        self.gameworld.update(dt)
        

    def setup_collision_callbacks(self):
        systems = self.gameworld.systems
        physics = systems['cymunk-physics']
        character_system = systems['player_character']
        physics.add_collision_handler(1,3, 
            separate_func=character_system.begin_collision_solve_asteroid_bullet)
        physics.add_collision_handler(2,3, 
            separate_func=character_system.collision_solve_ship_bullet)
        physics.add_collision_handler(2,1, separate_func=character_system.collision_solve_ship_asteroid)
    
    def test_prerendered_background(self, dt):
        atlas_address = 'assets/prerendered_backgrounds/stardust_backgrounds/stardust7.atlas'
        self.generate_prerendered_background(atlas_address, (512, 512))
        
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
                position_dict[index] = (x * x_distance + x_distance *.5, y * y_distance + y_distance*.5)
                index += 1
        for num in range(num_tiles):
            create_component_dict = {'position': {'position': position_dict[num], 
            'scale_x': scale_x, 'scale_y': scale_y}, 
            'background_renderer': {'texture': atlas_address, 'texture_key': str(num+1), 
            'render': False, 'size': size}}
            component_order = ['position', 'background_renderer']
            self.gameworld.init_entity(create_component_dict, component_order)

    def test_entity(self, dt):
        rand_x = random.randint(0, self.gameworld.currentmap.map_size[0])
        rand_y = random.randint(0, self.gameworld.currentmap.map_size[1])
        create_component_dict = {'position': {'position': (rand_x, rand_y)}, 
        'quadtree_renderer': {'texture': 'assets/background_objects/star1.png', 
        'render': False, 'size': (14,14)}}
        component_order = ['position', 'quadtree_renderer']
        self.gameworld.init_entity(create_component_dict, component_order)

    def test_remove_entity(self, dt):
        self.gameworld.remove_entity(0)

    def test_player_character(self, dt):
        box_dict = {'width': 108, 'height': 96, 'mass': 250}
        col_shape_dict = {'shape_type': 'box', 'elasticity': .5, 
        'collision_type': 2, 'shape_info': box_dict, 'friction': 1.0}
        physics_component_dict = { 'main_shape': 'box', 
        'velocity': (0, 0), 'position': (500, 500), 'angle': 0, 
        'angular_velocity': 0, 'mass': 250, 'vel_limit': 150, 
        'ang_vel_limit': math.radians(65), 'col_shapes': [col_shape_dict]}
        projectile_box_dict = {'width': 14, 'height': 14, 'mass': 50}
        projectile_col_shape_dict = {'shape_type': 'box', 'elasticity': 1.0, 
        'collision_type': 3, 'shape_info': projectile_box_dict, 'friction': .3}
        projectile_physics_component_dict = { 'main_shape': 'box', 
        'velocity': (0, 0), 'position': (500, 500), 'angle': 0, 
        'angular_velocity': 0, 'mass': 50, 'vel_limit': 250, 
        'ang_vel_limit': math.radians(60),'col_shapes': [projectile_col_shape_dict]}
        projectile_renderer_dict = {'texture': 'assets/projectiles/bullet-14px.png', 
        'render': False, 'size': (14, 14)}
        projectile_dict = {'cymunk-physics': projectile_physics_component_dict, 
        'physics_point_renderer': projectile_renderer_dict, 
        'projectile_system': {'damage': 10, 'offset': (46, 49), 'accel': 50000}}
        projectile_dict_2 = {'cymunk-physics': projectile_physics_component_dict, 
        'physics_point_renderer': projectile_renderer_dict, 
        'projectile_system': {'damage': 10, 'offset': (-46, 49), 'accel': 50000}}
        ship_dict = {'health': 10, 'accel': 15000, 'offset_distance': 50, 
        'ang_vel_accel': math.radians(95), 'projectiles': [projectile_dict, projectile_dict_2]}
        particle_system1 = {'particle_file': 'assets/pexfiles/engine_burn_effect3.pex', 
        'offset': 65}
        particle_system2 = {'particle_file': 'assets/pexfiles/ship_explosion1.pex', 'offset': 0}
        particle_systems = {'engine_effect': particle_system1, 'explosion_effect': particle_system2}
        create_component_dict = {'cymunk-physics': physics_component_dict, 
        'physics_renderer': {'texture': 'assets/ships/ship1-1.png', 
        'render': False, 'size': (64, 52)}, 'player_character': ship_dict,
        'particle_manager': particle_systems}
        component_order = ['cymunk-physics', 'physics_renderer', 'player_character', 
        'particle_manager']
        self.gameworld.init_entity(create_component_dict, component_order)


class KivEntApp(App):
    def build(self):
        pass

if __name__ == '__main__':
    KivEntApp().run()
    #cProfile.run('KivEntApp().run()', 'prof')