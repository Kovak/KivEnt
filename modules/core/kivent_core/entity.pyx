# cython: embedsignature=True
from kivent_core.systems.staticmemgamesystem cimport MemComponent, GameSystem
from kivent_core.memory_handlers.block cimport MemoryBlock
from kivent_core.memory_handlers.indexing cimport IndexedMemoryZone

class NoSystemWithNameError(Exception):
    pass

class SystemHasNoComponentsError(Exception):
    pass

class NoComponentActiveError(Exception):
    pass

class DuplicateComponentError(Exception):
    pass

cdef class Entity(MemComponent):
    '''Entity is a python object that will allow access to all of the components
    attached to that particular entity. GameWorld is responsible for creating
    and recycling entities. You should never create an Entity directly or
    modify an entity_id. You can access an active entity component by dot
    lookup: for instance entity.position would retrieve the component for
    GameSystem with system_id 'position'. If no component is active for that
    GameSystem an IndexError will be raised.

    **Attributes:**
        **entity_id** (int): The entity_id will be assigned on creation by the
        GameWorld. You will use this number to refer to the entity throughout
        your Game.

        **load_order** (list): The load order is the order in which GameSystem
        components should be initialized. When GameWorld.remove_entity is called
        components will be removed in the reverse of load_order.

        **system_manager** (SystemManager): The SystemManager for the GameWorld.
        Typically set during GameWorld.init_entity. Not accessible from Python,
        used internally for retrieving the appropriate index of a GameSystem.
    '''
    def __cinit__(self, MemoryBlock memory_block, unsigned int index,
            unsigned int offset):
        self._load_order = []
        self.system_manager = None

    def __getattr__(self, str name):
        cdef SystemManager system_manager = self.system_manager
        cdef unsigned int system_index = system_manager.get_system_index(name)
        if system_index == -1:
            raise NoSystemWithNameError(
                'There is no system named {system_name}'
                .format(system_name=name))
        if system_index >= system_manager.system_count:
            raise SystemHasNoComponentsError(
                'The {system_name} system has no components'
                .format(system_name=name))
        cdef GameSystem system = system_manager[name]
        cdef unsigned int* pointer = <unsigned int*>self.pointer
        cdef unsigned int component_index = pointer[system_index+1]
        if component_index == <unsigned int>-1:
            raise NoComponentActiveError(
                'Entity {ent_id} has no component '
                'active for {system_name}'.format(ent_id=str(self._id),
                    system_name=name))
        return system.components[component_index]

    property entity_id:
        def __get__(self):
            return self._id

    property load_order:
        def __get__(self):
            cdef SystemManager system_manager = self.system_manager
            cdef GameSystem system
            cdef list ret = list()
            cdef unsigned int comp_index
            for system_index in self._load_order:
                comp_index = self.get_component_index_c(system_index)
                if comp_index == <unsigned int>-1:
                    continue
                system = system_manager.systems[system_index]
                ret.append(system.system_id)
            return ret

    cdef int set_component(self, unsigned int component_id,
        unsigned int system_index) except 0:
        '''Sets the component_id for component of system with system_id index
        Args:
            component_id (unsigned int): Index of the component in the
            GameSystem

            system_index (unsigned int): System index of the GameSystem
        '''
        cdef unsigned int* pointer = <unsigned int*>self.pointer
        if component_id != <unsigned int>-1: # a new component is registered
            if pointer[system_index+1] != <unsigned int>-1:
                system = self.system_manager.systems[system_index]
                raise DuplicateComponentError(
                    "Entity already has a component for system '%s'." % (
                        system.system_id
                        ))
            if system_index not in self._load_order:
                self._load_order.append(system_index)
        pointer[system_index+1] = component_id
        return 1

    cpdef unsigned int get_component_index(self, str name):
        '''Gets the index of the component for GameSystem with system_id name.
        Args:
            name (str): The system_id of the GameSystem to retrieve the
            component for.
        Return:
            component_index (unsigned int): The index of the component
            for the GameSystem with system_id name.
        '''
        cdef unsigned int system_index = self.system_manager.get_system_index(
            name)
        cdef unsigned int* pointer = <unsigned int*>self.pointer
        return pointer[system_index+1]
    
    cdef unsigned int get_component_index_c(self, unsigned int system_index):
        '''Gets the index of the component for the GameSystem with system_index.
        Args:
            system_index (unsigned int): The system_index of the GameSystem to retrieve the
            component for.
        Return:
            component_index (unsigned int): The index of the component
            for the GameSystem with system_id name.
        '''
        cdef unsigned int* pointer = <unsigned int*>self.pointer
        return pointer[system_index+1]
