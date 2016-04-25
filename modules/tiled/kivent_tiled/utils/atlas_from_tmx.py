import os
import shutil
import tempfile
from itertools import chain

import click
from PIL import Image
from tmxloader.loader import TileMap
from kivent_tiled.utils import name_from_tile, name_from_source

os.environ['KIVY_DOC_INCLUDE'] = '1'
from kivy.atlas import Atlas


@click.command()
@click.argument('map_source')
@click.argument('outname')
@click.argument('size', nargs=2, type=int)
@click.argument('padding', default=2)
@click.argument('use_path', default=False)
def atlas_from_tileset(map_source, **kwargs):
    atlas = AtlasWrapper(map_source)
    atlas.create_atlas(**kwargs)


class AtlasWrapper(object):
    def __init__(self, map_source):
        self.tilesets = []
        self.image_layers = []
        self.map = TileMap(map_source, image_loader=self.image_loader)

    def add_tileset(self, tileset):
        tileset_wrapper = TilesetWrapper(tileset)
        self.tilesets.append(tileset_wrapper)
        return tileset_wrapper

    def add_image_layer(self, image_layer):
        self.image_layers.append(ImageLayerWrapper(image_layer))

    def image_loader(self, tileset=None, image_layer=None):
        if tileset:
            tileset_wrapper = self.add_tileset(tileset)
        else:
            self.add_image_layer(image_layer)

        def extract_image(tile=None):
            if tileset and tile is not None:
                return tileset_wrapper.add_image(tile)
            return name_from_source(image_layer.source)
        return extract_image

    def __iter__(self):
        return (filename for wrapper in chain(self.tilesets, self.image_layers)
                for filename in wrapper)

    def create_atlas(self, **kwargs):
        Atlas.create(filenames=set(self), **kwargs)


class ImageCollectionWrapper(object):
    def __init__(self, image_collection):
        self.filenames = []
        self.source = image_collection.source

    def __iter__(self):
        return iter(self.filenames)

    def add_image(self, *args, **kwargs):
        raise NotImplementedError


class ImageLayerWrapper(ImageCollectionWrapper):
    def __init__(self, image_collection):
        super(ImageLayerWrapper, self).__init__(image_collection)
        self.add_image()

    def add_image(self):
        source = self.source
        self.filenames.append(source)
        return name_from_source(source)


class TilesetWrapper(object):
    def __new__(cls, *args, **kwargs):
        tileset, = args
        if tileset.is_images_collection:
            return ImageCollectionTilesetWrapper(tileset)
        return SingleImageTilesetWrapper(tileset)


class ImageCollectionTilesetWrapper(ImageCollectionWrapper):
    def add_image(self, tile):
        source = tile.source
        self.filenames.append(source)
        return name_from_source(source)


class SingleImageTilesetWrapper(ImageCollectionTilesetWrapper):
    image_extension = '.png'

    def __init__(self, image_collection):
        super(SingleImageTilesetWrapper, self).__init__(image_collection)
        self.base_image = Image.open(self.source)
        self.tmpdir = tempfile.mkdtemp()

    def add_image(self, tile):
        x, y, w, h = tile.rect
        box = (x, y, x + w, y + h)
        tile_image = self.base_image.crop(box)
        tile_name = name_from_tile(tile)
        image_path = os.path.join(self.tmpdir, tile_name + self.image_extension)
        tile_image.save(image_path)
        self.filenames.append(image_path)
        return tile_name

    def __del__(self):
        shutil.rmtree(self.tmpdir)


if __name__ == '__main__':
    atlas_from_tileset()
