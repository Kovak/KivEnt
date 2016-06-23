# cython: embedsignature=True
import json
from os import path
from kivy.core.image import Image as CoreImage
from kivent_core.rendering.model cimport VertexModel, Vertex
from kivent_core.rendering.vertex_formats cimport format_registrar, FormatConfig
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivy.logger import Logger
try:
    import cPickle as pickle
except:
    import pickle
from kivent_core.rendering.svg_loader cimport SVG, SVGModelInfo
from kivent_core.managers.game_manager cimport GameManager

cdef class ModelManager(GameManager):
    '''
    The ModelManager is responsible for managing all VertexModel that will be
    used during your game's rendering. A model is a collection of vertex and
    index data describing the triangles that make up your entities geometry.]

    The ModelManager ensures that all models using the same vertex format are
    stored contiguously, helping to ensure that your rendering does not have to
    jump around so much in memory.

    If you do not provide custom instructions to the allocation function,
    the ModelManager will register 100 KiB for each format found in the
    rendering.vertex_formats.format_registrar. The memory will be split 72/25
    vertices to indices.

    Remember every entity that uses a model of the same name will share all
    of that vertex data and modifying ones model will modify all. There is
    copying functionality built into the loading functions in case you want to
    create unique models per entity.

    **Attributes:**
        **models** (dict): A dict of all the loaded models, keyed by name.

        **key_counts** (dict): The count of the number of copies made of a
        certain model. Used internally if we are constructing a copy of an
        already loaded model.

        **model_register** (dict): Used to keep track of the entities actively
        using this model. Keyed by model_name will be dicts of key = entity_id,
        value = system_id of renderer for that entity. If you want to modify
        a model attached to many entities, use the model_register to find out
        which entities are actively using that model.

    **Attributes: (Cython Access Only)**
        **allocation_size** (unsigned int): Set during initalization of the
        ModelManager, this is the amount of space to be reserved for each
        vertex format if an empty formats_to_allocate dict is provided to
        **allocate**. The space will be split 75/25 for vertices/indices.

        **memory_blocks** (dict): A dict of dicts. Each format that gets
        allocated will have an entry here, that is a dict containing keys:
        'vertices_block' and 'indices_block'. Models for that format will be
        allocated inside these MemoryBlock.

    '''

    def __init__(self, allocation_size=100*1024):
        self.allocation_size = allocation_size
        self.memory_blocks = {}
        self._models = {}
        self._key_counts = {}
        self._model_register = {}
        self._svg_index = {}

    property svg_index:
        def __get__(self):
            return self._svg_index

    property models:
        def __get__(self):
            return self._models

    property key_counts:
        def __get__(self):
            return self._key_counts

    property model_register:
        def __get__(self):
            return self._model_register


    def register_entity_with_model(self, unsigned int entity_id, str system_id,
        str model_name):
        '''
        Used to register entities that are using a certain model. Typically
        called internally as part of Renderer.init_component or the logic
        associated with setting a RenderComponent.model.

        Note: At the moment you should not register the same model on the same
        entity with multiple renderers. This is not handled. Although I'm not
        quite certain when you would do that.

        Args:
            entity_id (unsigned int): Id of the entity being registered.

            system_id (str): system_id of the Renderer that this entity is
            attached to with the model.

            model_name (str): Name of the model to register the entity_id with.

        '''
        if model_name not in self._model_register:
            self._model_register[model_name] = {entity_id: system_id}
        else:
            self._model_register[model_name][entity_id] = system_id

    def unregister_entity_with_model(self, unsigned int entity_id,
        str model_name):
        '''
        Unregisters a previously registered entity.

        Args:
            entity_id (unsigned int): The id of the entity being registered.

            model_name (str): The name of the model that entity was registered
            with.
        '''
        del self._model_register[model_name][entity_id]

    def pickle_model(self, str model_name, str directory_name):
        '''
        Saves a model to disk using Pickle. Data will be stored as a
        dictionary containing keys 'vertices', 'indices', and 'format_name'.

        The name of the file will be os.path.join(directory_name,
        model_name + '.kem').

        Args:
            model_name (str): The name of the model to save.

            directory_name (str): The directory where you want to save the
            model.

        '''
        cdef VertexModel model = self._models[model_name]
        cdef list indices = model.indices
        cdef list vertices = model.vertices
        cdef dict vert_dict = {}
        cdef FormatConfig format_config = model._format_config
        cdef dict format_dict = format_config._format_dict
        cdef Vertex vert
        for index, vert in enumerate(vertices):
            vert_dict[index] = vert_data = {}
            for key in format_dict:
                vert_data[key] = getattr(vert, key)
        save_dict = {
            'vertices': vert_dict,
            'indices': indices,
            'format_name': format_config._name
        }
        output = open(path.join(directory_name, model_name + '.kem'), 'wb')
        pickle.dump(save_dict, output)
        output.close()

    def load_model_from_pickle(self, str file_to_load, str model_name=None):
        '''
        Loads a previously pickled model.

        Args:
            file_to_load (str): Name of the file to load.

        '''
        if model_name is None:
            model_name = path.splitext(path.basename(file_to_load))[0]
        pkl_file = open(file_to_load, 'rb')
        data = pickle.load(pkl_file)
        format_name = data['format_name']
        indices = data['indices']
        index_count = len(indices)
        vertices = data['vertices']
        vertex_count = max(vertices) + 1
        pkl_file.close()
        return self.load_model(format_name, vertex_count, index_count,
            model_name, indices=indices, vertices=vertices)

    def allocate(self, master_buffer, gameworld):
        '''
        Allocates space for loading models. Typically called as part of
        Gameworld.allocate.


        Args:
            master_buffer (Buffer): The buffer to do allocation from.
            gameworld (GameWorld):

        Return:
            unsigned int: Number of bytes actually used by the ModelManager

        '''
        #Either for each format in formats to allocate, or use default behavior
        #Load 10 mb of space for each registered vertex format.
        #(index space, vertex_space) for val at format_name key.
        #         If you pass in a dict keyed by the name of registered vertex_formats
        # with a tuple value of (bytes for vertex data, bytes for index data)
        # you can control the formats loaded and the data loaded. If you do not
        # provide instructions, every registered vertex format will have
        # 75 KiB allocated for vertex data and 25 KiB for index data by default.
        # This default allocation can be controlled by **allocation_size**
        # if set before initalization.


        cdef FormatConfig format_config
        for each in format_registrar._vertex_formats:
            format_config = format_registrar._vertex_formats[each]
            Logger.info('KivEnt: Vertex Format: {name} registered. Size per '
                'vertex is: {size}. Format is {format}.'.format(
                name=format_config._name,
                size=str(format_config._size),
                format=format_config._format))

        formats_to_allocate = gameworld.model_format_allocations
        cdef MemoryBlock indices_block
        cdef MemoryBlock vertices_block
        vertex_formats = format_registrar._vertex_formats
        cdef dict memory_blocks = self.memory_blocks
        cdef unsigned int total_count = 0
        if formats_to_allocate == {}:
            for key in vertex_formats:
                formats_to_allocate[key] = (
                    self.allocation_size - self.allocation_size // 4,
                    self.allocation_size // 4)
        for format in formats_to_allocate:
            vertex_size, index_size = formats_to_allocate[format]
            format_config = vertex_formats[format]
            indices_block = MemoryBlock(index_size, 1, 1)
            vertices_block = MemoryBlock(vertex_size, 1, 1)
            vertices_block.allocate_memory_with_buffer(master_buffer)
            indices_block.allocate_memory_with_buffer(master_buffer)
            memory_blocks[format] = {'indices_block': indices_block,
                'vertices_block': vertices_block}
            total_count += vertex_size + index_size
            Logger.info('KivEnt: Model Manager reserved space for vertex '
                'format: {name}. {space} KiB was reserved for vertices, '
                'fitting a total of {vert_count}. {ind_space} KiB was reserved '
                'for indices fitting a total of {ind_count}.'.format(
                name=format,
                space=str(vertex_size//1024),
                vert_count=str(vertex_size//format_config._size),
                ind_space=str(index_size//1024),
                ind_count=str(index_size//sizeof(unsigned short)),))
        return total_count

    def load_model_from_model_info(self, SVGModelInfo info, str svg_name):
        '''
        Turns the data in a SVGModelInfo to an actual Model for use in 
        your game. 

        Args:

            info (SVGModelInfo): The data for the model you want to load.

            svg_name (str): The name of the svg file, previously returned by 
            **get_model_info_for_svg**.

        Return:
            str: The key this model is registered under. Will be svg_name + '_'
            + element_id for the SVGModelInfo.

        '''
        model_key = self.load_model(
            'vertex_format_2f4ub', info.vertex_count, 
            info.index_count, svg_name + '_' + info.element_id,
            indices=info.indices, vertices=info.vertices,
            )
        self._svg_index[svg_name][info.element_id] = model_key
        return model_key

    def combine_model_infos(self, list infos):
        '''
        Takes a list of SVGModelInfo objects and combines them into the 
        minimum number of models that will fit that data. Each model will 
        be no more than 65535 vertices, as this is the limit to number of 
        vertices in a single model in ES2.0. 

        Args:
            infos (list): List of SVGModelInfo to combine.

        Return:
            list: New list of SVGModelInfo combined into the minimum number
            necessary to display the data.

        '''
        current_info = None
        final_infos = []
        while len(infos) > 0:
            new_info = infos.pop(0)
            if current_info is None:
                current_info = new_info
            elif current_info.vertex_count + new_info.vertex_count < 65535:
                current_info = current_info.combine_model_info(new_info)
            else:
                final_infos.append(current_info)
                current_info = new_info
        else:
            final_infos.append(current_info)
        return final_infos

    def get_center_and_bbox_from_infos(self, list infos):
        '''
        Gets the bounding box and center info for the provided list of 
        SVGModelInfo.

        Args:
            infos (list): List of SVGModelInfo to find the bounding box
            and center for.

        Return:
            dict: with keys 'center' and 'bbox'. center is a 2-tuple of 
            center_x, center_y coordinates. bbox is a 4-tuple of leftmost x,
            bottom y, rightmost x, top y.
            
        '''
        cdef float top, left, right, bot, x, y
        initial_pos = infos[0].vertices[0]['pos']
        top = bot = initial_pos[1]
        left = right = initial_pos[0]
        cdef SVGModelInfo info
        for info in infos:
            for i in range(info.vertex_count):
                vertex = info.vertices[i]
                x, y = vertex['pos']
                if x < left:
                    left = x
                elif x > right:
                    right = x
                if y < bot:
                    bot = y
                elif y > top:
                    top = y
        bot_left = (bot, left)
        top_left = (top, left)
        bot_right = (bot, right)
        top_right = (top, right)
        center_y = bot + (top - bot) / 2.
        center_x = left + (right - left) / 2.
        return {'center': (center_x, center_y),
                'bbox': (left, bot, right, top)}

    def get_model_info_for_svg(self, str source, str svg_name=None):
        '''
        Returns the SVGModelInfo objects representing the elements in an 
        svg file. You can then parse this data depending on your needs 
        before loading the final assets. Use **load_model_from_model_info**
        to load your assets.
        '''
        if svg_name is None:
            svg_name = str(path.splitext(path.basename(source))[0])
        if svg_name in self._svg_index:
            raise KeyError()
        self._svg_index[svg_name] = {}
        cdef SVG svg = SVG(source)
        cdef list svg_data = svg.get_model_data()
        return {'model_info': svg_data, 'svg_name': svg_name}

    def load_model(self, str format_name, unsigned int vertex_count,
        unsigned int index_count, str name, do_copy=False, indices=None,
        vertices=None):
        '''
        Loads a new VertexModel, and allocates space in the MemoryBlock for its
        vertex format to hold the model. The model will be stored in the
        **models** dict.

        Load model does not fill your model with any data you should do that
        after creating it. Either by accessing the vertices yourself or through
        a function such as **copy_model** or **load_textured_rectangle**.

        The kwarg do_copy controls the behavior of the loaded. By default if we
        find a model has already been loaded under **name**, we simply return
        that already loaded model's name. If do_copy is set to True we will
        actually create a new model that appends an underscore and number to
        the name provide. For instance, 'test_model' becomes 'test_model_0',
        and then 'test_model_1' and so on. Copying 'test_model_0' will create
        'test_model_0_0'.

        Args:
            format_name (str): The name of the vertex format this model should
            be created with.

            vertex_count (unsigned int): The number of vertices in the model.

            index_count (unsigned int): The number of indices for the model.

            name (str): The name to store the model under.

        Kwargs:
            do_copy (bool): Defaults False, determines whether to copy the model
            if we find one with its name is already loaded.

            indices (list): If a list of indices is provided, the data will be
            loaded into your model. Make sure the len(indices) ==
            **index_count**.

            vertices (dict): Vertex data can be supplied in the form of a
            dictionary containing key is the index of vertex, and the value at
            the key is a dict with key vertex attribute,
            value at that attribute.

            For instance:

            .. code-block:: python

                vertices = {
                    1: {'pos': (-5., -5.), uvs: (0., 0.)},
                    2: {'pos': (-5., 5.), uvs: (0., 1.)},
                    3: {'pos': (5., 5.), uvs: (1., 1.)},
                    4: {'pos': (5., -5.), uvs: (1., 0.)},
                }

        Return:
            str: Returns the actual name the model has been stored under.

        '''
        vertex_formats = format_registrar._vertex_formats
        cdef FormatConfig format_config = vertex_formats[format_name]
        if name not in self._key_counts:
            self._key_counts[name] = 0
        elif name in self._key_counts and not do_copy:
            return name
        elif name in self._key_counts and do_copy:
            old_name = name
            name = name + '_' + str(self._key_counts[name])
            self._key_counts[old_name] += 1
            self._key_counts[name] = 0
        cdef MemoryBlock vertex_block = self.memory_blocks[format_name][
            'vertices_block']
        cdef MemoryBlock index_block = self.memory_blocks[format_name][
            'indices_block']
        cdef VertexModel model = VertexModel(vertex_count, index_count,
            format_config, index_block, vertex_block, name)
        self._models[name] = model
        if vertices is not None:
            model.vertices = vertices
        if indices is not None:
            model.indices = indices
        return name

    def copy_model(self, str model_to_copy, str model_name=None):
        '''
        Copies an existing model, creating a new model with the same data. If
        you set the model_name kwarg the new model will be stored under this
        name, otherwise the name of model being copied will be used, with
        do_copy set to True for **load_model**.

        Args:
            model_to_copy (str): The name of the model to copy.

        Kwargs:
            model_name (str): The name to store the new model under. If None
            the model_to_copy name will be used.

        Return:
            str: Actual name of the copied model.

        '''
        cdef VertexModel copy_model = self._models[model_to_copy]
        cdef str format_name = copy_model._format_config._name
        if model_name is None:
            model_name = model_to_copy
        real_name = self.load_model(format_name, copy_model._vertex_count,
            copy_model._index_count, model_name, do_copy=True)
        self._models[real_name].copy_vertex_model(copy_model)
        return real_name

    def load_textured_rectangle(self, str format_name, float width,
        float height, str texture_key, str name, do_copy=False):
        '''
        Loads a new model and sets it to be a textured quad (sprite).
        vertex_count will be set to 4, index_count to 6 with indices set to
        [0, 1, 2, 2, 3, 0].

        The uvs from **texture_key** will be used.

        Args:
            format_name (str): Name of the vertex format to use.

            width (float): Width of the quad.

            height (float): Height of the quad.

            texture_key (str): Name of the texture to use.

            name (str): Name to load the model under.

        Kwargs:
            do_copy (bool): Defaults False. Kwarg forwarded to load_model,
            controls whether we will copy the model if name is laready in use.

        Return:
            str: Actual name of the loaded model.

        '''
        model_name = self.load_model(format_name, 4, 6, name, do_copy=do_copy)
        cdef VertexModel model = self._models[model_name]
        texkey = texture_manager.get_texkey_from_name(texture_key)
        uvs = texture_manager.get_uvs(texkey)
        model.set_textured_rectangle(width, height, uvs)
        return model_name

    def unload_model(self, str model_name):
        '''
        Unloads the model. Freeing it for GC. Make sure you have not kept
        any references to your model yourself.

        Args:
            model_name (str): Name of the model to unload.

        '''
        cdef VertexModel model = self._models[model_name]
        model.free_memory()
        del self._models[model_name]
        if model_name in self._model_register:
            del self._model_register[model_name]
        if model_name in self._key_counts:
            del self._key_counts[model_name]


cdef class TextureManager(GameManager):
    '''
    The TextureManager handles the loading of all image resources into our
    game engine. Use **load_image** for image files and **load_atlas** for
    .atlas files. Do not load 2 images with the same name even in different
    atlas files. Prefer to access kivent.renderers.texture_manager than
    making your own instance.
    '''

    def __init__(self):
        #maps texkey to textures
        self._textures = {}
        #maps string names to texkeys
        self._keys = {}
        #maps texkey to string names
        self._key_index = {}
        #maps texkey to actual texture key (for atlas)
        self._texkey_index = {}
        self._key_count = 0
        #map texkey to w, h of texture
        self._sizes = {}
        #maps texkey to list of uvs
        self._uvs = {}
        #maps actual texture key to all subtexture texkey (for atlas)
        self._groups = {}

    property loaded_textures:
        def __get__(self):
            return [key for key in self._keys]

    def load_image(self, source):
        texture = CoreImage(source, nocache=True).texture
        name = path.splitext(path.basename(source))[0]
        name = str(name)
        if name in self._keys:
            raise KeyError()
        else:
            key_count = self._key_count
            size = texture.size
            self._textures[key_count] = texture
            self._keys[name] = key_count
            self._sizes[key_count] = size
            self._key_index[key_count] = name
            self._texkey_index[key_count] = key_count
            self._uvs[key_count] = [0., 0., 1., 1.]
            self._groups[key_count] = [key_count]
            self._key_count += 1
        return key_count

    def load_texture(self, name, texture):
        name = str(name)
        if name in self._keys:
            raise KeyError()
        else:
            key_count = self._key_count
            self._textures[key_count] = texture
            size = texture.size
            self._sizes[key_count] = size
            self._keys[name] = key_count
            self._key_index[key_count] = name
            self._texkey_index[key_count] = key_count
            self._uvs[key_count] = [0., 0., 1., 1.]
            self._groups[key_count] = [key_count]
            self._key_count += 1
        return key_count

    def unload_texture(self, name):
        if name not in self._keys:
            raise KeyError()
        else:
            key_index = self._keys[name]
            texture_keys = self._groups[key_index]
            for key in texture_keys:
                name = self._key_index[key]
                del self._key_index[key]
                del self._uvs[key]
                del self._texkey_index[key]
                del self._keys[name]
                del self._sizes[key]
            del self._groups[key_index]
            del self._textures[key_index]

    def get_texkey_from_name(self, name):
        return self._keys[name]

    def get_uvs(self, tex_key):
        return self._uvs[tex_key]

    def get_size(self, tex_key):
        return self._sizes[tex_key]

    def get_size_by_name(self, name):
        return self._sizes[self._keys[name]]

    def get_texture(self, tex_key):
        #handles if batch has no texture
        if tex_key == <unsigned int>-1:
            return None
        return self._textures[tex_key]

    def get_texture_by_name(self, name):
        tex_key = self._keys[name]
        if tex_key == <unsigned int>-1:
            return None
        return self._textures[tex_key]

    def get_groupkey_from_texkey(self, tex_key):
        #handles if entity has no texture
        if tex_key == <unsigned int>-1:
            return tex_key
        else:
            return self._texkey_index[tex_key]

    def get_texname_from_texkey(self, tex_key):
        return self._key_index[tex_key]

    def get_texkey_in_group(self, tex_key, group_key):
        return tex_key in self._groups[group_key]

    def load_atlas(self, source, datatype='json', dirname=None):
        if datatype == 'json':
            dirname = path.dirname(source)
            with open(source, 'r') as data:
                 atlas_data = json.load(data)
        elif datatype == 'dict':
            atlas_data = source
        keys = self._keys
        uvs = self._uvs
        for imgname in atlas_data:
            texture = CoreImage(
                path.join(dirname,imgname), nocache=True).texture
            name = str(path.basename(imgname))
            size = texture.size
            w = <float>size[0]
            h = <float>size[1]
            atlas_content = atlas_data[imgname]
            atlas_key = self.load_texture(name, texture)
            group_list = self._groups[atlas_key]
            group_list_a = group_list.append
            for key in atlas_content:
                key = str(key)
                kx,ky,kw,kh = atlas_content[key]
                key_index = self._key_count
                self._keys[key] = key_index
                self._key_index[key_index] = key
                self._texkey_index[key_index] = atlas_key
                self._sizes[key_index] = kw, kh
                x1, y1 = kx, ky
                x2, y2 = x1 + kw, y1 + kh
                self._uvs[key_index] = [x1/w, 1.-y1/h, x2/w, 1.-y2/h]
                self._key_count += 1
                group_list_a(key_index)

texture_manager = TextureManager()
