import tmx
from os.path import basename, dirname

def init_entities_from_map(tile_map, init_entity):
    w, h = tile_map.size_on_screen
    tile_size = tile_map.tile_size
    for j in range(tile_map.size[0]):
        for i in range(tile_map.size[1]):
            tile = tile_map.get_tile(j,i)
            comp_data = {
                'position': (i * tile_size + tile_size/2, h - j * tile_size - tile_size/2),
                'tile_map': {'name': tile_map.name, 'pos': (i,j)},
                'renderer': {
                    'model': tile.model,
                    'texture': tile.texture
                    }
                }
            systems = ['position', 'tile_map', 'renderer']
            if tile.animation:
                comp_data['animation'] = {
                    'name': tile.animation,
                    'loop': True,
                        }
                systems.append('animation')

            init_entity(comp_data, systems)


def parse_tmx(filename, texture_manager, model_manager, map_manager):
    tilemap = tmx.TileMap.load(filename)

    tiles, tile_ids = _load_tile_map(tilemap.layers[0], tilemap.width)
    _load_tilesets(tilemap.tilesets, dirname(filename), tile_ids,
                   texture_manager.load_atlas,
                   model_manager.load_textured_rectangle)

    name ='.'.join(basename(filename).split('.')[:-1])
    map_manager.load_map(name, (tilemap.width, tilemap.height),
                         tilemap.tilewidth, tiles)

    return name


def _load_tilesets(tilesets, dirname, tile_ids, load_atlas, load_model):
    atlas_data = {}
    model_data = {}
    for tileset in tilesets:
        image = tileset.image
        name = image.source
        fgid = int(tileset.firstgid)
        w, h = int(image.width), int(image.height)
        tw, th = int(tileset.tilewidth), int(tileset.tileheight)
        m, s = int(tileset.margin), int(tileset.spacing)

        rows = (w + s)/(tw + 2*m + s)
        cols = (h + s)/(th + 2*m + s)

        atlas_data[name] = {}
        for tile in range(tileset.tilecount):
            if (tile + fgid) in tile_ids:
                x, y = tile % rows, cols - 1 - int(tile / rows)
                px, py = x * (tw + 2*m + s) + m, y * (th + 2*m + s) + m
                atlas_data[name]['tile_%d' % (tile + fgid)] = (px, py, tw, th)
                model_data['tile_%d' % (tile + fgid)] = (tw, th)

    load_atlas(atlas_data, 'dict', dirname)
    for model in model_data:
        tw, th = model_data[model]
        load_model('vertex_format_4f', tw, th, model, model)


def _load_tile_map(layer, width):
    tiles = []
    tile_row = []
    tile_ids = set()
    for tile in layer.tiles:
        tile_ids.add(tile.gid)
        tile = {'texture': 'tile_%d' % tile.gid,
                'model': 'tile_%d' % tile.gid}
        tile_row.append(tile)

        if len(tile_row) == width:
            tiles.append(tile_row)
            tile_row = []

    return tiles, list(tile_ids)
