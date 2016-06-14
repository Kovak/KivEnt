def init_entities_from_map(tile_map, init_entity):
    w, h = tile_map.size_on_screen
    tile_size = tile_map.tile_size
    for i in range(tile_map.size[0]):
        for j in range(tile_map.size[1]):
            tile = tile_map.get_tile(i,j)
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
