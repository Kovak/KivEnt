import kivy
from kivy.app import App
from kivy.uix.widget import Widget
import kivent_core
from kivy.properties import NumericProperty, StringProperty
from math import pi, cos, sin


def get_triangle_data(side_length):
    return {
        'vertices': {0: {'pos': (-side_length/2., -side_length/2.),
                         'v_color': (255, 0, 0, 255)},
                     1: {'pos': (side_length/2., -side_length/2.),
                         'v_color': (0, 255, 0, 255)},
                     2: {'pos': (0., side_length/2.),
                         'v_color': (0, 0, 255, 255)},
                    },
        'indices': [0, 1, 2],
        'vertex_count': 3,
        'index_count': 3,
        }

def get_rectangle_data(height, width):
    return {
        'vertices': {0: {'pos': (-width/2., -height/2.),
                         'v_color': (255, 0, 0, 255)},
                     1: {'pos': (-width/2., height/2.),
                         'v_color': (0, 255, 0, 255)},
                     2: {'pos': (width/2., height/2.),
                         'v_color': (0, 0, 255, 255)},
                     3: {'pos': (width/2., -height/2.),
                         'v_color': (255, 0, 255, 255)}
                    },
        'indices': [0, 1, 2, 2, 3, 0],
        'vertex_count': 4,
        'index_count': 6,
        }

def get_regular_polygon(sides, r, middle_color, edge_color, pos=(0., 0.)):
    x, y = pos
    angle = 2 * pi / sides
    all_verts = {}
    all_verts[0] = {'pos': pos, 'v_color': middle_color}

    i = 0
    indices = []
    vert_count = 1
    ind_count = 0
    ind_ext = indices.extend 
    c = 1
    for s in range(sides):
        new_pos = [x + (r * sin(s * angle)), y + (r * cos(s * angle))]
        all_verts[vert_count] = {'pos': new_pos, 'v_color': edge_color}
        vert_count += 1
        if c < sides:
            ind_ext((c, 0, c+1))
        else:
            ind_ext((c, 0, 1))
        ind_count += 3
        c += 1
    return {'indices': indices, 'vertices': all_verts, 
            'vertex_count': vert_count, 'index_count': ind_count}

def get_layered_regular_polygon(levels, sides, middle_color,
                                radius_color_dict, pos=(0., 0.)):
    '''
    radius_color_dict = {level#: (r, (r,g,b,a))}
    '''
    x, y = pos
    angle = 2 * pi / sides
    all_verts = {}
    all_verts[0] = {'pos': pos, 'v_color': middle_color}
    r_total = 0
    i = 0
    indices = []
    vert_count = 1
    ind_count = 0
    ind_ext = indices.extend 
    for count in range(levels):
        level = i + 1
        r, color = radius_color_dict[level]
        for s in range(sides):
            new_pos = list((x + (r + r_total) * sin(s * angle), 
                y + (r + r_total) * cos(s * angle)))
            all_verts[vert_count] = {'pos': new_pos, 'v_color': color}
            vert_count += 1
        r_total +=  r
        c = 1 #side number we are on in loop
        if level == 1:
            for each in range(sides):
                if c < sides:
                    ind_ext((c, 0, c+1))
                else:
                    ind_ext((c, 0, 1))
                ind_count += 3
                c += 1
        else:
            for each in range(sides):
                offset = sides*(i-1)
                if c < sides:
                    ind_ext((c+sides+offset, c+sides+1+offset, c+offset))
                    ind_ext((c+offset, c+1+offset, c+sides+1+offset))
                else:
                    ind_ext((c+sides+offset, sides+1+offset, sides+offset))
                    ind_ext((sides+offset, 1+offset, sides+1+offset))
                ind_count += 6
                c += 1
        i += 1
    return {'indices': indices, 'vertices': all_verts, 
            'vertex_count': vert_count, 'index_count': ind_count}



class TestGame(Widget):
    entity_id = NumericProperty(None)
    shape_to_draw = StringProperty(None, allownone=True)


    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        self.shapes = {}
        self.gameworld.init_gameworld(
            ['position', 'poly_renderer'],
            callback=self.init_game)
        

    def init_game(self):
        self.setup_states()
        self.set_state()
        self.load_shapes()

    def create_shape(self, pos, shape_name):
        create_dict = {
            'position': pos,
            'poly_renderer': {'model_key': self.shapes[shape_name]},
            }
        return self.gameworld.init_entity(create_dict, 
                                          ['position', 'poly_renderer'])

    def on_touch_down(self, touch):
        super(TestGame, self).on_touch_down(touch)
        if not self.ids.button_tray.collide_point(touch.x, touch.y):
            if self.shape_to_draw is not None:
                self.create_shape(touch.pos, self.shape_to_draw)


    def draw_shape_callback(self, shape_type):
        self.shape_to_draw = shape_type

    def stop_drawing(self):
        self.shape_to_draw = None

    def clear(self):
        self.gameworld.clear_entities()

    def load_shapes(self):
        model_manager = self.gameworld.model_manager
        init_entity = self.gameworld.init_entity
        triangle_data = get_triangle_data(150.)
        triangle_model = model_manager.load_model(
                                            'vertex_format_2f4ub',
                                            triangle_data['vertex_count'],
                                            triangle_data['index_count'],
                                            'triangle',
                                            indices=triangle_data['indices'],
                                            vertices=triangle_data['vertices']
                                            )
        self.shapes['triangle_model'] = triangle_model
        rectangle_data = get_rectangle_data(100., 150.)
        rectangle_model = model_manager.load_model(
                                            'vertex_format_2f4ub',
                                            rectangle_data['vertex_count'],
                                            rectangle_data['index_count'],
                                            'rectangle',
                                            indices=rectangle_data['indices'],
                                            vertices=rectangle_data['vertices']
                                            )
        self.shapes['rectangle_model'] = rectangle_model
        circle_data = get_regular_polygon(32, 150., (255, 255, 0, 255), 
                                          (45, 0, 125, 255))
        circle_model = model_manager.load_model(
                                            'vertex_format_2f4ub',
                                            circle_data['vertex_count'],
                                            circle_data['index_count'],
                                            'circle',
                                            indices=circle_data['indices'],
                                            vertices=circle_data['vertices'],
                                            )
        self.shapes['circle_model'] = circle_model
        layered_circle_data = get_layered_regular_polygon(
                                            2, 32, 
                                            (255, 0, 255, 255),
                                            {1: (75., (255, 0, 0, 255)),
                                             2: (5., (255, 255, 255, 0))}
                                            )
        layered_circle_model = model_manager.load_model(
                                    'vertex_format_2f4ub',
                                    layered_circle_data['vertex_count'],
                                    layered_circle_data['index_count'],
                                    'layered_circle',
                                    vertices=layered_circle_data['vertices'],
                                    indices=layered_circle_data['indices']
                                    )
        self.shapes['layered_circle_model'] = layered_circle_model


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
