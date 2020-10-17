# cython: embedsignature=True
from kivy.logger import Logger

from kivent_core.managers.game_manager cimport GameManager
'''
GameWorld uses these system management classes to keep track of the GameSystems
attached to it, their indexes in the EntityManager memory, and the
configuration of each of the systems IndexedMemoryZone.
'''
cdef unsigned int DEFAULT_SYSTEM_COUNT = 8
cdef unsigned int DEFAULT_COUNT = 10000

cdef class ZoneConfig:
    '''Stores the configuration information for a zone in the GameWorld's
    GameSystems.

    **Attributes: (Cython Access Only)**
        **count** (unsigned int): Number of entities in this zone.

        **zone_name** (str): Name of the zone.

        **systems** (list): List of the names of the GameSystem that will
        reserve space for this zone.
    '''

    def __cinit__(self, str name, unsigned int count):
        '''When initialized the ZoneConfig will have no GameSystem's attached.
        The **systems** attribute will be initialized to []. Systems should be
        added to the zone through the use of the SystemConfig object.

        Args:
            name (str): The name of the zone.

            count (unsigned int): The number of entities to be stored in the
            zone.
        '''
        self.count = count
        self.zone_name = name
        self.systems = []

class ZoneAlreadyAddedError(Exception):
    pass

class SystemAlreadyAddedError(Exception):
    pass

cdef class SystemConfig:
    '''Organizes the ZoneConfigs for a GameWorld. Responsible for adding
    new zones to the GameWorld and adding systems to those zones.

    **Attributes: (Cython Access Only)**
        **zone_configs** (dict): Hashmap of ZoneConfig objects stored by
        keys of the zone_name (str).
    '''

    def __cinit__(self):
        self.zone_configs = {}

    def get_config_dict(self, system_name):
        '''Returns the config_dict for a specific system_name. This will be
        a dictionary of zone_name, zone_count pairings. If the default zone,
        'general', is not registered with the Zone it will be inserted
        automatically with a DEFAULT_COUNT.

        Args:
            system_name (str): Name of the system to get the config dict for.

        Return:
            config_dict (dict): zone_name, zone_count hashmap that includes
            all the zones that should be allocated for the given system.
        '''
        cdef ZoneConfig zone_config
        cdef dict zone_configs = self.zone_configs
        cdef config_dict = {}
        for config_name in zone_configs:
            zone_config = zone_configs[config_name]
            if system_name in zone_config.systems:
                if zone_config.zone_name not in config_dict:
                    config_dict[zone_config.zone_name] = zone_config.count
        return config_dict

    def add_system_to_zone(self, system_name, zone_name):
        '''Adds a system to the zone specified. An already added system cannot
        be added again (will raise a SystemAlreadyAddedError).
        Args:
            system_name (str): The name of the system to add to the zone.

            zone_name (str): The name of the zone.
        '''
        cdef ZoneConfig config = self.zone_configs[zone_name]
        cdef list systems = config.systems
        if system_name in systems:
            raise SystemAlreadyAddedError('The system {name} has already been'
                'added to zone {zone_name}'.format(name=system_name,
                    zone_name=zone_name))
        systems.append(system_name)

    def add_zone(self, zone_name, count):
        '''Creates a new ZoneConfig object and adds it to the **zone_configs**
        dictionary. A ZoneAlreadyAddedError will be raised if the zone_name
        has been previously used.
        Args:
            zone_name (str): The name of the zone to add.

            count (int): The number of entities the zone will contain.
        '''
        if zone_name in self.zone_configs:
            raise ZoneAlreadyAddedError('The zone {name} has already been'
                'added'.format(name=zone_name))
        self.zone_configs[zone_name] = ZoneConfig(zone_name, count)


class TooManySystemsError(Exception):
    pass

