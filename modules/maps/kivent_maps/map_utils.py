import tmx
from tmx import Layer, ObjectGroup
from os.path import basename, dirname

from kivent_core.systems.renderers import Renderer, ColorPolyRenderer
from kivent_core.systems.animation import AnimationSystem

from math import sin, cos, radians

def load_map_systems(layer_count, gameworld, renderargs, animargs, polyargs):
    '''
    Create and initialise the systems required for displaying all layers of the
    map. Each layer requires a Renderer for images, PolyRenderer for shapes
    and AnimationSystem for animated tiles.

    The name format of the Renderer is map_layer%d, PolyRenderer is
    map_layer%d_polygons, AnimationSystem is map_layer%d_animator
    where %d is the layer number.

    Args:
        layer_count (unsigned int): Number of layers to init

        gameworld (Gameworld): Instance of the gameworld

        renderargs (dict): Dict of arguments required to init the Renderer.
        This is same as those used in a KV file for adding a system.

        animargs (dict): Dict of arguments required to init the AnimationSystem

        polyargs (dict): Dict of arguments required to init the PolyRenderer.

    Return:
        list of str, list of str: A tuple of two lists of system names with fisrt
        containing names of Renderers and PolyRenderers and second containing
        names of AnimationSystems. The names are in the order in which they are
        added to the Gameworld. You can use these lists for init_gameworld
        and setup_state.

    '''
    rendersystems = []
    for i in range(layer_count):
        rendersystems.extend(['map_layer%d' % i, 'map_layer%d_polygons' % i])
    animsystems = ['map_layer%d_animator' % i for i in range(layer_count)]

    system_count = gameworld.system_count

    for i in range(layer_count):
        renderargs['system_id'] = rendersystems[2 * i]
        renderargs['system_names'] = [rendersystems[2 * i], 'position']
        animargs['system_id'] = animsystems[i]
        animargs['system_names'] = [animsystems[i],rendersystems[2 * i]]
        polyargs['system_id'] = rendersystems[2 * i + 1]
        polyargs['system_names'] = [rendersystems[2 * i + 1],
                                    'position',
                                    'color']

        r = Renderer()
        a = AnimationSystem()
        p = ColorPolyRenderer()

        r.gameworld = gameworld
        a.gameworld = gameworld
        p.gameworld = gameworld
        for k in renderargs:
            setattr(r,k,renderargs[k])
        for k in animargs:
            setattr(a,k,animargs[k])
        for k in polyargs:
            setattr(p,k,polyargs[k])

        gameworld.add_widget(r, system_count)
        gameworld.add_widget(a, system_count)
        gameworld.add_widget(p, system_count)
        system_count += 3

    gameworld.system_count = system_count

    return rendersystems, animsystems


def init_entities_from_map(tile_map, init_entity):
    '''
    Initialise entities for every layer of every tile and add them to the
    corresponding systems.

    Args:
        tile_map (TileMap): the tile map from which to load the tiles.

        init_entity (function): the gameworld.init_entity function

    '''
    z_map = tile_map.z_index_map

    # Load tile entities
    for i in range(tile_map.size[0]):
        for j in range(tile_map.size[1]):
            # Get Tile object for position (i, j)
            tile_layers = tile_map.get_tile(i,j)

            # Loop through all LayerTiles
            for tile in tile_layers.layers:
                renderer_name = 'map_layer%d' % z_map[tile.layer]
                animator_name = 'map_layer%d_animator' % z_map[tile.layer]
                comp_data = {
                    'position': tile_map.get_tile_position(i, j),
                    'tile_map': {'name': tile_map.name, 'pos': (i,j)},
                    renderer_name: {
                        'model': tile.model,
                        'texture': tile.texture
                        }
                    }
                systems = ['position', 'tile_map', renderer_name]

                # If tile is animated add that component
                if tile.animation:
                    comp_data[animator_name] = {
                        'name': tile.animation,
                        'loop': True,
                            }
                    systems.append(animator_name)

                init_entity(comp_data, systems)

    # Load object entities
    for obj_layer in tile_map.objects:
        mh = tile_map.size_on_screen[1]
        for obj in obj_layer:
            if obj.texture:
                # Object is an image
                renderer_name = 'map_layer%d' % z_map[obj.layer]
                comp_data = {
                    'position': (obj.position[0], mh - obj.position[1]),
                    renderer_name: {
                        'model': obj.model,
                        'texture': obj.texture,
                        }
                    }
                systems = ['position', renderer_name]
            else:
                # Object is a shape
                renderer_name = 'map_layer%d_polygons' % z_map[obj.layer]
                comp_data = {
                    'position': (obj.position[0], mh - obj.position[1]),
                    renderer_name: {
                        'model_key': obj.model,
                        },
                    # Color is taken from vertex, so white here
                    'color': (255, 255, 255, 255)
                    }
                systems = ['position','color', renderer_name]

            init_entity(comp_data, systems)

