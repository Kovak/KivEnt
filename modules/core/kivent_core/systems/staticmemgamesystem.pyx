# cython: embedsignature=True
'''
**StaticMemGameSystem** and **MemComponent** are the basis for all built in
GameSystems. They are cythonic classes that store their data in raw C
arrays allocated using the custom memory management designed for pooling and
contiguous processing found in the **memory_handlers** modules.
'''
from kivent_core.memory_handlers.zone cimport MemoryZone
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone
from kivy.properties import (NumericProperty, ObjectProperty, ListProperty,
    BooleanProperty)
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivent_core.memory_handlers.zonedblock cimport ZonedBlock
from kivent_core.systems.gamesystem cimport GameSystem
from kivent_core.managers.system_manager cimport SystemManager
from cpython cimport bool
from kivent_core.memory_handlers.utils import memrange
from kivent_core.managers.entity_manager cimport EntityManager


cdef class MemComponent:
    '''The base for a cdef extension that will work with the MemoryBlock
    memory management system. The data do not live inside the MemComponent,
    it just provide a python accessible interface for working with the raw
    C structs holding the data. Will store a pointer to the actual data,
    and the index of the slot. All of the Python accessible C optimized
    components (and the Entity class) inherit from this class.

    **Attributes: (Cython Access Only)**
        **pointer** (void*): Pointer to the location in the provided
        memory_block that this component's data resides in.

        **_id** (unsigned int): Index of this component in the overall
        component memory. Will usually be locate in MemoryBlock + offset of
        MemoryBlock in the MemoryPool.

    '''

    def __cinit__(self, MemoryBlock memory_block, unsigned int index,
        unsigned int offset):
        '''Initializes a new MemComponent, typically called internally by
        GameSystem or EntityManager.

        Args:
            memory_block (MemoryBlock): the actual MemoryBlock where the data
            for this component resides.

            index (unsigned int): The location of the data in the MemoryBlock
            array.

            offset (unsigned int): The offset of the MemoryBlock in the
            MemoryPool or MemoryZone.
        '''
        self._id = index + offset
        self.pointer = memory_block.get_pointer(index)


class NotAllocatedError(Exception):
    pass


