
from kivy.uix.widget import Widget
from kivy.properties import (StringProperty, ListProperty, 
    NumericProperty, DictProperty, BooleanProperty, ObjectProperty)
from kivy.clock import Clock
from math import fabs
from kivy.core.window import Window


class Component(object):
    pass


cdef class RotateComponent:
    cdef float _r

    def __cinit__(self, float r):
        self._r = r

    property r:
        def __get__(self):
            return self._r
        def __set__(self, float value):
            self._r = value


cdef class ScaleComponent:
    cdef float _s

    def __cinit__(self, float s):
        self._s = s

    property s:
        def __get__(self):
            return self._s
        def __set__(self, float value):
            self._s = value


cdef class PositionComponent:
    cdef float _x
    cdef float _y
    
    def __cinit__(self, float x, float y):
        self._x = x
        self._y = y

    property x:
        def __get__(self):
            return self._x
        def __set__(self, float value):
            self._x = value

    property y:
        def __get__(self):
            return self._y
        def __set__(self, float value):
            self._y = value


cdef class ColorComponent:
    cdef float _r
    cdef float _g
    cdef float _b
    cdef float _a
    
    def __cinit__(self, float r, float g, float b, float a):
        self._r = r
        self._g = g
        self._b = b
        self._a = a

    property r:
        def __get__(self):
            return self._r
        def __set__(self, float value):
            self._r = value

    property g:
        def __get__(self):
            return self._g
        def __set__(self, float value):
            self._g = value

    property b:
        def __get__(self):
            return self._b
        def __set__(self, float value):
            self._b = value

    property a:
        def __get__(self):
            return self._a
        def __set__(self, float value):
            self._a = value


