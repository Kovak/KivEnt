from kivy.properties import StringProperty
from kivy.uix.screenmanager import ScreenManager, Screen


class GameScreenManager(ScreenManager):
    state = StringProperty('initial')

    def __init__(self, **kwargs):
        super(GameScreenManager, self).__init__(**kwargs)
        self.states = {}

    def on_state(self, instance, value):
        state_name = self.states[value]
        if state_name is not None:
            self.current = state_name


class GameScreen(Screen):
    name = StringProperty('default_screen_id')

