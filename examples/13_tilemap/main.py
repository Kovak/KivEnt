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
from kivy.factory import Factory

def get_asset_path(asset, asset_loc):
    return join(dirname(dirname(abspath(__file__))), asset_loc, asset)

class TileSystem(GameSystem):
    tile_width = NumericProperty(64.)
    tile_height = NumericProperty(64.)
    tiles_in_x = NumericProperty(100)
    tiles_in_y = NumericProperty(100)
    camera_pos = ListProperty(None, allownone=True)
    camera_size = ListProperty(None, allownone=True)

    def __init__(self, **kwargs):
        super(TileSystem, self).__init__(**kwargs)
        self.tiles_on_screen_last_frame = set()
        self.tile_trigger = Clock.create_trigger(self.handle_tile_drawing)
        self.calc_tiles_trigger = Clock.create_trigger(self.calc_tiles)
        self.calc_tiles_trigger()

    def calc_tiles(self, dt):
        self.tiles = [[None for y in range(self.tiles_in_y)] for x in range(
                     self.tiles_in_x)]

    def on_tiles_in_x(self, instance, value):
        self.calc_tiles_trigger()

    def on_tiles_in_y(self, instance, value):
        self.calc_tiles_trigger()

    def on_camera_pos(self, instance, value):
        self.tile_trigger()

    def handle_tile_drawing(self, dt):
        if self.camera_pos is not None and self.camera_size is not None:
            last_frame = self.tiles_on_screen_last_frame
            components = self.components
            init_entity = self.gameworld.init_entity
            remove_entity = self.gameworld.remove_entity
            tiles_in_view = set(self.calculate_tiles_in_view())
            screen_pos_from_tile_pos = self.get_screen_pos_from_tile_pos
            new = tiles_in_view - last_frame
            removed = last_frame - tiles_in_view
            self.tiles_on_screen_last_frame = tiles_in_view
            for component_index in removed:
                tile_comp = self.components[component_index]
                remove_entity(tile_comp.current_entity)
                tile_comp.current_entity = None
            for component_index in new:
                tile_comp = self.components[component_index]
                screen_pos = screen_pos_from_tile_pos(
                        tile_comp.tile_pos)
                create_dict = {
                    'position': screen_pos,
                    'renderer': {'texture': tile_comp.texture, 
                                 'model_key': tile_comp.texture},
                    }
                ent = init_entity(create_dict, ['position', 'renderer'])
                tile_comp.current_entity = ent
            
    def on_camera_size(self, instance, value):
        self.tile_trigger()

    def get_world_pos(self, pos):
        tile_max_x = self.tiles_in_x * self.tile_width
        tile_max_y = self.tiles_in_y * self.tile_height
        return (pos[0] % tile_max_x, pos[1] % tile_max_y)

    def get_screen_pos_from_tile_pos(self, tile_pos):
        cx, cy = -self.camera_pos[0], -self.camera_pos[1]
        tile_max_x = self.tiles_in_x * self.tile_width
        tile_max_y = self.tiles_in_y * self.tile_height
        tcx, tcy = self.get_tile_at_world_pos(
            self.get_world_pos((cx, cy)))
        wx, wy = self.get_world_pos_from_tile_pos(tile_pos)
        origin_x, origin_y = None, None
        if tile_pos[0] < tcx:
            origin_x = (cx // tile_max_x + 1) * tile_max_x
        else:
            origin_x = (cx // tile_max_x) * tile_max_x
        if tile_pos[1] < tcy:
            origin_y = (cy // tile_max_y + 1) * tile_max_y
        else:
            origin_y = (cy // tile_max_y) * tile_max_y
        return origin_x + wx, origin_y + wy

    def get_world_pos_from_tile_pos(self, tile_pos):
        return (tile_pos[0] * self.tile_width, 
                tile_pos[1] * self.tile_height)

    def get_tile_at_world_pos(self, world_pos):
        return (int(world_pos[0] // self.tile_width),
                int(world_pos[1] // self.tile_height))

    def calculate_tiles_in_view(self):
        cx, cy = -self.camera_pos[0], -self.camera_pos[1]
        cw, ch = self.camera_size
        tile_width = self.tile_width
        tile_height = self.tile_height
        tiles_in_x = self.tiles_in_x
        tiles_in_y = self.tiles_in_y
        world_pos = self.get_world_pos((cx, cy))
        x_count = int(cw // tile_width) + 2
        y_count = int(ch // tile_height) + 2
        starting_x, starting_y = self.get_tile_at_world_pos(world_pos)
        end_x = starting_x + x_count
        end_y = starting_y + y_count
        tiles_in_view = []
        tiles_a = tiles_in_view.append
        tiles = self.tiles
        for x in range(starting_x, end_x):
            actual_x = x % tiles_in_x
            for y in range(starting_y, end_y):
                actual_y = y % tiles_in_y
                tile = tiles[actual_x][actual_y]
                if tile is not None:
                    tiles_a(tile)
        return tiles_in_view

    def init_component(self, component_index, entity_id, zone, args):
        component = self.components[component_index]
        component.entity_id = entity_id
        component.texture = args.get('texture')
        component.tile_pos = tx, ty = args.get('tile_pos')
        component.current_entity = None
        self.tiles[tx][ty] = component_index


Factory.register('TileSystem', cls=TileSystem)


class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.gameworld.init_gameworld(
            ['renderer', 'position', 'camera1', 'tiles'],
            callback=self.init_game)

    def init_game(self):
        self.setup_states()
        self.load_textures()
        self.load_models()
        self.set_state()
        self.setup_tiles()

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

    def setup_tiles(self):
        init_entity = self.gameworld.init_entity
        tile_system = self.ids.tiles
        for x in range(tile_system.tiles_in_x):
            for y in range(tile_system.tiles_in_y):
                model_key = choice(['orange-tile', 'green-tile', 'purple-tile',
                                    'blue-tile'])
                create_dict = {
                    'tiles': {'texture': model_key, 'tile_pos': (x, y)},
                }
                ent = init_entity(create_dict, ['tiles'])
        tile_system.tile_trigger()

    def setup_states(self):
        self.gameworld.add_state(state_name='main', systems_added=['renderer'],
                                 systems_unpaused=['renderer'])

    def set_state(self):
        self.gameworld.state = 'main'


class YourAppNameApp(App):
    pass


if __name__ == '__main__':
    YourAppNameApp().run()