class GameSystem(Widget):
    '''GameSystem is the part of your game that holds the logic to operate 
    on the data of your Entity's components. They keep track of the entity_id
    of each entity that has a component for the system. The GameSystem is 
    responsible for the creation and deletion of its corresponding components.

    **Attributes:**
        **system_id** (StringProperty): Name of this gamesystem, used to name 
        entity component attribute, and refer to system.

        **updateable** (BooleanProperty): Boolean to let gameworld know 
        whether or not to run an update tick on this gamesystem. Defaults to 
        False

        **paused** (BooleanProperty): Boolean used to determine whether or not 
        this system should be updated on the current tickif updateable is True

        **gameworld** (ObjectProperty): Reference to the gameworld object, 
        usually bound in kv

        **viewport** (StringProperty): Name of the GameView this system will 
        be rendered too.

        **update_time** (NumericProperty): The 'tick' rate of this system's 
        update. Defaults to 1./60. or 60 FPS

        **entity_ids** (list): a list of entities that have an active
        component for this GameSystem

    '''

    system_id = StringProperty('default_id')
    updateable = BooleanProperty(False)
    paused = BooleanProperty(False)
    gameworld = ObjectProperty(None)
    viewport = StringProperty('default_gameview')
    update_time = NumericProperty(1./60.)


    def __init__(self, **kwargs):
        cdef list entity_ids
        cdef float frame_time
        super(GameSystem, self).__init__(**kwargs)
        self.entity_ids = list()
        self.frame_time = 0.0

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
            for entity_id in self.entity_ids:
                entity = entities[entity_id]
                #Do your system logic per entity here
        '''
        pass

    def _update(self, dt):
        '''
        This function is called internally in order to ensure that no time 
        is lost, excess time that is not quite another update_time
        is added to frame_time and consumed next tick.
        '''
        self.frame_time += dt
        update_time = self.update_time
        while self.frame_time >= update_time:
            self.update(update_time)
            self.frame_time -= update_time

    def generate_component(self, args):
        '''This function is called to generate a component. The default 
        behavior is to take in a dict and turn all the keys, val pairs to 
        attributes of an Entity object. Override this to create a custom
        component or take in a different args format.
        ''' 
        new_component = Component()
        for each in args:
            setattr(new_component, each, args[each])
        return new_component

    def create_component(self, object entity, args):
        setattr(entity, self.system_id, self.generate_component(args))
        self.entity_ids.append(entity.entity_id)

    def remove_entity(self, int entity_id):
        '''
        Args:
            entity_id (int): the entity_id for the entity being removed
            from the GameSystem

        Function used by GameWorld to remove an entity, you should ensure
        all data related to your component is cleaned up or recycled here'''
        self.entity_ids.remove(entity_id)

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


class PositionSystem(GameSystem):
    '''PositionSystem is optimized to hold 2d location data for your entities.
    The rendering systems will be able to interact with this data using the
    underlying C structures rather than the Python objects.'''

    def generate_component(self, tuple pos):
        '''
        Args:
            pos (tuple): (float x, float y) 

        Position system takes in a tuple: (x, y) and creates a component 
        with x, y properties (_x, _y to access from cython)
        '''
        x = pos[0]
        y = pos[1]
        new_component = PositionComponent.__new__(PositionComponent, x, y)
        return new_component

class ScaleSystem(GameSystem):
    '''ScaleSystem is optimized to hold a single scale float for your entities.
    The rendering systems will be able to interact with this data using the
    underlying C structures rather than the Python objects. This object will
    potentially change in the future to support scaling at different
    rates in different directions.'''

    def generate_component(self, float s):
        '''
        Args:
            s (float): scaling factor for the Entity

        Scale system takes in a float: s and creates a component with
        s property (_s to access from cython)'''
        new_component = ScaleComponent.__new__(ScaleComponent, s)
        return new_component

class RotateSystem(GameSystem):
    '''RotateSystem is optimized to hold a single rotate float for your 
    entities. The CymunkPhysics System and Renderers expect this to be an 
    angle in radians.
    The rendering systems will be able to interact with this data using the
    underlying C structures rather than the Python objects. This object will
    potentially change in the future to support rotating around arbitrary axes
    '''


    def generate_component(self, float r):
        '''
        Args:
            r (float): rotation in radians for the Entity

        Rotate system takes in a float: r and creates a component with
        r property (_r to access from cython)'''
        new_component = RotateComponent.__new__(RotateComponent, r)
        return new_component


class ColorSystem(GameSystem):
    '''ColorSystem is optimized to hold rgba data for your entities. 
    Renderers expect this data to be between 0.0 and 1.0 for each float.
    The rendering systems will be able to interact with this data using the
    underlying C structures rather than the Python objects.'''

    def generate_component(self, tuple color):
        '''
        Args:
            color (tuple): color for entity (r, g, b, a) in 0.0 to 1.0 

        Color system takes in a 4 tuple of floats 0.0 to 1.0 (r, g, b, a)
        and creates r, g, b, a properties (_r, _g, _b, _a to access 
        from cython)'''
        r = color[0]
        g = color[1]
        b = color[2]
        a = color[3]
        new_component = ColorComponent.__new__(ColorComponent, r, g, b, a)
        return new_component


class GameMap(GameSystem):
    '''GameMap is a basic implementation of a map size for your GameWorld that
    limits the scrolling of GameView typically a GameMap does not actually
    have any entities, it simply holds some data and logic for use by
    other GameSystems

    **Attributes:**
        **map_size** (ListProperty): Sets the size of this map, used to 
        determine scrolling bounds. If the map size is smaller than the 
        window it will be centered inside the window.

        **margins** (ListProperty): The amount of scrolling beyond the size of 
        the map in x, y directions to be allowed. If the map is smaller than 
        the window. This value is calculated automatically.

        **default_margins** (ListProperty): The amount of margin if the map is 
        larger than the window, defaults to (0, 0) which means no scrolling 
        beyond edge of GameMap.

    '''
    system_id = StringProperty('default_map')
    map_size = ListProperty((2000., 2000.))
    window_size = ListProperty((0., 0.))
    margins = ListProperty((0., 0.))
    map_color = ListProperty((1., 1., 1., 1.))
    default_margins = ListProperty((0., 0.))

    def on_map_size(self, instance, value):
        self.check_margins()

    def on_size(self, instance, value):
        self.check_margins()

    def check_margins(self):
        map_size = self.map_size
        window_size = Window.size
        window_larger_x = False
        window_larger_y = False
        if window_size[0] > map_size[0]:
            margin_x = (window_size[0] - map_size[0])/2.
            window_larger_x = True
        if window_size[1] > map_size[1]:
            margin_y = (window_size[1] - map_size[1])/2.
            window_larger_y = True
        if window_larger_x:
            self.margins[0] = margin_x
        if window_larger_y:
            self.margins[1] = margin_y
        if not window_larger_x and not window_larger_y:
            self.margins = self.default_margins

    def on_add_system(self):
        super(GameMap, self).on_add_system()
        if self.gameworld:
            self.gameworld.currentmap = self

    def on_remove_system(self):
        super(GameMap, self).on_remove_system()
        if self.gameworld.currentmap == self:
            self.gameworld.currentmap = None


class GameView(GameSystem):
    '''GameView is another entity-less system. It is intended to work with
    other systems in order to provide camera functionally. 
    **The implementation for GameView is very messy at the moment,
    expect changes in the future to clean up the API and add functionality**

    **Attributes:**
        **do_scroll_lock** (BooleanProperty): If True the scrolling will be 
        locked to the bounds of the GameWorld's currentmap.

        **camera_pos** (ListProperty): Current position of the camera

        **focus_entity** (BooleanProperty): If True the camera will follow the 
        entity set in entity_to_focus

        **do_scroll** (BooleanProperty): If True touches will scroll the camera

        **entity_to_focus** (NumericProperty): Entity entity_id for the camera 
        to focus on if focus_entity is True.

        **camera_speed_multiplier** (NumericProperty): Time it will take camera 
        to reach focused entity, Speed will be 1.0/camera_speed_multiplier 
        seconds to close the distance

    '''
    system_id = StringProperty('default_gameview')
    do_scroll_lock = BooleanProperty(True)
    camera_pos = ListProperty((0, 0))
    camera_scale = NumericProperty(1.0)
    focus_entity = BooleanProperty(False)
    do_scroll = BooleanProperty(True)
    entity_to_focus = NumericProperty(None, allownone=True)
    updateable = BooleanProperty(True)
    camera_speed_multiplier = NumericProperty(1.0)

    def on_entity_to_focus(self, instance, value):
        if value ==  None:
            self.focus_entity = False
        else:
            self.focus_entity = True

    def update(self, dt):
        cdef int entity_to_focus
        cdef float dist_x
        cdef float dist_y
        cdef object entity
        cdef float camera_speed_multiplier
        cdef PositionComponent position_data
        gameworld = self.gameworld
        if self.focus_entity:
            entity_to_focus = self.entity_to_focus
            entity = gameworld.entities[entity_to_focus]
            position_data = entity.position
            camera_pos = self.camera_pos
            camera_speed_multiplier = self.camera_speed_multiplier
            size = self.size
            dist_x = -camera_pos[0] - position_data._x + size[0]*.5
            dist_y = -camera_pos[1] - position_data._y + size[1]*.5
            if self.do_scroll_lock:
               dist_x, dist_y = self.lock_scroll(dist_x, dist_y)
            self.camera_pos[0] += dist_x*camera_speed_multiplier*dt
            self.camera_pos[1] += dist_y*camera_speed_multiplier*dt
        gameworld.update_render_state(self)

    def on_size(self, instance, value):
        if self.do_scroll_lock and self.gameworld.currentmap:
            dist_x, dist_y = self.lock_scroll(0, 0)
            self.camera_pos[0] += dist_x
            self.camera_pos[1] += dist_y
        self.gameworld.update_render_state(self)


    def on_touch_move(self, touch):
        if not self.focus_entity and self.do_scroll:
            dist_x = touch.dx
            dist_y = touch.dy
            if fabs(dist_x) + fabs(dist_y) > 2:
                if self.do_scroll_lock and self.gameworld.currentmap:
                    dist_x, dist_y = self.lock_scroll(dist_x, dist_y)
                self.camera_pos[0] += dist_x
                self.camera_pos[1] += dist_y

    def lock_scroll(self, float distance_x, float distance_y):
        currentmap = self.gameworld.currentmap
        size = self.size
        pos = self.pos
        map_size = currentmap.map_size
        margins = currentmap.margins
        camera_pos = self.camera_pos
        cdef float x= pos[0]
        cdef float y = pos[1]
        cdef float w = size[0]
        cdef float h = size[1]
        cdef float mw = map_size[0]
        cdef float mh = map_size[1]
        cdef float marg_x = margins[0]
        cdef float marg_y = margins[1]
        cdef float cx = camera_pos[0]
        cdef float cy = camera_pos[1]

        if cx + distance_x > x + marg_x:
            distance_x = x - cx + marg_x
        elif cx + mw + distance_x <= x + w - marg_x:
            distance_x = x + w - marg_x - cx - mw

        if cy + distance_y > y + marg_y:
            distance_y = y - cy + marg_y 
        elif cy + mh + distance_y <= y + h - marg_y:
            distance_y = y + h - cy - mh  - marg_y

        return distance_x, distance_y

