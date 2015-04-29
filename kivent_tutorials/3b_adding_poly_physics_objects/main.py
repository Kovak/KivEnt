from kivy.app import App
from kivy.uix.widget import Widget
from kivy.clock import Clock
from kivy.core.window import Window
from random import randint, choice
from math import radians, pi, sin, cos
import kivent_core
import kivent_cymunk
from kivent_core.resource_managers import texture_manager, model_manager
from kivent_core.vertmesh import VertMesh

texture_manager.load_atlas('assets/background_objects.atlas')


class TestGame(Widget):
    def __init__(self, **kwargs):
        super(TestGame, self).__init__(**kwargs)
        Clock.schedule_once(self.init_game)

    def ensure_startup(self):
        systems_to_check = ['map', 'physics', 'renderer', 
            'rotate', 'position', 'gameview']
        systems = self.gameworld.systems
        for each in systems_to_check:
            if each not in systems:
                return False
        return True

    def init_game(self, dt):
        if self.ensure_startup():
            self.setup_map()
            self.setup_states()
            self.set_state()
            self.draw_some_stuff()
            Clock.schedule_interval(self.update, 0)
        else:
            Clock.schedule_once(self.init_game)

    def destroy_created_entity(self, dt):
        ent_id = self.created_entities.pop()
        if ent_id is not None:
            self.gameworld.systems['renderer'].rebatch_entity(ent_id)

    def draw_some_stuff(self):
        self.draw_regular_polygon(8, 30., (1., 0., 0., 1.), 'tmesh')
        size = Window.size
        self.created_entities = created_entities = []
        entities = self.gameworld.entities
        for x in range(50):
            pos = (randint(0, size[0]), randint(0, size[1]))
            ent_id = self.create_asteroid(pos)
            created_entities.append(ent_id)
        vert_mesh = model_manager.vert_mesh_from_key('tmesh')
        print "vert_mesh=",vert_mesh
        print dir(vert_mesh)
        print "vert_mesh.indices=",vert_mesh.indices
        print "vert_mesh.vertex_count=",vert_mesh.vertex_count
        print "vert_mesh.index_count=",vert_mesh.index_count
        for i in range(vert_mesh.vertex_count):
			print vert_mesh[i]
        Clock.schedule_interval(self.destroy_created_entity, 1.)

    def draw_regular_polygon(self, sides, radius, color, key):
        x, y = 0., 0.
        angle = 2. * pi / sides
        all_verts = []
        all_verts_a = all_verts.append
        l_pos = list((x, y))
        l_pos.extend(l_pos)#tex coords
        l_pos.extend([0,0])#center
        l_pos.extend([0])#
        l_pos.extend(color)
        l_pos.extend([1])#scale
        all_verts_a(l_pos)
        triangles = []
        triangles_a = triangles.extend
        r = radius
        for s in range(sides):
            print s * angle
            new_pos = int(x + r * sin(s * angle)), int(y + r * cos(s * angle))
            l_pos = list(new_pos)
            l_pos.extend(new_pos)#tex coords
            l_pos.extend([0,0])#center
            l_pos.extend([0])#
            l_pos.extend(color)
            l_pos.extend([1])#scale
            print l_pos
            all_verts_a(l_pos)
            if s == sides-1:
                triangles_a((s+1, 0, 1))
            else:
                triangles_a((s+1, 0, s+2))
        render_system = self.gameworld.systems['renderer']
        vert_count = len(all_verts)
        index_count = len(triangles)
        #render_system.attribute_count = 12
        print "render_system.attribute_count=", render_system.attribute_count
        model_manager.load_mesh(render_system.attribute_count, vert_count, index_count, key)
        vert_mesh = model_manager.vert_mesh_from_key(key)
        #vert_mesh =  VertMesh(render_system.attribute_count, 
        #    vert_count, index_count)
        print "triangles"
        vert_mesh.indices = triangles
        print triangles
        print "verts"
        for i in range(vert_count):
            vert_mesh[i] = all_verts[i]
            print all_verts[i]
        return vert_mesh


    def create_asteroid(self, pos):
        x_vel = randint(-100, 100)
        y_vel = randint(-100, 100)
        angle = radians(randint(-360, 360))
        angular_velocity = radians(randint(-150, -150))
        shape_dict = {'inner_radius': 0, 'outer_radius': 32, 
            'mass': 50, 'offset': (0, 0)}
        col_shape = {'shape_type': 'circle', 'elasticity': .5, 
            'collision_type': 1, 'shape_info': shape_dict, 'friction': 1.0}
        col_shapes = [col_shape]
        physics_component = {'main_shape': 'circle', 
            'velocity': (x_vel, y_vel), 
            'position': pos, 'angle': angle, 
            'angular_velocity': angular_velocity, 
            'vel_limit': 250, 
            'ang_vel_limit': radians(200), 
            'mass': 50, 'col_shapes': col_shapes}
        create_component_dict = {'physics': physics_component, 
            'renderer': {'texture': 'asteroid1', 
            'vert_mesh_key': 'tmesh', 
            #'size': (64, 64),
            'render': True}, 
            'position': pos, 'rotate': 0, 'color': (1., 0., 0., 1.),
            'scale': 1.}
        component_order = ['position', 'rotate', 'color',
            'physics', 'renderer', 'scale']
        return self.gameworld.init_entity(create_component_dict, component_order)

    def setup_map(self):
        gameworld = self.gameworld
        print(gameworld.systems)
        gameworld.currentmap = gameworld.systems['map']

    def update(self, dt):
        self.gameworld.update(dt)
        #if len(self.gameworld.entities)>10:
		#	print dir(self.gameworld.entities[7])

    def setup_states(self):
        self.gameworld.add_state(state_name='main', 
            systems_added=['renderer'],
            systems_removed=[], systems_paused=[],
            systems_unpaused=['renderer'],
            screenmanager_screen='main')

    def set_state(self):
        self.gameworld.state = 'main'


class YourAppNameApp(App):
    def build(self):
        Window.clearcolor = (0, 0, 0, 1.)


if __name__ == '__main__':
    YourAppNameApp().run()
