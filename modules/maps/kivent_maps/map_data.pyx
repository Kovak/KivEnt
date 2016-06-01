from kivent_core.rendering.model cimport VertexModel
from kivent_core.managers.resource_managers import texture_manager
from kivent_core.memory_handlers.block cimport MemoryBlock


cdef class TileTexture:
    '''
    TileTexture stores the model and texture data for a tile texture
    '''

    def __cinit__(self, ModelManager model_manager):
        self.model_manager = model_manager

    property model:
        def __get__(self):
            cdef VertexModel model = <VertexModel>self.texture_pointer.model
            return model.name

        def __set__(self, value):
            self.texture_pointer.model = <void*>self.model_manager.models[value]

    property texture:
        def __get__(self):
            return texture_manager.get_texname_from_texkey(self.texture_pointer.texkey)

        def __set__(self, value):
            self.texture_pointer.texkey = texture_manager.get_texkey_from_name(value)


cdef class Tile:
    '''
    Tile represents data for a tile on the map - position and texture
    '''

    property pos:
        def __get__(self):
            return (self.tile_pointer.x, self.tile_pointer.y)

        def __set__(self, pos):
            self.tile_pointer.x = pos[0]
            self.tile_pointer.y = pos[1]

cdef class TileMap:
    '''
    TileMap stores tiles for all positions
    '''

    def  __cinit__(self, map_size, tile_size, tile_buffer, model_manager, name):
        self.size_x = map_size[0]
        self.size_y = map_size[1]
        self.tile_size = tile_size
        self.model_manager = model_manager
        self.name = name.encode('utf-8')

        cdef MemoryBlock tiles_block = MemoryBlock(
            map_size[0]*map_size[1]*sizeof(TileStruct), sizeof(TileStruct), 1)
        tiles_block.allocate_memory_with_buffer(tile_buffer)
        self.tiles_block = tiles_block

    def __dealloc__(self):
        if self.tiles_block is not None:
            self.tiles_block.remove_from_buffer()
            self.tiles_block = None
        self.model_manager = None

    def get_tile(self, unsigned int x, unsigned int y):
        if x >= self.size_x and y >= self.size_y:
            raise IndexError()

        cdef Tile tile = Tile()
        tile.tile_pointer = <TileStruct*>self.tiles_block.get_pointer(x*self.size_x + y)
        return tile

    def free_memory(self):
        if self.tiles_block is not None:
            self.tiles_block.remove_from_buffer()
            self.tiles_block = None

    property tiles:
        def __get__(self):
            tile_list = []
            for i in range(self.size_x):
                tile_row = []
                for j in range(self.size_y):
                    tile_row.append(self.get_tile(i,j))
                tile_list.append(tile_row)

        def __set__(self, list tiles):
            cdef unsigned int size_x = len(tiles)
            cdef unsigned int size_y = len(tiles[0])

            if size_x != self.size_x or size_y != self.size_y:
                raise Exception("Provided tiles list does not match internal size")
            for i in range(size_x):
                for j in range(size_y):
                    tile = self.get_tile(i,j)
                    data = tiles[i][j]
                    tile.pos = (i, j)
                    tile.texture = data['texture']
                    tile.model = data['model']

    property size:
        def __get__(self):
            return (self.size_x, self.size_y)

    property size_on_screen:
        def __get__(self):
            return (self.size_x * self.tile_size, self.size_y * self.tile_size)