cdef class StaticMemGameSystem(GameSystem):
    '''
    The StaticMemGameSystem keeps a statically allocated array of C structs as
    its components. The allocation is split out into several different 'zones'.
    This is done to help you ensure all entities of a certain type are processed
    roughly in order. The StaticMemGameSystem's components will also be pooled.
    All components will be created once and reused as often as possible.
    It will not be possibleto create more components in a zone than specified
    by the zone configuration.
    This class should not be used directly but instead inherited from to
    create your own GameSystem that makes use of the static, memory pooling
    features. This class should never be inherited from in Python as you will
    need Cython/C level access to various attributes and the components.

    **Attributes:**
        **size_of_component_block** (int): Internally the memory will be broken
        down into blocks of **size_of_component_block** kibibytes. Defaults to
        4.

        **type_size** (int): Number of bytes for the type. Typically you will
        set this with sizeof(YourCStruct).

        **component_type** (MemComponent): The object that will make your C
        structcomponent's data accessible from python. Should inherit from
        MemComponent.

        **processor** (BooleanProperty): If set to True, the system will
        allocate a helper object **ZonedAggregator** to make it easier to batch
        process all the system's components in your **update** function.
        Defaults to False.

        **system_names** (ListProperty): Names of the other component systems
        to be bound by the **ZonedAggregator**, this should be a list of other
        StaticMemGameSystem **system_id** that you will need the component data
        from during your **update** function

        **do_allocation** (BooleanProperty): Defaults to True for
        StaticMemGameSystem as we expect an allocation phase.

        **components** (IndexedMemoryZone): Instead of the simple python list,
        components are stored in the more complex IndexedMemoryZone which
        supports both direct C access to the underlying struct arrays and
        python level access to the **component_type** objects that wrap the
        C data.

    '''
    size_of_component_block = NumericProperty(4)
    type_size = NumericProperty(0)
    component_type = ObjectProperty(None)
    processor = BooleanProperty(False)
    system_names = ListProperty([])
    do_allocation = BooleanProperty(True)

    def __cinit__(self, **kwargs):
        self.entity_components = None
        self.imz_components = None

    property components:
        def __get__(self):
            if self.imz_components == None:
                raise NotAllocatedError('''{system_id} has not been
                    allocated yet'''.format(system_id=self.system_id))
            return self.imz_components

    def get_component(self, str zone):
        '''
        Overrides GameSystem's default get_component, using
        IndexedMemoryZone to handle component data instead. **clear_component**
        will be called prior to returning the new index of the component
        ensuring no junk data is present.

        Return:
            unsigned int: The index of the newly generated component.
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef unsigned int new_id = memory_zone.get_free_slot(zone)
        self.clear_component(new_id)
        return new_id

    def clear_entities(self):
        entities_to_clear = [
            component.entity_id for component in memrange(self.components)
            ]
        gameworld = self.gameworld
        for entity_id in entities_to_clear:
            gameworld.remove_entity(entity_id)

    def allocate(self, Buffer master_buffer, dict reserve_spec):
        '''
        Allocates an IndexedMemoryZone from the buffer provided following
        the zone_name, count pairings in reserve_spec. The IndexedMemoryZone
        will be stored internally on the C extension **imz_components**
        attribute, it is accessible in python through the **components**
        property. If **processor** is True a ZonedAggregator will also be
        allocated. This stores void pointers to the various components of the
        entity based on the system_names provides in **system_names**. This
        makes it easier to retrieve various component data for processing.

        Args:
            master_buffer (Buffer): The buffer that this syscdtem will allocate
            itself from.

            reserve_spec (dict): A key value pairing of zone name (str)
            to be allocated and desired counts for number of entities in that
            zone.
        '''
        self.imz_components = IndexedMemoryZone(master_buffer,
            self.size_of_component_block, self.type_size,
            reserve_spec, self.component_type)
        if self.processor:
            self.entity_components = ZonedAggregator(
                [x for x in self.system_names], reserve_spec,
                self.gameworld, master_buffer)

    def get_system_size(self):
        '''
        Returns the actual size being taken up by system data. Does not
        include python objects, just the various underlying arrays holding
        raw component data, and other memories allocated by this GameSystem.
        Must be called after **allocate**.

        Return:
            int: size in bytes of the system's allocations.
        '''
        size = self.imz_components.get_size()
        if self.processor:
            size += self.entity_components.get_size()
        return size

    def get_size_estimate(self, dict reserve_spec):
        '''
        Returns an estimated size, safe to call before calling **allocate**.
        Used internally by GameWorld to estimate if enough memory is available
        to support the GameSystem

        Return:
            int: estimated size in bytes of the system's allocations.
        '''
        cdef unsigned int size_of_zone, block_count, size_per_ent
        cdef unsigned int total = 0
        cdef unsigned int pointer_size_in_kb = 0
        cdef unsigned int count
        cdef unsigned int type_size = self.type_size
        cdef unsigned int block_size_in_kb = self.size_of_component_block
        cdef unsigned int size_in_bytes = (block_size_in_kb * 1024)
        cdef unsigned int slots_per_block = size_in_bytes // type_size
        cdef unsigned int entity_count = 0
        for zone_name in reserve_spec:
            size_of_zone = reserve_spec[zone_name]
            block_count = (size_of_zone//slots_per_block) + 1
            total += block_count*block_size_in_kb
            entity_count += block_count*slots_per_block
        if self.processor:
            count = len(self.system_names)
            size_per_ent = sizeof(void*) * count
            pointer_size_in_kb = ((entity_count * size_per_ent) // 1024) + 1
        return total + pointer_size_in_kb

    def remove_component(self, unsigned int component_index):
        '''
        Overrides the default behavior of GameSystem, passing data handling
        duties to the IndexedMemoryZone. **clear_component** will be called
        prior to calling **free_slot** on the MemoryZone.'''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef EntityManager entity_manager = self.gameworld.entity_manager
        cdef unsigned int *pointer = <unsigned int*>memory_zone.get_pointer(
            component_index)
        cdef unsigned int entity_id = pointer[0]
        self.clear_component(component_index)
        entity_manager.set_component(entity_id, -1, self.system_index)
        memory_zone.free_slot(component_index)

    def init_component(self, unsigned int component_index,
        unsigned int entity_id, args):
        '''
        Not implemented for StaticMemGameSystem, override when subclassing.
        Use this function to setup the initialization of a component's values.
        '''
        pass

    def clear_component(self, unsigned int component_index):
        '''
        Not implemented for StaticMemGameSystem, override when subclassing.
        Use this function to setup the clearing of a component's values for
        recycling'''
        pass

    cpdef unsigned int get_active_component_count(self) except <unsigned int>-1:
        '''Returns the number of all active components in this system.

        **Return:**
            unsigned int: The number of active components.
        '''
        cdef IndexedMemoryZone indexed = self.imz_components
        cdef MemoryZone memory_zone = indexed.memory_zone
        return memory_zone.get_active_slot_count()
    
    cpdef unsigned int get_active_component_count_in_zone(self, str zone) except <unsigned int>-1:
        '''Returns the number of active components of this system in the given zone.

        **Args:**
            zone (str): The name of the zone to get the count from.

        **Return:**
            unsigned int: The number of active components in the given zone.

        Will raise a **ValueError** exception if this **GameSystem**
        does not use the given zone.
        '''
        cdef IndexedMemoryZone indexed = self.imz_components
        cdef MemoryZone memory_zone = indexed.memory_zone
        cdef unsigned int pool_index = memory_zone.get_pool_index_from_name(zone) 
        return memory_zone.get_active_slot_count_in_pool(pool_index)


cdef class ZonedAggregator:
    '''
    ZonedAggregator provides a shortcut for processing data from several
    components. A single contiguous array of void pointers is allocated,
    respecting the zoning of memory for the IndexedMemoryZone.
    It is not accessible from Python, this class is meant to be used only from
    Cython and allow you to deal directly with pointers to memory. Unintended
    uses could result in dangling pointers. You will be responsible for
    correctly casting the result while executing the system logic.
    If you remove a component from your entity that is being tracked by the
    Aggregator, you must remove and readd the entity to the Aggregator or it
    will have a bad reference.

    **Attributes (Cython Access Only):**
        **count** (unsigned int): The number of systems being tracked by this
        aggregator.

        **total** (unsigned int): The number of entitys data can be collected
        from summing all zones. The actual number of pointers being tracked is
        total * count

        **entity_block_index** (dict): Stores the actual location of the entity
        in the Aggregator as keyed by the entity_id.

        **system_names** (list): The systems that components will be retrieved
        from per entity.

        **memory_block** (ZonedBlock): The actual container of the pointer data.
        Access via memory_block.data

        **gameworld** (object): Reference to the GameWorld for access to
        entities and system_manager.
    '''

    def __cinit__(self, list system_names, dict zone_counts,
        object gameworld, Buffer master_buffer):
        '''
        The ZonedAggregator allocates a ZonedBlock with enough space
        to fit the total sum of entities as specified in the zone_counts dict.

        Args:
            system_names (list): The names of the systems to lookup pointers
            for, will be stored in the same order as listed.

            zone_counts (dict): The config_dict for the GameSystem's zones.

            gameworld (object): Reference to the GameWorld widget for the
            GameSystem

            master_buffer (Buffer): the buffer from which the void pointer
            array will be allocated.
        '''
        self.count = len(system_names)
        cdef unsigned int total = 0
        for zone_name in zone_counts:
            total += zone_counts[zone_name]
        self.total = total
        self.gameworld = gameworld
        self.system_names = system_names
        self.entity_block_index = {}
        cdef unsigned int size_per_ent = sizeof(void*) * self.count
        self.memory_block = ZonedBlock(size_per_ent, zone_counts)
        self.memory_block.allocate_memory_with_buffer(master_buffer)
        self.clear()

    cdef bool check_empty(self):
        '''
        Determines whether the **memory_block** is current empty

        Return:
            bool: Will be True if there is no data in **memory_block**, else
            False.
        '''
        return self.memory_block.check_empty()

    cdef void free(self):
        '''
        Free the memory being used by **memory_block**, returning it to
        whichever Buffer the memory was allocated from during initialization
        '''
        self.memory_block.remove_from_buffer()

    cdef unsigned int get_size(self):
        '''Gets the size of the **memory_block**

        Return:
            unsigned int: The amount of data in bytes reserved by the
            **memory_block**
        '''
        return self.memory_block.size

    cdef void clear(self):
        '''
        Clears the data in **memory_block**, resetting everything to NULL.
        '''
        cdef void** data = <void**>self.memory_block.data
        self.memory_block.clear()
        cdef unsigned int i
        for i in range(self.total*self.count):
            data[i] = NULL

    cdef int remove_entity(self, unsigned int entity_id) except 0:
        '''
        Removes a previously added entity. All pointers at the location
        will be reset to NULL.

        Args:
            entity_id (unsigned int): the id of the entity to remove from the
            aggregator.

        Return:
            int: 1 if entity_id was successfully removed, else 0. Return exists
            mainly for exception propogation from Cython to Python.
        '''
        cdef unsigned int block_index = self.entity_block_index[entity_id]
        cdef unsigned int adjusted_index = block_index * self.count
        cdef void** data = <void**>self.memory_block.data
        cdef unsigned int i
        for i in range(self.count):
            data[adjusted_index+i] = NULL
        self.memory_block.remove_data(block_index, 1)
        del self.entity_block_index[entity_id]
        return 1

    cdef unsigned int add_entity(self, unsigned int entity_id,
        str zone_name) except -1:
        '''
        Adds an entity to the aggregator, inserting it into zone_name
        section of the **memory_block**. Pointers to the current components
        corresponding to **system_names** will be stored for iteration on
        update. An exception will be raised if <unsigned int>-1 is returned.
        A hashmap (**entity_block_index**) of entity_id, block_index will be
        created so that you do not have to keep in mind the internal position
        in the aggregator when dealing with your entities.

        Args:
            entity_id (unsigned int): The id of the entity to be added.

            zone_name (str): The zone of the aggregator to insert this entity
            into, should match the zone the entity's components exist in.

        Return:
            unsigned int: Will return the index of the pointers in the
            **memory_block**
        '''
        cdef unsigned int block_index = self.memory_block.add_data(1, zone_name)
        cdef IndexedMemoryZone entities = self.gameworld.entities
        cdef unsigned int* entity = <unsigned int*>entities.get_pointer(
            entity_id)
        cdef unsigned int adjusted_index = block_index * self.count
        self.entity_block_index[entity_id] = block_index
        cdef unsigned int system_index, component_index, pointer_loc
        cdef StaticMemGameSystem system
        cdef unsigned int i
        cdef str system_name
        cdef MemoryZone memory_zone
        cdef void** data = <void**>self.memory_block.data
        cdef SystemManager system_manager = self.gameworld.system_manager
        cdef list systems = system_manager.systems
        for i, system_name in enumerate(self.system_names):
            pointer_loc = adjusted_index + i
            system_index = system_manager.get_system_index(system_name)
            component_index = entity[system_index+1]
            system = systems[system_index]
            memory_zone = system.imz_components.memory_zone
            data[pointer_loc] = memory_zone.get_pointer(component_index)
        return block_index


cdef class ComponentPointerAggregator:
    '''
    ComponentPointerAggregator provides a shortcut for processing data from
    several components. A single contiguous array of void pointers is allocated.
    It is not accessible from Python, this class is meant to be used only from
    Cython and allow you to deal directly with pointers to memory. Unintended
    uses could result in dangling pointers. You will be responsible for
    correctly casting the result while executing the system logic. If you
    remove a component from your entity that is being tracked by the Aggregator,
    you must remove and readd the entity to the Aggregator or it will have a
    bad reference.

    **Attributes (Cython Access Only):**
        **count** (unsigned int): The number of systems being tracked by this
        aggregator.

        **total** (unsigned int): The number of entitys data can be collected
        from summing all zones. The actual number of pointers being tracked is
        total * count

        **entity_block_index** (dict): Stores the actual location of the entity
        in the Aggregator as keyed by the entity_id.

        **system_names** (list): The systems that components will be retrieved
        from per entity.

        **memory_block** (MemoryBlock): The actual container of the pointer
        data. Access via memory_block.data

        **gameworld** (object): Reference to the GameWorld for access to
        entities and system_manager.
    '''

    def __cinit__(self, list system_names, unsigned int total,
        object gameworld, Buffer master_buffer):
        '''
        The ComponentPointerAggregator allocates a MemoryBlock with enough
        space to fit total * len(system_names) void pointers.

        Args:
            system_names (list): The names of the systems to lookup pointers
            for, will be stored in the same order as listed.

            total (unsigned int): The number of entities to make space for.

            gameworld (object): Reference to the GameWorld widget for the
            GameSystem

            master_buffer (Buffer): the buffer from which the void pointer
            array will be allocated.
        '''
        cdef unsigned int count = len(system_names)
        self.count = count
        self.total = total
        self.gameworld = gameworld
        self.system_names = system_names
        self.entity_block_index = {}
        cdef unsigned int size_per_ent = sizeof(void*) * count
        cdef unsigned int size_in_kb = ((total * size_per_ent) // 1024) + 1
        self.memory_block = MemoryBlock(size_in_kb*1024, size_per_ent, 1)
        self.memory_block.allocate_memory_with_buffer(master_buffer)
        self.clear()

    cdef bool check_empty(self):
        '''
        Determines whether the **memory_block** is current empty

        Return:
            bool: Will be True if there is no data in **memory_block**,
            else False.
        '''
        return self.memory_block.check_empty()

    cdef void free(self):
        '''
        Free the memory being used by **memory_block**, returning it to
        whichever Buffer the memory was allocated from during initialization
        '''
        self.memory_block.remove_from_buffer()

    cdef unsigned int get_size(self):
        '''
        Gets the size of the **memory_block**

        Return:
            size (unsigned int): The amount of data in bytes reserved by
            the **memory_block**
        '''
        return self.memory_block.real_size

    cdef void clear(self):
        '''
        Clears the data in **memory_block**, resetting everything to NULL.
        '''
        cdef void** data = <void**>self.memory_block.data
        self.memory_block.clear()
        cdef unsigned int i
        for i in range(self.total*self.count):
            data[i] = NULL

    cdef int remove_entity(self, unsigned int entity_id) except 0:
        '''
        Removes a previously added entity. All pointers at the location
        will be reset to NULL.

        Args:
            entity_id (unsigned int): the id of the entity to remove from the
            aggregator.

        Return:
            int: 1 if entity_id was successfully removed, else 0. Return exists
            mainly for exception propogation from Cython to Python.
        '''
        cdef unsigned int block_index = self.entity_block_index[entity_id]
        cdef unsigned int adjusted_index = block_index * self.count
        cdef void** data = <void**>self.memory_block.data
        cdef unsigned int i
        for i in range(self.count):
            data[adjusted_index+i] = NULL
        self.memory_block.remove_data(block_index, 1)
        del self.entity_block_index[entity_id]
        return 1

    cdef unsigned int add_entity(self, unsigned int entity_id) except -1:
        '''
        Adds an entity to the aggregator, inserting it into the first
        available slot in the **memory_block**. Pointers to the current
        components corresponding to **system_names** will be stored for
        iteration on update. An exception will be raised if <unsigned int>-1 is
        returned. A hashmap (**entity_block_index**) of entity_id, block_index
        will be created so that you do not have to keep in mind the internal
        position in the aggregator when dealing with your entities.

        Args:
            entity_id (unsigned int): The id of the entity to be added.

        Return:
            unsigned int: Will return the index of the pointers in the
            **memory_block**
        '''
        cdef unsigned int block_index = self.memory_block.add_data(1)
        cdef IndexedMemoryZone entities = self.gameworld.entities
        cdef unsigned int* entity = <unsigned int*>entities.get_pointer(
            entity_id)
        cdef unsigned int adjusted_index = block_index * self.count
        self.entity_block_index[entity_id] = block_index
        cdef unsigned int system_index, component_index, pointer_loc
        cdef StaticMemGameSystem system
        cdef unsigned int i
        cdef str system_name
        cdef MemoryZone memory_zone
        cdef void** data = <void**>self.memory_block.data
        cdef SystemManager system_manager = self.gameworld.system_manager
        cdef list systems = system_manager.systems
        for i, system_name in enumerate(self.system_names):
            pointer_loc = adjusted_index + i
            system_index = system_manager.get_system_index(system_name)
            if system_index == <unsigned int>(-1):
                raise KeyError(system_name)
            try:
                component_index = entity[system_index+1]
                system = systems[system_index]
                memory_zone = system.imz_components.memory_zone
                data[pointer_loc] = memory_zone.get_pointer(component_index)
            except IndexError, e:
                raise KeyError("missing key=%s raised %s"%(system_name, e))
        return block_index
