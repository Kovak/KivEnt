import kivy
from kivy.app import App
from kivy.uix.widget import Widget
import kivent_core
import kivent_particles
from kivent_core.managers.resource_managers import texture_manager

texture_manager.load_atlas('assets/stars.atlas')


class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.gameworld.init_gameworld(['position', 'scale', 'rotate',
            'color', 'particles', 'emitters', 'particles_renderer', 'renderer'],
            callback=self.init_game)

    def init_game(self):
        self.setup_states()
        self.set_state()
        self.load_emitter()

    def load_emitter(self):
        emitter_system = self.ids.emitter
        data = {'number_of_particles': 1000, 'texture': 'star3', 'paused': False,
            'pos_variance': (150., 150.), 'life_span_variance': 2.0, 'speed_variance': 50.}
        eff_id = emitter_system.load_effect_from_data(data, 'effect_test')
        comp_args = {
            'position': (200., 200.),
            'rotate': 0.,
            'emitters': ['effect_test'],
            # 'renderer': {'texture': 'star2'},
            }
        self.gameworld.init_entity(comp_args, ['position', 'rotate', 
            'emitters'])

    def setup_states(self):
        self.gameworld.add_state(state_name='main', 
            systems_added=['particles_renderer', 'renderer'],
            systems_removed=[], systems_paused=[],
            systems_unpaused=['particles_renderer', 'renderer'],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'


class YourAppNameApp(App):
    def build(self):
        pass


if __name__ == '__main__':
    YourAppNameApp().run()
