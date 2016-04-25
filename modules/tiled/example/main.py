from kivy.app import App
from kivy.clock import Clock
from kivy.uix.widget import Widget
from kivy.properties import StringProperty

import kivent_core


class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.gameworld.init_gameworld(
            ['position', 'map_renderer', 'camera', 'map_animator', 'tilemap'],
            callback=self.init_game)

    def init_game(self):
        self.setup_states()
        self.set_state()
        self.ids.tilemap.init()

    def update(self, dt):
        self.gameworld.update(dt)

    def setup_states(self):
        self.gameworld.add_state(
            state_name='main',
            systems_added=['map_renderer', 'map_animator'],
            systems_removed=[],
            systems_paused=[],
            systems_unpaused=['map_renderer', 'map_animator'],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'


class DebugPanel(Widget):
    fps = StringProperty(None)

    def __init__(self, **kwargs):
        super(DebugPanel, self).__init__(**kwargs)
        Clock.schedule_once(self.update_fps)

    def update_fps(self, dt):
        self.fps = str(int(Clock.get_fps()))
        Clock.schedule_once(self.update_fps, .05)


class ExampleApp(App):
    def build(self):
        pass


if __name__ == '__main__':
    ExampleApp().run()
