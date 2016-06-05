from kivy.app import App
from kivy.uix.widget import Widget
from kivy.clock import Clock
from random import choice
import kivent_core
from kivent_core.gameworld import GameWorld
from kivent_core.managers.resource_managers import texture_manager
from kivy.properties import StringProperty, NumericProperty, ListProperty
from os.path import dirname, join, abspath
from kivent_core.systems.gamesystem import GameSystem
from kivent_maps import map_utils
from kivent_maps.map_system import MapSystem

def get_asset_path(asset, asset_loc):
    return join(dirname(dirname(abspath(__file__))), asset_loc, asset)

class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.gameworld.init_gameworld(
            ['renderer', 'position', 'camera1', 'tile_map'],
            callback=self.init_game)

    def init_game(self):
        self.setup_states()
        self.load_textures()
        self.load_models()
        self.set_state()
        self.setup_tile_map()

    def load_textures(self):
        texture_manager.load_image(get_asset_path('orange-tile.png', 'assets'))
        texture_manager.load_image(get_asset_path('purple-tile.png', 'assets'))
        texture_manager.load_image(get_asset_path('green-tile.png', 'assets'))
        texture_manager.load_image(get_asset_path('blue-tile.png', 'assets'))

    def load_models(self):
        model_manager = self.gameworld.model_manager
        model_manager.load_textured_rectangle('vertex_format_4f', 64., 64.,
                                              'orange-tile', 'orange-tile')
        model_manager.load_textured_rectangle('vertex_format_4f', 64., 64.,
                                              'purple-tile', 'purple-tile')
        model_manager.load_textured_rectangle('vertex_format_4f', 64., 64.,
                                              'green-tile', 'green-tile')
        model_manager.load_textured_rectangle('vertex_format_4f', 64., 64.,
                                              'blue-tile', 'blue-tile')

    def setup_tile_map(self):
        map_manager = self.gameworld.map_manager

        tiles = []
        for i in range(100):
            tiles[i] = []
            for j in range(100):
                tile_name = choice(['orange-tile', 'purple-tile', 'green-tile', 'blue-tile'])
                tiles[i][j] = {
                        'texture': tile_name,
                        'model': tile_name
                        }

        map_manager.load_map('my_map', (100, 100), 64, tiles)

        map_utils.init_entities_from_map(map_manager.maps['my_map'], self.gameworld.init_entity)

    def setup_states(self):
        self.gameworld.add_state(state_name='main', systems_added=['renderer'],
                                 systems_unpaused=['renderer'])

    def set_state(self):
        self.gameworld.state = 'main'


class YourAppNameApp(App):
    pass


if __name__ == '__main__':
    YourAppNameApp().run()
