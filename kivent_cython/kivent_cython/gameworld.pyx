
from kivy.uix.widget import Widget
from kivy.properties import (StringProperty, ListProperty, NumericProperty, 
DictProperty, BooleanProperty, ObjectProperty)
from kivy.clock import Clock
from functools import partial


class GameWorld(Widget):
    state = StringProperty('initial')
    number_entities = NumericProperty(0)
    
    gamescreenmanager = ObjectProperty(None)
    currentmap = ObjectProperty(None, allownone = True)
    

    def __init__(self, **kwargs):
        cdef list entities
        cdef dict states
        cdef list deactivated_entities
        cdef list entities_to_remove
        cdef dict systems
        super(GameWorld, self).__init__(**kwargs)
        self.entities = []
        self.states = {}
        self.deactivated_entities = []
        self.entities_to_remove = []
        self.systems = {}
        #Clock.schedule_once(self.init_world)
        
    def init_world(self, dt):
        Clock.schedule_interval(self.update, 1./30.)

    def add_state(self, state_name, systems_added, systems_removed, systems_paused, systems_unpaused, screenmanager_screen):
        self.states[state_name] = {'systems_added': systems_added, 
        'systems_removed': systems_removed, 'systems_paused': systems_paused, 'systems_unpaused': systems_unpaused}
        self.gamescreenmanager.states[state_name] = screenmanager_screen

    def on_state(self, instance, value):
        state_dict = self.states[value]
        gamescreenmanager = self.gamescreenmanager
        gamescreenmanager.state = value
        
        systems = self.systems
        children = self.children
        for system in state_dict['systems_added']:
            if systems[system] in children:
                pass
            else:
                self.add_widget(systems[system])
        for system in state_dict['systems_removed']:
            if systems[system] in children:
                self.remove_widget(systems[system])
        for system in state_dict['systems_paused']:
            systems[system].paused = True
        for system in state_dict['systems_unpaused']:
            systems[system].paused = False
        self.remove_widget(gamescreenmanager)
        self.add_widget(gamescreenmanager)

    def create_entity(self):
        entity = {'id': self.number_entities}
        self.entities.append(entity)
        self.number_entities += 1
        return entity['id']

    def init_entity(self, dict components_to_use, list component_order):
        if self.deactivated_entities == []:
            entity_id = self.create_entity()
        else:
            entity_id = self.deactivated_entities.pop()
        systems = self.systems
        self.entities[entity_id]['entity_load_order'] = component_order
        for component in component_order:
            systems[component].create_component(entity_id, 
                components_to_use[component])
        return entity_id

    def timed_remove_entity(self, int entity_id, dt):
        self.remove_entity(entity_id)

    def timed_remove_entity(self, int entity_id, dt):
        self.entities_to_remove.append(entity_id)

    def remove_entity(self, int entity_id):
        cdef dict entity = self.entities[entity_id]
        cdef list components_to_delete = []
        cdef dict systems = self.systems
        cdef str data
        cdef str component
        for data in entity:
            if data == 'id':
                pass
            elif data == 'entity_load_order':
                components_to_delete.append(data)
            else:
                components_to_delete.append(data)
                systems[data].remove_entity(entity_id)
        for component in components_to_delete:
            del entity[component]
        Clock.schedule_once(partial(self.add_entity_to_deactivated, entity_id), 1.0)

    def add_entity_to_deactivated(self, int entity_id, dt):
        self.deactivated_entities.append(entity_id)

    def update(self, dt):
        cdef dict systems = self.systems
        cdef object system
        for system_name in systems:
            system = systems[system_name]
            if system.updateable and not system.paused:
                system.update(dt)
        Clock.schedule_once(self.remove_entities)

    def remove_entities(self, dt):
        for entity_id in self.entities_to_remove:
            self.remove_entity(entity_id)
            self.entities_to_remove.remove(entity_id)

    def load_entity(self, entity_dict):
        pass

    def save_entity(self, entity):
        entity_dict = {}
        return entity_dict

    def clear_entities(self):
        for entity in self.entities:
            self.remove_entity(entity['id'])

    def remove_system(self, system_id):
        systems = self.systems
        systems[system_id].on_delete_system()
        self.remove_widget(systems[system_id])
        del systems[system_id]

    def add_system(self, widget, dt):
        self.systems[widget.system_id] = widget
        widget.on_init_system()
        widget.on_add_system()

    def add_widget(self, widget):
        if isinstance(widget, GameSystem) and widget.system_id not in self.systems:
            Clock.schedule_once(partial(self.add_system, widget))
        super(GameWorld, self).add_widget(widget)
        

    def remove_widget(self, widget):
        if isinstance(widget, GameSystem):
            widget.on_remove_system()
        super(GameWorld, self).remove_widget(widget)
