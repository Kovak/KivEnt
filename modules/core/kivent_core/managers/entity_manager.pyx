# cython: embedsignature=True
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from kivent_core.entity cimport Entity
from kivent_core.managers.game_manager cimport GameManager

cdef class EntityManager(GameManager):
    '''
    The EntityManager will keep track of the entities in your GameWorld.
    An Entity is technically nothing more than an entry in an array of
    unsigned int. The entity is made up of system_count + 1 entries.
    The first entry is the actual identity of the entity, if it is inactive
    this will be <unsigned int>-1.
    The rest of the entries will correspond to the components of your
    GameSystem with do_components set to True. When a component is active its
    id will be stored here, if it is inactive the entry will be
    <unsigned int>-1.

    This means technically there is a limit to the number of components and
    entities you can have at 4,294,967,294. It is however extremely unlikely
    your game will consist of this many entities or components. Probably KivEnt
    will also be hopelessly overwhelmed.

    EntityManager is typically allocated as part of your GameWorld.allocate.

    **Attributes: (Cython Access Only):

        **memory_index** (IndexedMemoryZone): Zoned memory for storing the
        Entity indices.

        **system_count** (unsigned int): The number of slots reserved per
        Entitywill be one more than the initialization system_count arg as the
        first entry is used internally to determine whether an entity is
        active.

    '''
    def __cinit__(self):
        '''
        '''
        pass

    def allocate(self, master_buffer, gameworld):
        cdef dict zones_dict = {}
        zones = gameworld.zones
        system_manager = gameworld.managers['system_manager']
        self.system_count = gameworld.system_count + 1
        if 'general' not in zones:
            zones['general'] = gameworld.DEFAULT_COUNT
        for key in zones:
            zones_dict[key] = zones[key]
            system_manager.add_zone(key, zones[key])
        self.memory_index = IndexedMemoryZone(
            master_buffer, gameworld.size_of_entity_block, 
            sizeof(unsigned int)*self.system_count, zones_dict,
            Entity)
        gameworld.entities = self.memory_index
        return self.get_size()


    cdef void clear_entity(self, unsigned int entity_id):
        '''
        Clears an entity, setting all slots to <unsigned int>-1.

        Args:
            entity_id (unsigned int): The index of the entity to be cleared.
        '''
        cdef MemoryZone memory_zone = self.memory_index.memory_zone
        cdef unsigned int* pointer = <unsigned int*>(
            memory_zone.get_pointer(entity_id))
        cdef unsigned int system_count = self.system_count
        cdef unsigned int i
        for i in range(system_count):
            pointer[i] = -1

    cdef unsigned int get_size(self):
        '''
        Returns the size of the IndexedMemoryZone in bytes.
        '''
        return self.memory_index.get_size()

    cdef int set_component(self, unsigned int entity_id,
        unsigned int component_id, unsigned int system_id) except 0:
        '''
        Sets the component_id for the system at system_id in the
        entity data for Entity entity_id. Typically called by the GameSystem
        create_component automatically as part of initializing an entity.
        If you wish to change a component you should use the GameSystem's
        remove_component and create_component rather than manually calling
        this function, unless you really know the implications of what you are
        doing.

        Args:
            entity_id (unsigned int): id of the entity to set the component on.

            component_id (unsigned int): id of the component to be set.

            system_id (usngined int): index of the GameSystem.

        '''
        cdef Entity entity = self.memory_index[entity_id]
        entity.set_component(component_id, system_id)
        return 1

    cdef void set_entity_active(self, unsigned int entity_id):
        '''
        Marks the Entity at entity_id as active. This means that
        the first entry for that entity has been set to the entity_id
        instead of <unsigned int>-1. Typically called internally as part of
        **generate_entity**.

        Args:
            entity_id (unsigned int): The id of the entity to activate

        '''
        cdef MemoryZone memory_zone = self.memory_index.memory_zone
        cdef unsigned int* pointer = <unsigned int*>(
            memory_zone.get_pointer(entity_id))
        pointer[0] = entity_id

    cdef unsigned int generate_entity(self, str zone) except -1:
        '''
        Activates a new entity in zone of **memory_index. Typically
        called internally as part of GameWorld.get_entity

        Args:
            zone (str): The zone to initialize the entity in.

        Return:
            new_id (unsigned int): The entity_id by which the new Entity will
            be referred to.

        '''
        cdef IndexedMemoryZone memory_index = self.memory_index
        cdef MemoryZone memory_zone = memory_index.memory_zone
        cdef unsigned int new_id = memory_zone.get_free_slot(zone)
        self.clear_entity(new_id)
        self.set_entity_active(new_id)
        return new_id

    def get_entity_entry(self, entity_id):
        '''Will return a list of **system_count** items corresponding to all
        the indices that make up the entity. If a value is 4,294,967,295,
        which is <unsigned int>-1, that component is inactive. If the first
        value is <unsigned int>-1 the entity itself is currently inactive.

        Args:
            entity_id (unsigned int): Identity of the entity to return.

        Return:
            list of ints : The component_id of each of the GameSystem with
            do_components.
        '''
        cdef unsigned int* pointer = <unsigned int*>(
            self.memory_index.memory_zone.get_pointer(entity_id))
        return [pointer[x] for x in range(self.system_count)]

    cdef void remove_entity(self, unsigned int entity_id):
        '''Removes an entity from the **memory_index**, will mark as inactive
        and free the associated memory for reuse. Will clear the entity before
        freeing.

        Args:
            entity_id (unsigned int): The identity of the entity to remove
        '''
        self.clear_entity(entity_id)
        cdef MemoryZone memory_zone = self.memory_index.memory_zone
        memory_zone.free_slot(entity_id)

    cpdef unsigned int get_active_entity_count(self):
        ''' Returns the number of all currently active entities.

        **Return**:
            unsigned int: active entity count.
        '''
        cdef MemoryZone memory_zone = self.memory_index.memory_zone
        return memory_zone.get_active_slot_count()

    cpdef unsigned int get_active_entity_count_in_zone(self, str zone) except <unsigned int>-1:
        '''Returns the number of currently active entities for the given zone.

        **Args**:
            zone (str): The zone name.

        **Return**:
            unsigned int: active entity count in the given zone.

        Will raise a **ValueError** exception if the given zone does not exists.
        '''
        cdef MemoryZone memory_zone = self.memory_index.memory_zone
        cdef unsigned int pool_index = memory_zone.get_pool_index_from_name(zone) 
        return memory_zone.get_active_slot_count_in_pool(pool_index)
