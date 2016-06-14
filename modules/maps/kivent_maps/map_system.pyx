from kivent_core.systems.staticmemgamesystem cimport StaticMemGameSystem, MemComponent
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.gameworld import GameWorld
from kivy.properties import (StringProperty, ObjectProperty, NumericProperty,
        BooleanProperty, ListProperty)
from kivy.factory import Factory
from kivent_maps.map_data cimport TileMap
from kivent_maps.map_manager cimport MapManager


cdef class MapComponent(MemComponent):
    property entity_id:
        def __get__(self):
            cdef MapStruct* data = <MapStruct*>self.pointer
            return data.entity_id

    property pos:
        def __get__(self):
            cdef MapStruct* data = <MapStruct*>self.pointer
            return (data.pos_x, data.pos_y)

        def __set__(self, list value):
            cdef MapStruct* data = <MapStruct*>self.pointer
            data.pos_x = value[0]
            data.pos_y = value[1]

cdef class MapSystem(StaticMemGameSystem):

    system_id = StringProperty('tile_map')
    processor = BooleanProperty(True)
    updataeble = BooleanProperty(False)
    type_size = NumericProperty(sizeof(MapStruct))
    component_type = ObjectProperty(MapComponent)
    system_names = ListProperty(['tile_map','renderer'])
    gameworld = ObjectProperty(None)

    def on_gameworld(self, instance, value):
        print "Yay"

        model_manager = self.gameworld.managers["model_manager"]
        map_manager = MapManager(model_manager)
        self.gameworld.register_manager("map_manager", map_manager)

    def init_component(self, unsigned int component_index,
                       unsigned int entity_id, str zone, args):
        model_manager = self.gameworld.managers["model_manager"]
        map_manager = self.gameworld.managers["map_manager"]

        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef MapStruct* component = <MapStruct*>(
                memory_zone.get_pointer(component_index))
        cdef TileMap tile_map = map_manager.maps[args['name']]

        component.entity_id = entity_id
        component.tile_map = <void*>tile_map
        component.pos_x = args['pos'][0]
        component.pos_y = args['pos'][1]


Factory.register('MapSystem', cls=MapSystem)
