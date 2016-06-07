from kivent_core.managers.resource_managers cimport ModelManager
from kivent_core.managers.game_manager cimport GameManager
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_maps.map_data cimport TileMap


cdef class MapManager(GameManager):
    '''
    Manages memory allocation and assigment of maps
    '''

    def __init__(self, ModelManager model_manager, allocation_size=1024*10):
        self.model_manager = model_manager
        self.allocation_size = allocation_size
        self._maps = {}

    def allocate(self, MemoryBlock master_buffer, gameworld):
        cdef MemoryBlock memory_block = MemoryBlock(self.allocation_size, 1, 1)
        memory_block.allocate_memory_with_buffer(master_buffer)
        self.memory_block = memory_block

        return self.allocation_size

    def load_map(self, name, map_size, tile_size, tiles=None):
        cdef TileMap tile_map = TileMap(map_size, tile_size, self.memory_block, self.model_manager, name)

        if tiles:
            tile_map.tiles = tiles
        self._maps[name] = tile_map
