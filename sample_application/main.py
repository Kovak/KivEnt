import kivy
from kivy.app import App
from kivy.uix.widget import Widget
from kivy.properties import (StringProperty, ObjectProperty, NumericProperty, 
    BooleanProperty)
from kivy.clock import Clock
from kivent import (GameWorld, GameSystem, GameMap, GameView, 
    ParticleManager, CymunkPhysics, 
    StaticQuadRenderer, DynamicRenderer, ProjectileSystem)
from kivy.core.window import Window
import yacs_ui_elements
import player_character
import levels
import musiccontroller
#import cProfile
import os
import sys
import gc

class TestGame(Widget):
    gameworld = ObjectProperty(None)
    state = StringProperty(None)
    number_of_asteroids = NumericProperty(0, allownone=True)
    number_of_probes = NumericProperty(0, allownone=True)
    number_of_enemies = NumericProperty(0, allownone=True)
    loading_new_level = BooleanProperty(False)
    cleared = BooleanProperty(True)
    current_level = NumericProperty(1)
    current_lives = NumericProperty(3)

    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        Clock.schedule_once(self.init_game)

    def init_game(self, dt):
        try: 
            self._init_game(0)
        except:
            print 'failed: rescheduling init'
            Clock.schedule_once(self.init_game)

    def on_state(self, instance, value):
        if value == 'choose_character':
            self.gameworld.systems['asteroids_level'].clear_level()
            self.clear_gameworld_objects()
            self.cleared = False
            Clock.schedule_once(self.check_clear)
            
    def check_clear(self, dt):
        systems = self.gameworld.systems
        systems_to_check = ['asteroids_level', 'asteroid_system', 
        'projectile_system', 'static_renderer']
        num_entities = 0
        self.check_clear_counter = 0
        for system in systems_to_check:
            num_entities += len(systems[system].entity_ids)
        if num_entities > 0:
            self.check_clear_counter += 1
            if self.check_clear_counter > 10:
                self.clear_gameworld_objects()
            Clock.schedule_once(self.check_clear, .01)
        else:
            self.cleared = True
            self.setup_new_level()
                
    def setup_new_level(self):
        Clock.schedule_once(
            self.gameworld.systems['asteroids_level'].generate_new_level)
        
    def setup_states(self):
        self.gameworld.add_state(state_name='main_menu', systems_added=[
            'static_renderer', 'default_map'], 
            systems_removed=['physics_renderer', 'particles', 
            'lighting_renderer', 'static_renderer', 
            'probe_system', 'background_renderer'], 
            systems_paused=['cymunk_physics', 'default_gameview', 
            'physics_renderer', 'background_renderer', 'static_renderer',
            'particles', 'asteroid_system', 
            'ship_system', 'lighting_renderer', 'probe_system', 
            'ship_ai_system'], systems_unpaused=[],
            screenmanager_screen='main_menu')
        self.gameworld.add_state(state_name='choose_character', systems_added=[
            'static_renderer',  'default_map'], 
            systems_removed=['physics_renderer', 'particles', 
             'lighting_renderer','probe_system', 'background_renderer',
             'static_renderer'], 
            systems_paused=['cymunk_physics', 'default_gameview', 
            'physics_renderer', 'static_renderer', 'background_renderer',
            'particles', 'asteroid_system', 
            'ship_system', 'lighting_renderer', 'probe_system', 
            'ship_ai_system'], systems_unpaused=[],
            screenmanager_screen='choose_character')
        self.gameworld.add_state(state_name='main_game', systems_added=[
            'background_renderer', 'static_renderer', 'physics_renderer', 
            'cymunk_physics', 
            'default_map', 'probe_system', 'lighting_renderer', 
            'particles'], 
            systems_removed=[], systems_paused=[], 
            systems_unpaused=['cymunk_physics', 'default_gameview', 
            'physics_renderer', 'particles', 
            'static_renderer','asteroid_system', 'ship_system', 
            'lighting_renderer', 'background_renderer',
            'projectile_system', 'probe_system', 'ship_ai_system'], 
            screenmanager_screen='main_game')
        self.gameworld.add_state(state_name='game_over', systems_added=[ 
            'background_renderer', 'static_renderer', 'physics_renderer', 
            'cymunk_physics', 
            'default_map', 'probe_system', 'lighting_renderer', 
            'particles'], 
            systems_removed=[], systems_paused=[], 
            systems_unpaused=['cymunk_physics', 'default_gameview', 
            'physics_renderer', 'particles',
            'asteroid_system', 'ship_system', 'background_renderer',
            'lighting_renderer', 'probe_system', 'ship_ai_system'], 
            screenmanager_screen='game_over')

    def clear_gameworld_objects(self):
        systems = self.gameworld.systems
        systems['ship_system'].clear_ships()
        systems['asteroid_system'].clear_asteroids()
        systems['projectile_system'].clear_projectiles()
        systems['probe_system'].clear_probes()
        systems['boundary_system'].clear()

    def set_main_menu_state(self):
        self.gameworld.state = 'main_menu'
        musiccontroller = self.gameworld.music_controller
        if not self.gameworld.music_controller.check_if_songs_are_playing():
            self.gameworld.music_controller.play('track5')
        choose_character = self.gameworld.gamescreenmanager.get_screen(
            'choose_character').choose_character
        choose_character.current_ship = choose_character.list_of_ships[0]

    def setup_map(self):
        self.gameworld.currentmap = self.gameworld.systems['default_map']

    def start_round(self, character_to_spawn):
        if self.cleared:
            gameworld = self.gameworld
            character_system = gameworld.systems['ship_system']
            character_system.spawn_player_character(character_to_spawn)
            Clock.schedule_once(
                gameworld.systems['asteroid_system'].generate_asteroids)
            gameworld.systems['boundary_system'].generate_boundaries()
            gameworld.state = 'main_game'
            gameworld.systems['asteroids_level'].begin_spawning_of_ai()
            game_screen = gameworld.gamescreenmanager.get_screen('main_game')
            game_screen.objective_panel.reset_objectives()

    def null_collide(self, space, arbiter):
        return False

    def setup_gameobjects(self):
        Clock.schedule_once(
            self.gameworld.systems['asteroids_level'].generate_new_level)

    def setup_particle_effects(self):
        particle_effects = [
        'assets/pexfiles/rocket_burn_effect1.pex',
        'assets/pexfiles/rocket_explosion_1.pex',
        'assets/pexfiles/rocket_burn_effect2.pex',
        'assets/pexfiles/rocket_explosion_2.pex',
        'assets/pexfiles/rocket_burn_effect3.pex',
        'assets/pexfiles/rocket_explosion_3.pex',
        'assets/pexfiles/rocket_burn_effect4.pex',
        'assets/pexfiles/rocket_explosion_4.pex',
        ]
        particles = self.gameworld.systems['particles']
        for effect in particle_effects:
            particles.load_particle_config(effect)

    def _init_game(self, dt):
        self.setup_states()
        self.setup_map()
        self.set_main_menu_state()
        self.setup_collision_callbacks()
        self.setup_gameobjects()
        self.setup_particle_effects()
        Clock.schedule_interval(self.update, 1./60.)

    def update(self, dt):
        self.gameworld.update(int(dt))

    def setup_collision_callbacks(self):
        systems = self.gameworld.systems
        physics = systems['cymunk_physics']
        ship_system = systems['ship_system']
        projectile_system = systems['projectile_system']
        asteroid_system = systems['asteroid_system']
        boundary_system = systems['boundary_system']
        physics.add_collision_handler(1, 1, 
            begin_func=asteroid_system.collision_begin_asteroid_asteroid)
        physics.add_collision_handler(1, 3, 
            begin_func=projectile_system.collision_begin_asteroid_bullet,
            separate_func=projectile_system.collision_solve_asteroid_bullet)
        physics.add_collision_handler(2, 3, 
            begin_func=projectile_system.collision_begin_ship_bullet,
            separate_func=projectile_system.collision_solve_ship_bullet)
        physics.add_collision_handler(2, 1, 
            begin_func=ship_system.collision_begin_ship_asteroid)
        physics.add_collision_handler(3, 3, 
            begin_func=projectile_system.collision_begin_bullet_bullet, 
            separate_func=projectile_system.collision_solve_bullet_bullet)
        physics.add_collision_handler(2, 4, 
            begin_func=ship_system.collision_begin_ship_probe)
        physics.add_collision_handler(1, 10,
            begin_func=boundary_system.collision_begin_func,
            separate_func=boundary_system.collision_separate_func)
        physics.add_collision_handler(2, 10,
            begin_func=boundary_system.collision_begin_func,
            separate_func=boundary_system.collision_separate_func)
        physics.add_collision_handler(3, 10,
            begin_func=boundary_system.collision_begin_func,
            separate_func=boundary_system.collision_separate_func)
        physics.add_collision_handler(4, 10,
            begin_func=boundary_system.collision_begin_func,
            separate_func=boundary_system.collision_separate_func)
        physics.add_collision_handler(5, 1,
            begin_func=ship_system.collision_object_shipview_begin,
            separate_func=ship_system.collision_object_shipview_end)
        physics.add_collision_handler(5, 2,
            begin_func=ship_system.collision_object_shipview_begin,
            separate_func=ship_system.collision_object_shipview_end)   
        physics.add_collision_handler(5, 3,
            begin_func=ship_system.collision_object_shipview_begin,
            separate_func=ship_system.collision_object_shipview_end)   
        physics.add_collision_handler(5, 4,
            begin_func=ship_system.collision_object_shipview_begin,
            separate_func=ship_system.collision_object_shipview_end)  
        physics.add_collision_handler(5, 5,
            begin_func=self.null_collide,
            separate_func=self.null_collide)
        physics.add_collision_handler(5, 10,
            begin_func=self.null_collide,
            separate_func=self.null_collide)
        

    def set_choose_character_state(self, dt):
        self.gameworld.state = 'choose_character'

    def check_win_conditions(self):
        if self.gameworld.state == 'main_game':
            number_of_asteroids = self.number_of_asteroids
            number_of_probes = self.number_of_probes
            number_of_enemies = self.number_of_enemies
            number_of_enemies_to_spawn = self.number_of_enemies_to_spawn
            winning = True
            if self.do_enemies:
                if number_of_enemies > 0 or number_of_enemies_to_spawn > 0:
                    winning = False
            if self.do_probes:
                if number_of_probes > 0:
                    winning = False
            if self.do_asteroids:
                if number_of_asteroids > 0:
                    winning = False
            return winning
        else:
            return False

    def on_number_of_enemies(self, instance, value):
        if 'asteroids_level' in self.gameworld.systems:
            if self.check_win_conditions():
                self.gameworld.systems['asteroids_level'].current_level_id += 1
                self.current_level = self.gameworld.systems[
                    'asteroids_level'].current_level_id + 1
                Clock.schedule_once(self.set_choose_character_state, 2.0)

    def on_number_of_probes(self, instance, value):
        if 'asteroids_level' in self.gameworld.systems:
            if self.check_win_conditions():
                self.gameworld.systems['asteroids_level'].current_level_id += 1
                self.current_level = self.gameworld.systems[
                    'asteroids_level'].current_level_id + 1
                Clock.schedule_once(self.set_choose_character_state, 2.0)

    def on_number_of_asteroids(self, instance, value):
        if 'asteroids_level' in self.gameworld.systems:
            if self.check_win_conditions():
                self.gameworld.systems['asteroids_level'].current_level_id += 1
                self.current_level = self.gameworld.systems[
                    'asteroids_level'].current_level_id + 1
                Clock.schedule_once(self.set_choose_character_state, 2.0)

    def player_lose(self, dt):
        self.gameworld.state = 'game_over'
        self.current_lives -= 1
        if self.current_lives < 0:
            self.gameworld.systems['asteroids_level'].current_level_id = 0
            self.current_level = self.gameworld.systems[
                'asteroids_level'].current_level_id + 1
            self.current_lives = 3
            

class KivEntApp(App):
    shader_path = StringProperty('assets/shaders/')

    def build(self):
        Window.clearcolor = (0, 0, 0, 1.)



if __name__ == '__main__':
   KivEntApp().run()
    # sd_card_path = os.path.dirname('/sdcard/profiles/')
    # print sd_card_path
    # if not os.path.exists(sd_card_path):
    #     print 'making directory'
    #     os.mkdir(sd_card_path)
    # print 'path: ', sd_card_path
    # cProfile.run('KivEntApp().run()', sd_card_path + '/asteroidsprof.prof')