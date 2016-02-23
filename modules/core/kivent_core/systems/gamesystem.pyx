# cython: embedsignature=True
'''
This is the base for creating a GameSystem usable from python. It will 
store the components in a python list and allow dynamic control of your 
components data as it is just a python object. These type of GameSystem 
do not store their memory as contiguously as the more optimized game systems 
but are perfectly suitable for prototyping or game systems that simply do not
do that much processing.
'''
from kivent_core.uix.cwidget cimport CWidget
from kivy.properties import (StringProperty, ListProperty, 
    NumericProperty, BooleanProperty, ObjectProperty)
from kivent_core.managers.system_manager cimport SystemManager
from kivy.clock import Clock
from kivy.factory import Factory
from kivent_core.managers.entity_manager cimport EntityManager
from kivy.logger import Logger
from kivent_core.gameworld import debug
from collections import deque
from kivent_core.memory_handlers.membuffer cimport Buffer

class Component(object):
    '''A component will keep track of the data for your GameSystems logic.
    It keeps track of its own identity (index in the components list), and
    the entity_id of its entity. If the entity_id returned is <unsigned int>-1
    the component is not currently attached to an entity

    **Attributes:**
        **_id** (unsigned int): The identity of this component
    '''
    
    def __init__(self, component_id):
        self._id = component_id
        self.entity_id = <unsigned int>-1