def parse_tmx(filename, gameworld):
    '''
    Uses the tmx library to load the TMX into an object and then calls all the
    util functions with the relevant data.

    Args:
        filename (str): Name of the tmx file.

        gameworld (Gameworld): instance of the gameworld.

    Return:
        str: name of the loaded map which is the filename

    '''
    texture_manager = gameworld.managers['texture_manager']
    model_manager = gameworld.managers['model_manager']
    map_manager = gameworld.managers['map_manager']
    animation_manager = gameworld.managers['animation_manager']

    # Get tilemap object with all the data from tmx
    tilemap = tmx.TileMap.load(filename)

    # Get the tiles as a 3D list and the z_map, objects as a 2D list and the
    # z_map, the set of tile_ids which will be used in the map,
    # set of models of the objects in the map.
    tiles, tiles_z, objects, objects_z, tile_ids, objmodels = \
            _load_tile_map(tilemap.layers, tilemap.width,
                           _load_tile_properties(tilemap.tilesets))

    # Loads the models, textures and animations of the tileset into
    # corresponding managers
    _load_tilesets(tilemap.tilesets, dirname(filename), tile_ids,
                   texture_manager.load_atlas,
                   model_manager.load_textured_rectangle,
                   animation_manager.load_animation)

    # Load the object models with model_manager
    _load_obj_models(objmodels, model_manager.load_textured_rectangle,
                     model_manager.load_model)

    # Load the map with map_manager
    name ='.'.join(basename(filename).split('.')[:-1])
    map_manager.load_map(name, tilemap.width, tilemap.height,
                         tiles, len(tiles_z),
                         objects, sum([len(o) for o in objects]),
                         tilemap.orientation)

    # Set the extra map properties for hexagonal/staggered maps
    loaded_map = map_manager.maps[name]
    loaded_map.tile_size = (tilemap.tilewidth, tilemap.tileheight)
    loaded_map.z_index_map = tiles_z + objects_z
    if tilemap.staggerindex:
        loaded_map.stagger_index = tilemap.staggerindex
    if tilemap.staggeraxis:
        loaded_map.stagger_axis = tilemap.staggeraxis
    if tilemap.hexsidelength:
        loaded_map.hex_side_length = tilemap.hexsidelength

    return name


