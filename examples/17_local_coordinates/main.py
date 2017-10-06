from kivy.app import App
from kivy.uix.widget import Widget
from kivy.uix.treeview import TreeView, TreeViewLabel
from math import radians, degrees
from kivent_core.gameworld import GameWorld, ObjectProperty
from kivent_core.managers.resource_managers import texture_manager
from kivent_core.systems.renderers import RotateRenderer
from kivent_core.systems.position_systems import PositionSystem2D
from kivent_core.systems.rotate_systems import RotateSystem2D
from kivy.properties import StringProperty, NumericProperty, ListProperty, BooleanProperty
from kivent_core.systems.attachment_system import LocalPositionRotateSystem2D
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.dropdown import DropDown
from kivy.uix.button import Button
from kivy.graphics import Color, Rectangle
from os.path import dirname, join, abspath

class AttachmentSystemDemoAPI():
    """
    This class represents a simple API for the LocalPositionRotateSystem2D system.
    It is used here to give a better overview over the relevant demo code.
    You do NOT need to wrap the AttachmentSystems in your code.
    
    The concept is the same for all other "local systems" like LocalPositionSystem2D.
    """
    def __init__(self, gameworld,
                 local_position_system="local_position",
                 local_rotation_system="local_rotate",
                 attachment_system="attachment"):
        self.local_position_system = local_position_system
        self.local_rotation_system = local_rotation_system
        self.attachment_system = gameworld.system_manager[attachment_system]
        self.entities = gameworld.entities
        self.gameworld = gameworld
        
    def attach_entity(self, child_id, parent_id):
        """
        Attach one entity to another.
        Both entities need to be part of the LocalPositionRotateSystem2D.
        Local values in root entities (entities without parent) are ignored. 
        
        You can safely attach entities already attached to an other entity.
        It will be automatically detached from the previous parent.
        """
        
        # If you create cycles in the children parent relations (a->b->a)
        # the whole subtree (a and b in this case) won't be updated anymore.
        # Normally you'd want to avoid cycles.
        attachment = getattr(self.entities[parent_id],
                             self.attachment_system.system_id)
        if attachment.has_ancestor(child_id):
            raise ValueError("Cycle in relationtree detected.")
        # Alternative:
        #if self.attachment_system.has_ancestor_by_id(parent_id, child_id):            
        self.attachment_system.attach_child(parent_id, child_id)
    
    def detach_entity(self, entity_id):
        """
        Detach a child entity from the parent.
        This will convert this entity to a root entity.
        The global systems (position, rotate) will still hold the old values.
        In other words the global position of this entity will not
        change after detaching.
        """
        attachment = getattr(self.entities[entity_id],
                             self.attachment_system.system_id)
        if not attachment.is_root:
            self.attachment_system.detach_child(entity_id)
    
    def remove_entity(self, entity_id):
        """
        Remove an entity.
        If an entity with children is removed all children will
        be detached and become root entities.
        """
        self.gameworld.remove_entity(entity_id)
    
    def remove_tree(self, entity_id):
        """
        Removes an entity and its complete children tree.
        """
        self.attachment_system.remove_subtree(entity_id)
    
    def set_local_coordinates(self, entity_id, x, y):
        """
        Accessing the global or local system components is simple.
        Just access the local or global system components
        via dot lookup.
        """
        position = getattr(self.entities[entitiy_id],
                           self.local_position_system)
        position.x = x 
        position.y = y 
    
    def get_local_coordinates(self, entity_id):
        position = getattr(self.entities[entity_id],
                           self.local_position_system)
        return (position.x, position.y)
    
    def set_local_rotation(self, entity_id, r):
        rotation = getattr(self.entities[entity_id],
                           self.local_rotation_system)
        rotation.r = radians(r)
        
    def get_local_rotation(self, entity_id):
        rotation = getattr(self.entities[entity_id],
                           self.local_rotation_system)
        return degrees(rotation.r)
    

