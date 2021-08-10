from functools import partial
from os.path import dirname, join, abspath
from random import randint, choice
import signal
from math import radians, pi, sin, cos

from kivy.app import App
from kivy.logger import Logger
from kivy.uix.widget import Widget
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.vector import Vector
import kivent_core
import kivent_cymunk
from kivent_core.gameworld import GameWorld
from kivent_core.managers.resource_managers import texture_manager

from kivent_core.rendering.svg_loader import SVGModelInfo
from kivent_core.systems.renderers import RotateRenderer
from kivent_core.systems.position_systems import PositionSystem2D
from kivent_core.systems.rotate_systems import RotateSystem2D
from kivent_cymunk.interaction import CymunkTouchSystem
from kivy.properties import StringProperty, NumericProperty

from concave2convex import merge_triangles, cached_mtr
from debugdraw import gv

texture_manager.load_atlas(join(dirname(dirname(abspath(__file__))), 'assets', 
    'background_objects.atlas'))



class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.gameworld.init_gameworld(
            ['cymunk_physics', 'poly_renderer', 'rotate', 'position',  'cymunk_touch' ],
            callback=self.init_game)

    def init_game(self):
        self.setup_states()
        self.draw_some_stuff()
        self.set_state()

    def destroy_created_entity(self, ent_id, dt):
        self.gameworld.remove_entity(ent_id)
        self.app.count -= 1

    def draw_some_stuff(self):
        self.gameworld.clear_entities()

        self.load_svg('objects.svg', self.gameworld)

    def load_svg(self, fname, gameworld):
        mm = gameworld.model_manager
        data = mm.get_model_info_for_svg(fname)

        posvel = {
                    'spiral': ((300, 300), (0, 0)), 
                    'ball': ((600, 130), (-800, 0))
                }

        for info in data['model_info']:

            pos, vel = posvel[info.element_id]

            Logger.debug("adding object with title/element_id=%s/%s and desc=%s", info.title, info.element_id, info.description)
            model_name = mm.load_model_from_model_info(info, data['svg_name'])

            shapeno = 0
            shapes = []
            for poly in cached_mtr(info.path_vertices):
            #for poly in merge_triangles(info.path_vertices):
                
                shape = {
                    'shape_type': 'poly',
                    'elasticity': 0.8,
                    'collision_type': 1,
                    'friction': 0.1,
                    'shape_info': {
                        'mass': 50,
                        'offset': (0, 0),
                        'vertices': poly
                    }

                }
                Logger.debug("shape %s added", shapeno)
                shapeno += 1
                shapes.append(shape)

            #shapepolys = [x['shape_info']['vertices'] for x in shapes]
            #gv(shapepolys, pdf=False)



            physics = {
                    'main_shape': 'poly',
                    'velocity': vel,
                    'position': pos,
                    'angle': 0,
                    'angular_velocity': radians(0),
                    'ang_vel_limit': radians(0),
                    'mass': 0 if info.element_id == 'spiral' else 50, 
                    'col_shapes': shapes
            }

            create_dict = {
                    'position': pos,
                    'poly_renderer': {'model_key': model_name},
                    'cymunk_physics': physics, 
                    'rotate': radians(0),
            }

            #need to pause it a bit
            Clock.schedule_once(partial(self.init_entity, create_dict))
            self.app.count += 1

    def init_entity(self, create_dict, dt):
        self.gameworld.init_entity(create_dict, ['position', 'rotate', 'poly_renderer', 'cymunk_physics'])

    def update(self, dt):
        self.gameworld.update(dt)

    def setup_states(self):
        self.gameworld.add_state(state_name='main', 
            systems_added=['poly_renderer', 'cymunk_physics'],
            systems_removed=[], systems_paused=[],
            systems_unpaused=['poly_renderer', 'cymunk_physics'],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'


class DebugPanel(Widget):
    fps = StringProperty(None)

    def __init__(self, **kwargs):
        super(DebugPanel, self).__init__(**kwargs)
        Clock.schedule_once(self.update_fps)

    def update_fps(self,dt):
        self.fps = str(int(Clock.get_fps()))
        Clock.schedule_once(self.update_fps, .05)

class YourAppNameApp(App):
    count = NumericProperty(0)

if __name__ == '__main__':
    YourAppNameApp().run()