cdef class GameSystem(CWidget):
    '''
    GameSystem is the part of your game that holds the logic to operate 
    on the data of your Entity's components. It will also manage assembling,
    cleaning up, storing, and destroying the components holding system data.
    The basic GameSystem keeps track of **Component**, which is a 
    regular Python object supporting all the dynamic nature of python but 
    without many static optimizations. 
    The basic setup is that we will create a Component object and release them
    for garbage collection when the entity is done. We will avoid resizing the
    components list by reusing space in the list (a component will be cleared
    to None when removed and an internal free list will provide these spaces
    before growing the list).

    **Attributes:**
        **system_id** (StringProperty): Name of this gamesystem, used to name 
        entity component attribute, and refer to system.

        **system_index** (NumericProperty): The integer index of the GameSystem
        in the SystemManager array. Corresponds to where in the entity array
        you will find this system's component_index. 

        **updateable** (BooleanProperty): Boolean to let gameworld know 
        whether or not to run an update tick on this gamesystem. Defaults to 
        False

        **paused** (BooleanProperty): Boolean used to determine whether or not 
        this system should be updated on the current tick,
        if updateable is True

        **gameworld** (ObjectProperty): Reference to the gameworld object, 
        usually bound in kv

        **gameview** (StringProperty): Name of the GameView this system will 
        be rendered too. If set to None the system will instead be rendered
        to GameWorld's canvas. The default value is None

        **update_time** (NumericProperty): The 'tick' rate of this system's 
        update. Defaults to 1./60. or 60 FPS

        **components** (list): a list of the components currently active. 
        If the list contains None at an index that component has been recently
        released for GC and a free list is being maintained internally. Skip
        these values during processing.

        **frame_time** (float): Leftover time from the last update, not consumed
        yet.

        **do_allocation** (BooleanProperty): Determines whether GameWorld
        should run the **allocate** function of the GameSystem during GameWorld
        allocation.

        **do_components** (BooleanProperty): Indicates whether the GameSystem 
        will actually have components and thus have a slot reserved for storing
        the component in the EntityManager array. 

        **zones** (ListProperty): Determines which zones will be present in the
        GameSystem's memory allocation. Unused in the default GameSystem
        implementation.

    '''
    system_id = StringProperty(None, allownone=True)
    system_index = NumericProperty(None)
    updateable = BooleanProperty(False)
    paused = BooleanProperty(False)
    gameworld = ObjectProperty(None)
    gameview = StringProperty(None, allownone=True)
    update_time = NumericProperty(1./60.)
    do_allocation = BooleanProperty(False)
    do_components = BooleanProperty(True)
    zones = ListProperty([])

    property frame_time:
        def __get__(self):
            return self._frame_time

        def __set__(self, float value):
            self._frame_time = value

    property components:
        def __get__(self):
            return self.py_components

    def __init__(self, **kwargs):
        super(GameSystem, self).__init__(**kwargs)
        self.py_components = []
        self.free_indices = deque()
        self.component_count = 0
        self._frame_time = 0.0
        self.copied_components = {}

    def allocate(self, Buffer master_buffer, dict reserve_spec):
        '''
        Override this function if your GameSystem desires to make static 
        allocation of some data to be kept for the lifetime of the GameSystem. 

        Args:
            master_buffer (Buffer): The buffer that this system will allocate
            itself from.

            reserve_spec (dict): A key value pairing of zone name (str) 
            to be allocated and desired counts for number of entities in that 
            zone.
        '''
        pass

    def on_gameview(self, instance, value):
        '''
        Event that handles the adding of this widget to the appropriate parent
        if gameview is set. 
        '''
        if self.parent is not None:
            self.parent.remove_widget(self)
        if value is None:
            self.gameworld.add_widget(self)
        cdef SystemManager system_manager = self.gameworld.system_manager
        systems = system_manager.system_index
        if value not in systems:
            #reschedule if we do not find the gameview created yet.
            Clock.schedule_once(lambda dt: self.on_gameview(instance, value))
            return
        else:
            gameview = system_manager[value]
            gameview.add_widget(self)

    def update(self, dt):
        '''
        Args:
            dt (float): time argument passed in by Clock. Should be
            equivalent to update_time.

        Override this function to create your gamesystems update logic
        typically looks like:

        .. code-block:: python

            gameworld = self.gameworld
            entities = gameworld.entities
            for component in self.components:
                #make sure to skip released components.
                if component is not None:
                    #If we need other components from the entity let us 
                    #retrieve it like this:
                    entity_id = component.entity_id
                    entity = entities[entity_id]
                    #Do your system logic per entity here
        '''
        pass

    def _update(self, float dt):
        '''
        This function is called internally in order to ensure that no time 
        is lost, excess time that is not quite another update_time
        is added to frame_time and consumed next tick.
        '''
        cdef float frame_time = self._frame_time
        frame_time += dt
        update_time = self.update_time
        update = self.update
        while frame_time >= update_time:
            update(update_time)
            frame_time -= update_time
        self._frame_time = frame_time


    def init_component(self, component_index, entity_id, zone, args):
        '''Override this function to provide custom logic for setting up your 
        component, by default each key, val pair of args will be setattr on 
        the component.'''
        component = self.py_components[component_index]
        component.entity_id = entity_id
        for each in args:
            setattr(component, each, args[each])

    def clear_component(self, component_index):
        '''Override this function if we must cleanup the component in some way 
        before destroying or reusing it.'''
        pass

    def get_component(self, zone):
        '''This function is used internally to determine whether to add a new 
        spot onto our list or use one of the existing free slots. Typically
        you will not need to call or work with it directly unless you
        are designing a custom memory management for your components.

        Return:
            component_id (unsigned int): The index of the newly generated 
            component.
        '''
        free = self.free_indices
        if len(free) > 0:
            index = free.popleft()
            self.py_components[index] = Component(index)
        else:
            index = self.component_count
            self.component_count += 1
            self.py_components.append(Component(index))
        return index

    def create_component(self, unsigned int entity_id, str zone, args):
        '''Typically called by GameWorld automatically as part of creating an
        **Entity**. If you would like to dynamically add a component you should
        call directly. 
        
        Args:
            entity_id (unsigned int) : The identity of the **Entity** to assign
            this component to. 

            zone (str) : Not used in the basic GameSystem but used by 
            other systems which use the **IndexedMemoryZone**. 

            args (dict) : dictionary of the arguments for component 
            initialization

        Return:
            component_index (unsigned int) : The identity (location) of the new 
            **component**. 
        '''
        component_index = self.get_component(zone)
        cdef EntityManager entity_manager = self.gameworld.entity_manager
        cdef unsigned int system_index = self.system_index
        entity_manager.set_component(entity_id, component_index, 
            system_index)
        self.init_component(component_index, entity_id, zone, args)
        return component_index

    def copy_component(self, unsigned int entity_id, 
                       unsigned int component_index):
        cdef EntityManager entity_manager = self.gameworld.entity_manager
        cdef unsigned int system_index = self.system_index
        entity_manager.set_component(entity_id, component_index, 
            system_index)
        self.copied_components[entity_id] = component_index
        return component_index

    def remove_component(self, unsigned int component_index):
        '''
        Typically this will be called automatically by GameWorld. If you want to 
        remove a component without destroying the entity call this function 
        directly. 
        If you want to override the behavior of component cleanup override 
        **clear_component** instead. Only override this function if you
        are working directly with the storage of components for your system.

        Args:
            component_index (unsigned int): the component_id to be removed.
        '''
        self.clear_component(component_index)
        self.py_components[component_index] = None
        self.free_indices.append(component_index)
        

    def on_remove_system(self):
        '''Function called when a system is removed during a gameworld state 
        change
        '''
        pass

    def on_add_system(self):
        '''Function called when a system is added during a gameworld state
        change'''
        pass

    def on_delete_system(self):
        '''Function called when a system is deleted by gameworld'''
        pass


Factory.register('GameSystem', cls=GameSystem)