class SimpleDropDown(BoxLayout):
    """
    Simple DropDown wrapper to make handling a bit easier.
    """
    text = StringProperty("Select one")
    row_height = NumericProperty(44)
    main_button = ObjectProperty(None)
    selected = ObjectProperty(None)
    background = ListProperty((1,1,1,1))
    
    def __init__(self, *args, **kwargs):
        super(SimpleDropDown, self).__init__()
        self._dropdown = DropDown(size_hint_x=1)
        self.orientation = "vertical"
        self._dropdown.bind(on_select=self._selected)
        with self._dropdown.canvas.before:
            self._background_rect = Color(*self.background)
            self.rect = Rectangle(size=self._dropdown.size,
                           pos=self._dropdown.pos)
        self._dropdown.bind(pos=self.on_update_rect, size=self.on_update_rect)
    
    def on_update_rect(self, instance, value):
        self.rect.pos = instance.pos
        self.rect.size = instance.size        

    def _selected(self, source, widget):
        if widget != self.selected:
            self.selected = widget
            self.main_button.text = widget.text   
        
    def on_main_button(self, _, value):
        if self.main_button:
            self.remove_widget(self.main_button)
        self.main_button = value
        self.main_button.bind(on_release=self._dropdown.open)
        
    def add_option(self, text, user_data=None):
        button = Button(text=text, size_hint_y=None, height=self.row_height)
        button._user_data = user_data
        button.bind(on_release=self._dropdown.select)
        self._dropdown.add_widget(button)
        
    def find_option(self, value, comparator=None):
        children = self._dropdown.container.children
        child = None
        for child in children:
            if comparator:
                if comparator(child, value):
                    break
            elif child.text == value:
                break
        else:
            return None
        return child
        
    def remove_option(self, value, comparator=None):
        child = self.find_option(value, comparator)
        if child:
            self._dropdown.remove_widget(child)
            
    def select_option(self, value, comparator=None):       
        child = self.find_option(value, comparator)
        if child:
            self._dropdown.select(child)


def _create_treeview_item(text, user_data=None):
    item = TreeViewLabel(
        text=text,
        is_open=True,
        size_hint = (None, None)
        )
    item._user_data = user_data
    item.size=item.texture_size
    item.text_size = item.size
    item.width = 300 # this is a bit dirty, but how else ?
    return item
        

texture_manager.load_image(join(dirname(dirname(abspath(__file__))), 'assets',
    'star3-blue.png'))