cdef class SystemManager(GameManager):
    '''Manages the GameSystems attached to the GameWorld as well as the zone
    configuration for systems which use the IndexedMemoryZone for holding
    entity data. Supports dictionary style key access of systems directly.
    There are two types of GameSystem in KivEnt, systems with components, and
    systems without. The GameWorld will reserve **system_count** spaces for
    components for each Entity, meaning that we cannot have more than
    **system_count** number of GameSystems that expect to attach components.
    This value will typically be set with **set_system_count** as part of
    GameWorld initialization. If **set_system_count** is not called,
    system_count will be system_manager.DEFAULT_SYSTEM_COUNT. Component systems
    will take up the first N spaces in the systems list, with non-component
    systems appearing afterwards. There is no limit to the number of
    non-component GameSystem.

    **Attributes: (Cython Acces Only)**
        **systems** (list): List of the currently active systems, unused
        slots will have a value of None.

        **system_index** (dict): Maps the name of the systems to their index
        in the systems list, which corresponds to the component index in the
        gameworld.entities IndexedMemoryZone.

        **system_config** (SystemConfig): Manages the zone counts for each
        GameSystem that makes use of the IndexedMemoryZone.

        **system_count** (unsigned int): The number of component systems
        with space reserved in the gameworld.entities IndexedMemoryZone.

        **current_count** (unsigned int): The number of component systems
        currently in use.

        **free_indices** (list): List used internally to track component system
        slots that have had their system removed and are available for reuse.

        **first_non_component_index** (unsigned int): Start of the non-component
        systems in the systems list.

        **free_non_component_indices** (list): List used internally to track
        slots for systems that have been removed that do not use components.

        **update_order** (list): *Accessible from Python*. Provides a list of
        indices that dictate the order the GameWorld should update the systems
        in. When setting provide the system_name and internally the appropriate
        index will be found. From cython you can work directly with the
        **_update_order** attribute.
    '''

    def __getitem__(self, str name):
        try:
            return self.systems[self.get_system_index(name)]
        except IndexError:
            raise KeyError(name)

    property update_order:
        def __get__(self):
            return self._update_order

        def __set__(self, list new_order):
            self._update_order = [self.get_system_index(x) for x in new_order]

    def __cinit__(self):
        self.systems = []
        self.system_count = DEFAULT_SYSTEM_COUNT
        self.current_count = 0
        self.free_indices = []
        self.free_non_component_indices = []
        self.first_non_component_index = DEFAULT_SYSTEM_COUNT
        self.system_index = {}
        self.initialized = 0
        self._update_order = []
        self.system_config = SystemConfig()

    def add_zone(self, zone_name, count):
        '''Adds a new zone to the **system_config**.
        Args:
            zone_name (str): Name of the zone to be added.

            count (unsigned int): Number of entities to add.
        '''
        self.system_config.add_zone(zone_name, count)

    cdef unsigned int get_system_index(self, str system_name):
        '''Cython typed function for retrieving the system_index from the
        system_name. Only usable from Cython.
        Args:
            system_name (str): Name of the system.

        Return:
            system_index (unsigned int): Index of the system in the **systems**
            list.
        '''
        try:
            return self.system_index[system_name]
        except KeyError:
            return -1

    def allocate(self, master_buffer, gameworld):
        """
        Args:
            master_buffer (Buffer): The buffer from which the space for the
            entity IndexedMemoryZone will be allocated.

            gameworld (GameWorld): The GameWorld for your application.

        """
        system_count = gameworld.system_count
        if system_count is None:
            system_count = gameworld._system_count
        self.set_system_count(system_count)
        for each in gameworld.systems_to_add:
            self.add_system(each.system_id, each)
        gameworld.systems_to_add = None
        return 0

    def set_system_count(self, unsigned int system_count):
        '''Set the system_count, which is the number of systems that will
        have space allocated for containing components in the gameworld.entities
        IndexedMemoryZone. Should be set as part of GameWorld.allocate.
        Args:
            system_count (unsigned int): Number of systems to reserve space
            for components.
        '''
        self.system_count = system_count
        self.first_non_component_index = system_count
        self.systems = [None for x in range(system_count)]
        self.initialized = 1

    def add_system(self, system_name, system):
        '''Adds a new system to the manager. If the system have do_components
        is True, **current_count** will need to be less than **system_count**
        or a TooManySystemsError will be raised. There is no limit to number
        of GameSystem that do not do_components. By default the system will be
        added to the end of the **update_order**. If you wish to change the
        order in which systems are updated set the **update_order** manually
        after adding all systems.

        Args:
            system_name (str): The name of the system being added.

            system (GameSystem): Reference to the actual system being added.
        '''
        if system.do_components == False:
            if len(self.free_non_component_indices) > 0:
                index = self.free_non_component_indices.pop(0)
                self.systems[index] = system
            else:
                index = self.first_non_component_index
                self.systems.append(system)
                self.first_non_component_index += 1
            self.system_index[system_name] = index
            self._update_order.append(index)

        else:
            free_count = len(self.free_indices)
            if free_count == 0 and not self.current_count < self.system_count:
                raise TooManySystemsError('''More systems with components than
                    allocated for, raise system_count in GameWorld or reduce
                    active GameSystem with do_components = True''')
            else:
                if free_count > 0:
                    index = self.free_indices.pop(0)
                else:
                    index = self.current_count
                    self.current_count += 1
                self.systems[index] = system
                system.system_index = index
                self.system_index[system_name] = index
                self._update_order.append(index)

    def get_system_config_dict(self, system_name):
        '''Gets the config dict for a specific system_name from
        **system_config**, which is a zone_name, zone_count pairing for each
        zone that system will allocate.
        Args:
            system_name (str): Name of the system to get the config_dict for
        Return:
            config_dict (dict): zone_name, zone_count pairing for the system.
        '''
        return self.system_config.get_config_dict(system_name)

    def remove_system(self, system_name):
        '''Removes an existing system from the system_manager.
        Args:
            system_name (str): Name of the system to removed
        '''
        cdef unsigned int system_index = self.get_system_index(system_name)
        self.systems[system_index] = None
        if system_index < self.system_count:
            self.free_indices.append(system_index)
        else:
            self.free_non_component_indices.append(system_index)
        self._update_order.remove(system_index)
        del self.system_index[system_name]

    def configure_system_allocation(self, system_name):
        '''Configures a GameSystem with the **system_config** using the
        GameSystem.zones list property. The GameSystem will be registered to
        use all zones who have their name listed in zones. This should be called
        during GameWorld.allocate after SystemManager.add_system has been
        called.
        Args:
            system_name (str): name of the system to be configured
        '''
        system = self[system_name]
        zones = system.zones
        cdef SystemConfig system_config = self.system_config
        for zone in zones:
            system_config.add_system_to_zone(system_name, zone)
