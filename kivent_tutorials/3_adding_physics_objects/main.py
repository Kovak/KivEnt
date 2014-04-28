from kivy.app import App
from kivy.uix.widget import Widget
from kivy.clock import Clock
from kivy.core.window import Window
import kivent
from random import randint
from math import radians


class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        Clock.schedule_once(self.init_game)
        self.asteroids = []

    def init_game(self, dt):
        self.setup_map()
        self.setup_states()
        self.set_state()
        self.draw_some_stuff()
        Clock.schedule_interval(self.update, 0)

    def draw_some_stuff(self):
        size = Window.size
        for x in range(50):
            pos = (randint(0, size[0]), randint(0, size[1]))
            self.create_asteroid(pos)

    def create_asteroid(self, pos):
        x_vel = randint(-100, 100)
        y_vel = randint(-100, 100)
        angle = radians(randint(-360, 360))
        angular_velocity = radians(randint(-150, -150))
        shape_dict = {'inner_radius': 0, 'outer_radius': 32, 
            'mass': 50, 'offset': (0, 0)}
        col_shape = {'shape_type': 'circle', 'elasticity': .5, 
            'collision_type': 1, 'shape_info': shape_dict, 'friction': 1.0}
        col_shapes = [col_shape]
        physics_component = {'main_shape': 'circle', 
            'velocity': (x_vel, y_vel), 
            'position': pos, 'angle': angle, 
            'angular_velocity': angular_velocity, 
            'vel_limit': 1250, 
            'ang_vel_limit': radians(200), 
            'mass': 10, 'col_shapes': col_shapes}
        create_component_dict = {'physics': physics_component, 
            'physics_renderer': {'texture': 'asteroid1', 'size': (64 , 64)}, 
            'position': pos, 'rotate': 0}
        component_order = ['position', 'rotate', 
            'physics', 'physics_renderer']
        asteroidID = self.gameworld.init_entity(create_component_dict, component_order)
        self.asteroids.append(asteroidID)
        return asteroidID

    def setup_map(self):
        gameworld = self.gameworld
        gameworld.currentmap = gameworld.systems['map']

    def on_touch_move(self, touch):
        pos = (touch.x, touch.y)
        self.create_asteroid(pos)
        for aid in self.asteroids:
          asteroid = self.gameworld.entities[aid]
          apos = asteroid.position
          dvecx = (touch.x-apos.x)*asteroid.physics.body.mass*0.1
          dvecy = (touch.y-apos.y)*asteroid.physics.body.mass*0.1
          asteroid.physics.body.apply_impulse((dvecx,dvecy))
        print "There are: %i Asteroids" % len(self.asteroids)
    def on_touch_down(self, touch):
        pos = (touch.x, touch.y)
        self.create_asteroid(pos)
    def update(self, dt):
        self.gameworld.update(dt)

    def setup_states(self):
        self.gameworld.add_state(state_name='main', 
            systems_added=['renderer', 'physics_renderer'],
            systems_removed=[], systems_paused=[],
            systems_unpaused=['renderer', 'physics_renderer'],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'


class YourAppNameApp(App):
    def build(self):
        Window.clearcolor = (0, 0, 0, 1.)


if __name__ == '__main__':
    YourAppNameApp().run()