class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.entities = dict()
        self._ent_default_color = (255,255,255,255)
        self._ent_selected_color = (255,0,0,255)
        self._selected = None
        self.gameworld.init_gameworld(
            ['attachment', 'local_position', 'local_rotate', 'rotate_color_renderer', 'rotate', 'color', 'position'],
            callback=self.init_game)

    def init_game(self):
        self.setup_states()
        self.set_state()
        gamescreen = self.ids.gamescreenmanager.ids.main_screen
        self.entity_tree = gamescreen.ids.tree_view
        self.entity_dropdown = gamescreen.ids.ent_dropdown
        self.txt_local_x = gamescreen.ids.txt_local_x
        self.txt_local_y = gamescreen.ids.txt_local_y
        self.slider_rotate = gamescreen.ids.rotation_slider  
        self.entity_dropdown.add_option('None', -1)
        
        self.demoApi = AttachmentSystemDemoAPI(
            self.gameworld,
            "local_position", "local_rotate", "attachment")
                
        self.entity_tree.bind(selected_node=self.on_tree_node_selected)
        self.txt_local_x.bind(focus=self.on_position_change) 
        self.txt_local_y.bind(focus=self.on_position_change)
        self.slider_rotate.bind(
            value=self.on_rotation_change)
        
    def create_entity(self, parent_id, local_position):
        camera = self.gameworld.system_manager['camera1']
        create_component_dict = { 
            'rotate_color_renderer': {
                'texture': 'star3-blue',
                'size': (50, 50),
                'render': True
            },
            'color': self._ent_default_color,
            'position': camera.get_camera_center(),
            'rotate': 0,
            # Create root entities with 'parent':-1 or simply use an empty dict.
            # Like 'attachment': {}
            'attachment': {'parent': parent_id},
            'local_position': local_position, 
            'local_rotate': 0,
            }
        component_order = ['rotate', 'color', 
            'position', 'local_position', 'local_rotate', 'rotate_color_renderer', 'attachment']
        entity_id = self.gameworld.init_entity(create_component_dict, component_order)
        return entity_id
        
    def on_add_entity(self):
        parent = self._selected
        if parent is None:
            parent = -1
            tree_parent = None
        else:
            parent = parent.entity_id
            tree_parent = self.entities[parent][1]
        entity_id = self.create_entity(parent, (25,0), )
        entity = self.gameworld.entities[entity_id]
        ent_name = 'Item_%i' % entity_id
        tree_entry = _create_treeview_item(ent_name, entity_id)
        self.entity_tree.add_node(tree_entry, tree_parent) 
        drop_entity = self.entity_dropdown.add_option(ent_name, entity_id)
        self.entities[entity_id] = (entity, tree_entry, drop_entity)
        self.entity_tree.select_node(tree_entry)
        
    def on_select_parent(self):
        entity_id = self._selected
        if entity_id is None:
            return
        entity_id = entity_id.entity_id
        parent_id = self.entity_dropdown.selected
        self.demoApi.detach_entity(entity_id)
        tree_parent = None
        if not parent_id is None:
            parent_id = parent_id._user_data
            if parent_id != -1:
                self.demoApi.attach_entity(entity_id, parent_id)
                tree_parent = self.entities[parent_id][1]
        tree_entry = self.entities[entity_id][1]
        self.entity_tree.remove_node(tree_entry)
        self.entity_tree.add_node(tree_entry, tree_parent)      
        self.entity_tree.select_node(tree_entry)
        
    def on_position_change(self, instance, value):
        if value: # skip got focus
            return
        if self._selected is None:
            return
        entity = self._selected
        if instance == self.txt_local_x:
            entity.local_position.x = int(self.txt_local_x.text)
        else:
            entity.local_position.y = int(self.txt_local_y.text)
        
    def on_rotation_change(self, instance, value):
        if self._selected is None:
            return
        entity = self._selected
        self.demoApi.set_local_rotation(entity.entity_id, value)
        
    def on_tree_node_selected(self, _, node):
        if node is None: return
        entity_id = node._user_data
        entity = self.entities[entity_id][0]
        if entity == self._selected:
            return
        # Restore old highlights
        if not self._selected is None:
            self._selected.color.rgb = self._ent_default_color 
        entity.color.rgb = self._ent_selected_color
        # and update labels
        self._selected = entity
        x, y = self.demoApi.get_local_coordinates(entity_id)
        self.txt_local_x.text = "%i" % x
        self.txt_local_y.text = "%i" % y
        self.slider_rotate.value = self.demoApi.get_local_rotation(entity_id)
        parent_id = entity.attachment.parent
        self.entity_dropdown.select_option(
            parent_id, comparator=lambda n,v: n._user_data == v)
        self.entity_tree.select_node(node) # Restore selected state on tree
        
    def on_remove_entity(self):
        entity = self._selected
        if entity is None: return
        for child in entity.attachment.children:
            tree_entry = self.entities[child][1]
            self.entity_tree.remove_node(tree_entry)
            self.entity_tree.add_node(tree_entry)
        self.entity_tree.remove_node(self.entities[entity.entity_id][1])
        self._selected = None
        del self.entities[entity.entity_id]
        self.demoApi.remove_entity(entity.entity_id)
        
    def on_remove_entity_tree(self):
        entity = self._selected
        if entity is None: return
        for child in entity.attachment.children:
            tree_entry = self.entities[child][1]
            self.entity_tree.remove_node(tree_entry)
            del self.entities[child]
        self.entity_tree.remove_node(self.entities[entity.entity_id][1])
        self._selected = None
        del self.entities[entity.entity_id]
        self.demoApi.remove_tree(entity.entity_id)
    
    def setup_states(self):
        self.gameworld.add_state(state_name='main', 
            systems_added=['rotate_color_renderer'],
            systems_removed=[], systems_paused=[],
            systems_unpaused=['rotate_color_renderer'],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'

    
class YourAppNameApp(App):
    pass


if __name__ == '__main__':
    YourAppNameApp().run()