def _load_tilesets(tilesets, dirname, tile_ids,
                   load_atlas, load_model, load_animation):
    '''
    Tileset of the map contains an atlas of the images used by the tiles. We
    need to load all those images as textures and models. If they are animated
    tiles we also load an animation for them.

    The texture, model names are in the format tile_%d where %d is the tile's
    gid. For animation the format is animation_tile_%d.

    Args:
        tilesets (list): List of TileSet objects. We can create an atlas of
        the tile images from TileSet data using the tile_ids.

        dirname (str): Directory of the image source of the tilesets

        tile_ids (list): List of tile ids which need to be loaded from the
        tileset.

        load_atlas (function): Takes an atlas dict and loads textures in the
        texture_manager

        load_model (function): Loads models for all loaded textures in the
        model_manager.

        load_animation (function): Takes frames of an animated tile and loads
        an animation.

    '''
    atlas_data = {}
    model_data = {}
    animation_data = {}
    for tileset in tilesets:
        image = tileset.image
        name = image.source
        fgid = int(tileset.firstgid)
        w, h = int(image.width), int(image.height)
        tw, th = int(tileset.tilewidth), int(tileset.tileheight)
        m, s = int(tileset.margin), int(tileset.spacing)

        rows = (w + s)//(tw + 2*m + s)
        cols = (h + s)//(th + 2*m + s)

        for tile in tileset.tiles:
            if tile.animation:
                animation = []
                for frame in tile.animation:
                    animation.append({
                        'texture': 'tile_%d' % (frame.tileid + fgid),
                        'model': 'tile_%d' % (frame.tileid + fgid),
                        'duration': frame.duration
                    })
                    tile_ids.add(frame.tileid + fgid)
                animation_name = 'animation_tile_%d' % (tile.id + fgid)
                animation_data[animation_name] = animation

        atlas_data[name] = {}
        for tile in range(rows*cols):
            if (tile + fgid) in tile_ids:
                x, y = tile % rows, cols - 1 - int(tile / rows)
                px, py = x * (tw + 2*m + s) + m, y * (th + 2*m + s) + m
                atlas_data[name]['tile_%d' % (tile + fgid)] = (px, py, tw, th)
                model_data['tile_%d' % (tile + fgid)] = (tw, th)

    load_atlas(atlas_data, 'dict', dirname)
    for model in model_data:
        tw, th = model_data[model]
        load_model('vertex_format_4f', tw, th, model, model)
    for animation in animation_data:
        frames = animation_data[animation]
        load_animation(animation, len(frames), frames)


def _load_obj_models(objmodels,
                     load_img_model, load_poly_model):
    '''
    Object models are a list of vertices for a shape or a model for a texture.
    They are read from the map and loaded into model_manager here.

    Args:
        objmodels (list): List of dicts containing model data.

        load_img_model (function): Load model for an image texture.

        load_poly_model (function): Load model from a set of vertices.
    '''
    for objname in objmodels:
        obj = objmodels[objname]
        if 'texture' in obj:
            load_img_model('vertex_format_4f', obj['width'], obj['height'],
                    obj['texture'], objname)
        elif 'vertices' in obj:
            load_poly_model('vertex_format_2f4ub',
                            obj['vertex_count'],
                            obj['index_count'],
                            objname,
                            vertices=obj['vertices'],
                            indices=obj['indices'])


