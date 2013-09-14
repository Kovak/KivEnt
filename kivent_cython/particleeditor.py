import kivy
from kivy.app import App
from kivy.uix.widget import Widget
from kivy.properties import (StringProperty, ObjectProperty, NumericProperty, 
    BooleanProperty)
from kivy.clock import Clock
from kivent_cython import (GameWorld, GameSystem, GameMap, GameView, 
    ParticleManager, QuadRenderer, PhysicsRenderer, CymunkPhysics, 
    PhysicsPointRenderer, QuadTreePointRenderer, BLEND_FUNC)
from kivy.uix.popup import Popup
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.togglebutton import ToggleButton
from kivy.graphics.opengl import (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

class Effects(GameSystem):
    system_id = StringProperty('effects')


class BlendFuncChoices(Popup):

    def __init__(self, func_chooser, **kwargs):
        super(BlendFuncChoices, self).__init__(**kwargs)
        self.func_chooser = func_chooser
        self.populate_list()
        

    def populate_list(self):
        self.src_choices_box.clear_widgets()
        self.dest_choices_box.clear_widgets()
        label = Label(text = 'Source')
        self.src_choices_box.add_widget(label)
        label = Label(text = 'Dest')
        self.dest_choices_box.add_widget(label)
        for each in BLEND_FUNC:
            
            button = ToggleButton(text = str(self.func_chooser.translate_blend_func_value(each)), font_size = self.size[0]*.12, id = str(each), group = 'func_choices')
            self.src_choices_box.add_widget(button)
            button.bind(on_press=self.press_src_button)
            if self.func_chooser.current_src == each:
                button.state = 'down'
            button = ToggleButton(text = str(self.func_chooser.translate_blend_func_value(each)), font_size = self.size[0]*.12, id = str(each), group = 'func_choices2')
            button.bind(on_press=self.press_dest_button)
            self.dest_choices_box.add_widget(button)
            if self.func_chooser.current_dest == each:
                button.state = 'down'
        

    def press_src_button(self, instance):
        self.func_chooser.set_source_text(instance.text, instance.id, instance.state)

    def press_dest_button(self, instance):
        self.func_chooser.set_dest_text(instance.text, instance.id, instance.state)
            
    

    def on_open(self):
        #self.populate_list()
        pass

class BlendFuncChooser(BoxLayout):
    func_choices = ObjectProperty(None)
    current_src = NumericProperty(GL_SRC_ALPHA)
    current_dest = NumericProperty(GL_ONE_MINUS_SRC_ALPHA)

    def __init__(self, **kwargs):
        super(BlendFuncChooser, self).__init__(**kwargs)
        Clock.schedule_once(self.setup_chooser)

    def setup_chooser(self, dt):
        self.func_choices = BlendFuncChoices(self)

    def open_popup(self):
        self.func_choices.open()

    def on_current_src(self, instance, value):
        source_text = str(self.translate_blend_func_value(self.current_src))
        dest_text = str(self.translate_blend_func_value(self.current_dest))
        self.blend_button.text = source_text + ' -> ' + dest_text

    def on_current_dest(self, instance, value):
        source_text = str(self.translate_blend_func_value(self.current_src))
        dest_text = str(self.translate_blend_func_value(self.current_dest))
        self.blend_button.text = source_text + ' -> ' + dest_text

    def set_source_text(self, text, button_id, state):
        if state == 'down':
            self.current_src = int(button_id)
            

    def set_dest_text(self, text, button_id, state):
        print 'setting dest', state
        if state == 'down':
            self.current_dest = int(button_id)

    def translate_blend_func_value(self, func_value):
        blend_func_names = {0: 'GL_ZERO',
            1: 'GL_ONE',
            0x300: 'GL_SRC_COLOR',
            0x301: 'GL_ONE_MINUS_SRC_COLOR',
            0x302: 'GL_SRC_ALPHA',
            0x303: 'GL_ONE_MINUS_SRC_ALPHA',
            0x304: 'GL_DST_ALPHA',
            0x305: 'GL_ONE_MINUS_DST_ALPHA',
            0x306: 'GL_DST_COLOR',
            0x307: 'GL_ONE_MINUS_DST_COLOR'
        }

        if func_value in blend_func_names:
            return blend_func_names[func_value]
        else:
            return func_value
            

class DebugPanel(Widget):
    fps = StringProperty(None)

    def __init__(self, **kwargs):
        super(DebugPanel, self).__init__(**kwargs)
        Clock.schedule_once(self.update_fps)

    def update_fps(self,dt):
        self.fps = str(int(Clock.get_fps()))
        Clock.schedule_once(self.update_fps, .05)


class ParticleEditor(Widget):
    def __init__(self, **kwargs):
        super(ParticleEditor, self).__init__(**kwargs)
        Clock.schedule_once(self.init_game)

    def _init_game(self, dt):
        self.setup_states()
        self.setup_particle_effects()
        self.set_state()
        Clock.schedule_interval(self.update, 1./60.)
        Clock.schedule_once(self.create_particle_effect)

    def init_game(self, dt):
        try: 
            self._init_game(0)
        except:
            print 'failed: rescheduling init'
            Clock.schedule_once(self.init_game)

    def create_particle_effect(self, dt):
        effect_string = 'assets/pexfiles/rocket_explosion_1.pex'
        particle_system = {'particle_file': effect_string, 'offset': 0}
        particle_systems = {'effect1': particle_system}
        create_dict = {'effects': {'position': (self.size[0]/2. - 100, self.size[1]/2.), 'on_screen': True, 'angle': 0.},
        'particle_manager': particle_systems}
        component_order = ['effects', 'particle_manager']
        entity_id = self.gameworld.init_entity(create_dict, component_order)
        self.gameworld.entities[entity_id]['particle_manager']['effect1']['particle_system_on'] = True

    def update(self, dt):
        self.gameworld.update(dt) 

    def setup_particle_effects(self):
        particle_effects = [
        'assets/pexfiles/rocket_burn_effect1.pex',
        'assets/pexfiles/rocket_explosion_1.pex',
        'assets/pexfiles/rocket_burn_effect2.pex',
        'assets/pexfiles/rocket_explosion_2.pex',
        'assets/pexfiles/rocket_burn_effect3.pex',
        'assets/pexfiles/rocket_explosion_3.pex',
        'assets/pexfiles/rocket_burn_effect4.pex',
        'assets/pexfiles/rocket_explosion_4.pex',
        ]
        particle_manager = self.gameworld.systems['particle_manager']
        for effect in particle_effects:
            particle_manager.load_particle_config(effect)

    def setup_states(self):
        self.gameworld.add_state(state_name='main', systems_added=[
            'particle_manager'], 
            systems_removed=[], 
            systems_paused=[], systems_unpaused=['particle_manager'],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'



class ParticleEditorApp(App):
    def build(self):
        pass


if __name__ == '__main__':
   ParticleEditorApp().run()
    # sd_card_path = os.path.dirname('/sdcard/profiles/')
    # print sd_card_path
    # if not os.path.exists(sd_card_path):
    #     print 'making directory'
    #     os.mkdir(sd_card_path)
    # print 'path: ', sd_card_path
    # cProfile.run('KivEntApp().run()', sd_card_path + '/asteroidsprof.prof')