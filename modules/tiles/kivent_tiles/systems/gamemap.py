from decimal import Decimal
from itertools import cycle

from kivy.factory import Factory
from kivent_core.systems.gamemap import GameMap
from tmxloader.loader import TileMap, ObjectType
from kivy.properties import StringProperty, ObjectProperty
from kivent_core.managers.resource_managers import texture_manager

from ..utils import name_from_tile, name_from_source


class TiledGameMap(GameMap):
    map_source = StringProperty(None)
    atlas_source = StringProperty(None)
    system_id = StringProperty('tilemap')
    renderer = StringProperty('map_renderer')
    animator_obj = ObjectProperty(None)

    def __init__(self, *args, **kwargs):
        super(TiledGameMap, self).__init__(*args, **kwargs)
        self.map = None
        self.tiles = []
        self.tile_number = None

    def init(self):
        self.load_tmx_file()
        self.load_textures()

        self.create_map()
        self.init_animator()
        self.map_size = self.map.size

    def init_animator(self):
        animator_obj = self.animator_obj
        if animator_obj and animator_obj.has_animations:
            animator_obj.init()

    def image_loader(self, tileset=None, image_layer=None):
        def extract_image(tile=None):
            if tileset and tile is not None:
                if tileset.is_images_collection:
                    return name_from_source(tile.source)
                return name_from_tile(tile)
            return name_from_source(image_layer.source)
        return extract_image

    def load_tmx_file(self):
        if self.map_source is None:
            raise Exception('No map source provided.')
        self.map = TileMap(self.map_source, image_loader=self.image_loader, load_unused_tiles=True)

    def load_textures(self):
        if not self.atlas_source:
            raise Exception('No map atlas provided!')
        texture_manager.load_atlas(self.atlas_source)

    def create_map(self):
        map_obj = self.map
        self.create_tiles(map_obj.get_tile_layers(visible=True))
        self.create_images(map_obj.get_image_layers(visible=True))
        self.create_objects(map_obj.get_object_groups(visible=True))

    def handle_tile_animation(self, animation_frames):
        # use Decimal because gcd function doesn't play well with floats (floating point inaccuracy)
        self.animator_obj.durations.extend(Decimal(str(f.duration_seconds)) for f in animation_frames)
        frames = cycle(animation_frames)
        return {
            'timer': 0,
            # since 'frames' is a generator obj, we need to store current frame
            'current_frame': next(frames),
            'frames': frames
        }

    def create_tiles(self, tile_layers):
        animator = self.animator_obj.system_id
        append_tile = self.tiles.append
        init_entity = self.gameworld.init_entity
        for layer in tile_layers:
            for cell in layer:
                renderer_id = self.renderer
                w, h = cell.size
                x, y = cell.pos
                x += w / 2.0
                y -= h / 2.0
                create_component_dict = {
                    renderer_id: {
                        'texture': cell.image,
                        'size': cell.size,
                        'render': True
                    },
                    'position': (x, y),
                }
                component_order = ['position', renderer_id]
                tile_properties = cell.tile.properties
                if tile_properties:
                    animation_frames = tile_properties.get('animation_frames')
                    if animation_frames and animator:
                        animation_component_dict = self.handle_tile_animation(animation_frames)
                        create_component_dict[animator] = animation_component_dict
                        component_order.append(animator)
                append_tile(init_entity(create_component_dict, component_order))

    def create_images(self, image_layers):
        append_tile = self.tiles.append
        for layer in image_layers:
            texture_name = layer.image
            x, y = layer.pos
            w, h = texture_manager.get_size_by_name(texture_name)
            x += w / 2.0
            y -= h / 2.0
            renderer_id = self.renderer
            create_component_dict = {
                renderer_id: {
                    'texture': texture_name,
                    'size': (w, h),
                    'render': True
                },
                'position': (x, y),
            }
            component_order = ['position', renderer_id]
            append_tile(self.gameworld.init_entity(create_component_dict, component_order))

    def create_objects(self, object_layers):
        append_tile = self.tiles.append
        init_entity = self.gameworld.init_entity
        for layer in object_layers:
            for obj in layer:
                if obj.type != ObjectType.Tile:
                    continue

                renderer_id = self.renderer
                w, h = obj.size
                x, y = obj.pos
                x += w / 2.0
                y += h / 2.0
                create_component_dict = {
                    renderer_id: {
                        'texture': obj.image,
                        'size': obj.size,
                        'render': True
                    },
                    'position': (x, y),
                }
                component_order = ['position', renderer_id]
                append_tile(init_entity(create_component_dict, component_order))

    def clear_map(self):
        self.gameworld.entities_to_remove.extend(self.tiles)


Factory.register('TiledGameMap', cls=TiledGameMap)