def _load_tile_map(layers, width, tile_properties):
    '''
    Loads data for all the tiles and objects of the tilemap as dicts
    which will directly be passed to map_manager. While looping through all
    tiles and objects it creates the z_index map, stores a unique set of
    tile_ids which will be used so we only load that data and also dicts for
    object models.

    The dicts for object models require generating the vertices of the polygons
    and hence has different math for different types of shapes.

    Args:
        layers (unsigned int): Number of layers to load

        width (unsigned int): Number of columns.

        tile_properties (dict): A map for specific tile properties to be loaded.
        
    '''
    height = int(len(layers[0].tiles)/width)
    tiles = [[[] for j in range(width)] for i in range(height)]
    objects = []
    objmodels = {}
    tile_ids = set()

    tile_layer_count = 0
    tile_zindex = []
    obj_layer_count = 0
    obj_zindex = []

    for i, layer in enumerate(layers):
        layerobjs = []
        if type(layer) == Layer:
            for n, tile in enumerate(layer.tiles):
                if tile.gid > 0:
                    tile_ids.add(tile.gid)
                    if tile.gid in tile_properties:
                        tile = tile_properties[tile.gid]
                    else:
                        tile = {'texture': 'tile_%d' % tile.gid,
                                'model': 'tile_%d' % tile.gid}
                    tile['layer'] = tile_layer_count

                    tiles[int(n/width)][n%width].append(tile)
            tile_layer_count += 1
            tile_zindex.append(i)
        elif type(layer) == ObjectGroup:
            c = layer.color
            color = (c._Color__r, c._Color__g, c._Color__b, 255)
            for n, obj in enumerate(layer.objects):
                if obj.gid:
                    tile_ids.add(obj.gid)
                    gid, width, height = obj.gid, obj.width, obj.height
                    obj = {'texture': 'tile_%d' % gid,
                           'model': 'obj_%d_%d' % (obj_layer_count, n),
                           'position': (obj.x + width/2, obj.y + height/2)}
                    objmodel = {'texture': 'tile_%d' % gid,
                                'width': width,
                                'height': height}
                elif obj.polygon:
                    x_coords = [v[0] for v in obj.polygon]
                    y_coords = [v[1] for v in obj.polygon]

                    w, h = (max(x_coords) - min(x_coords),
                            max(y_coords) - min(y_coords))
                    c = obj.x + w/2, obj.y + h/2

                    vertices = {}
                    indices = []
                    for n, v in enumerate(obj.polygon):
                        vertices[n] = {'pos': (v[0] - w/2, h/2 - v[1]),
                                       'v_color': color}
                        if n>0 and n<len(obj.polygon)-1:
                            indices.extend([0,n,n+1])
                    obj = {'model': 'obj_%d_%d' % (obj_layer_count, n),
                           'position': c}
                    objmodel = {'vertices': vertices,
                                'indices': indices,
                                'vertex_count': len(vertices),
                                'index_count': len(indices)}
                elif obj.ellipse:
                    vertices = {}
                    indices = []

                    a, b = obj.width/2., obj.height/2.
                    for t in range(360):
                        ang = radians(t)
                        v = (a * cos(ang), b * sin(ang))
                        vertices[t] = {'pos': v,
                                       'v_color': color}
                        if t>0 and t<359:
                            indices.extend([0,t,t+1])
                    obj = {'model': 'obj_%d_%d' % (obj_layer_count, n),
                           'position': (obj.x + obj.width/2,
                                        obj.y + obj.height/2),
                          }
                    objmodel = {'vertices': vertices,
                                'indices': indices,
                                'vertex_count': len(vertices),
                                'index_count': len(indices)}
                else:
                    w, h = obj.width, obj.height
                    objmodel = {
                            'vertices': { 0: {'pos': (-w/2., -h/2.),
                                              'v_color': color},
                                          1: {'pos': (-w/2., h/2.),
                                              'v_color': color},
                                          2: {'pos': (w/2., h/2.),
                                              'v_color': color},
                                          3: {'pos': (w/2., -h/2.),
                                              'v_color': color}},
                            'indices': [0, 1, 3, 3, 1, 2],
                            'vertex_count': 4,
                            'index_count': 6
                            }
                    obj = {'model': 'obj_%d_%d' % (obj_layer_count, n),
                           'position': (obj.x + obj.width/2,
                                        obj.y + obj.height/2)}

                name = 'obj_%d_%d' % (obj_layer_count, n)
                objmodels[name] = objmodel
                layerobjs.append(obj)

            objects.append(layerobjs)
            obj_layer_count += 1
            obj_zindex.append(i)

    return tiles, tile_zindex, objects, obj_zindex, tile_ids, objmodels

def _load_tile_properties(tilesets):
    tile_properties = {}
    for tileset in tilesets:
        for tile in tileset.tiles:
            if tile.animation:
                gid = tile.id + tileset.firstgid
                tile_properties[gid] = {
                        'animation':
                            'animation_tile_%d' % gid
                    }

    return tile_properties
