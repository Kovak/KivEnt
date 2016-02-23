import kivy
from kivy.app import App
from kivy.uix.widget import Widget
import kivent_core
from kivent_core.rendering.svg_loader import SVG
from kivy.properties import NumericProperty


class TestGame(Widget):
    entity_id = NumericProperty(None)

    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.uuids = {}
        self.gameworld.init_gameworld(
            ['position', 'poly_renderer'],
            callback=self.init_game)
        

    def init_game(self):
        self.setup_states()
        self.set_state()
        self.load_svg()

    def on_touch_move(self, touch):
        if self.entity_id is not None:
            entity = self.gameworld.entities[self.entity_id]
            position = entity.position
            position.x += touch.dx
            position.y += touch.dy


    def load_svg(self):
        model_manager = self.gameworld.model_manager
        data = model_manager.get_model_info_for_svg("tiger.svg")
        load_model_from_model_info = model_manager.load_model_from_model_info
        init_entity = self.gameworld.init_entity
        model_data = data['model_info']
        svg_name = data['svg_name']
        model_infos = []
        entity_to_copy = None
        final_infos = model_manager.combine_model_infos(model_data)
        svg_bounds = model_manager.get_center_and_bbox_from_infos(final_infos)
        center = svg_bounds['center']
        neg_center = [-center[0], -center[1]]
        for model_info in final_infos:
            model_name = load_model_from_model_info(model_info, svg_name)
            model = model_manager.models[model_name]
            print(model.vertex_count)
            model.add_all_vertex_attribute('pos', neg_center)
            create_dict = {
                'position': (300, 300),
                'poly_renderer': {'model_key': model_name},
            }
            if entity_to_copy is not None:
                create_dict['position'] = entity_to_copy
            ent = init_entity(create_dict, ['position', 'poly_renderer'])
            if entity_to_copy is None:
                entity_to_copy = self.gameworld.entities[ent]
                self.entity_id = ent




    def setup_states(self):
        self.gameworld.add_state(state_name='main', 
            systems_added=[],
            systems_removed=[], systems_paused=[],
            systems_unpaused=[],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'


class YourAppNameApp(App):
    def build(self):
        pass


if __name__ == '__main__':
    YourAppNameApp().run()
