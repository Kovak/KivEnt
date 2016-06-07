def init_entities_from_map(tile_map, init_entity):
    w, h = tile_map.size_on_screen
    tile_size = tile_map.tile_size
    for i in range(tile_map.size[0]):
        for j in range(tile_map.size[1]):
            tile = tile_map.get_tile(i,j)
            comp_data = {
                'position': (i * tile_size, h - j * tile_size),
                'tile_map': {'name': tile_map.name, 'pos': (i,j)},
                'renderer': {
                    'texture': tile.texture,
                    'model': tile.model
                    }
                }
            init_entity(comp_data, ['position', 'tile_map', 'renderer'])
