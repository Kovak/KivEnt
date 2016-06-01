from kivent_core.managers.resource_managers cimport ModelManager
from kivent_core.memory_handlers.block cimport MemoryBlock


ctypedef struct TileTextureStruct:
    int texkey
    void* model

ctypedef struct TileStruct:
    void* tile_texture
    int x
    int y

cdef class TileTexture:
    cdef TileTextureStruct* texture_pointer
    cdef ModelManager model_manager

cdef class Tile:
    cdef TileStruct* tile_pointer

cdef class TileMap:
    cdef MemoryBlock tiles_block
    cdef str name
    cdef unsigned int size_x
    cdef unsigned int size_y
    cdef unsigned int tile_size
