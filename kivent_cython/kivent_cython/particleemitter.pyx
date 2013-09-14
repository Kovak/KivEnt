from kivy.properties import (NumericProperty, BooleanProperty, ListProperty, 
    StringProperty, ObjectProperty, BoundedNumericProperty)
from kivy.graphics import (Color, Callback, Rotate, PushMatrix, 
    PopMatrix, Translate, Quad, Scale, Point)
from libc.math cimport pow as power
from libc.math cimport sqrt, sin, cos, fmax, fmin
from random import random

EMITTER_TYPE_GRAVITY = 0
EMITTER_TYPE_RADIAL = 1

cdef inline double calc_distance(tuple point_1, tuple point_2):
    cdef double x_dist2 = power(point_2[0] - point_1[0], 2)
    cdef double y_dist2 = power(point_2[1] - point_1[1], 2)
    return sqrt(x_dist2 + y_dist2)

cdef inline double random_variance(double base, double variance):
    return base + variance * (random() * 2.0 - 1.0)

cdef inline list random_color_variance(list base, list variance):
    return [fmin(fmax(0.0, (random_variance(base[i], variance[i]))), 1.0) 
            for i in range(4)]

class ParticleEmitter(Widget):
    max_num_particles = NumericProperty(200)
    adjusted_num_particles = NumericProperty(200)
    life_span = NumericProperty(2)
    texture = ObjectProperty(None)
    texture_path = StringProperty(None)
    life_span_variance = NumericProperty(0)
    start_size = NumericProperty(16)
    start_size_variance = NumericProperty(0)
    end_size = NumericProperty(16)
    end_size_variance = NumericProperty(0)
    emit_angle = NumericProperty(0)
    emit_angle_variance = NumericProperty(0)
    start_rotation = NumericProperty(0)
    start_rotation_variance = NumericProperty(0)
    end_rotation = NumericProperty(0)
    end_rotation_variance = NumericProperty(0)
    emitter_x_variance = NumericProperty(100)
    emitter_y_variance = NumericProperty(100)
    gameworld = ObjectProperty(None)
    particle_manager = ObjectProperty(None)
    fbo = ObjectProperty(None)
    gravity_x = NumericProperty(0)
    gravity_y = NumericProperty(0)
    speed = NumericProperty(0)
    speed_variance = NumericProperty(0)
    radial_acceleration = NumericProperty(100)
    radial_acceleration_variance = NumericProperty(0)
    tangential_acceleration = NumericProperty(0)
    tangential_acceleration_variance = NumericProperty(0)
    max_radius = NumericProperty(100)
    max_radius_variance = NumericProperty(0)
    min_radius = NumericProperty(50)
    rotate_per_second = NumericProperty(0)
    rotate_per_second_variance = NumericProperty(0)
    start_color = ListProperty([1.,1.,1.,1.])
    start_color_variance = ListProperty([1.,1.,1.,1.])
    end_color = ListProperty([1.,1.,1.,1.])
    end_color_variance = ListProperty([1.,1.,1.,1.])
    emitter_type = NumericProperty(0)
    current_scroll = ListProperty((0, 0))
    friction = NumericProperty(0.0)
    _is_paused = BooleanProperty(False)


    def __init__(self, fbo, **kwargs):
        self.particles = list()
        self.fbo = fbo
        self.frame_time = 0
        super(ParticleEmitter, self).__init__(**kwargs)

    def on_adjusted_num_particles(self, instance, value):
        self.emission_rate = value / self.life_span

    def on_max_number_particles(self, instance, value):
        self.emission_rate = value / self.life_span

    def receive_particle(self, int entity_id):
        cdef dict entity = self.gameworld.entities[entity_id]
        cdef list particles = self.particles
        particles.append(entity_id)
        cdef dict particle_manager = entity['particle_manager']
        cdef Particle particle = particle_manager['particle']
        particle_manager['color'] = None
        particle_manager['translate'] = None
        particle_manager['scale'] = None
        particle_manager['rotate'] = None
        particle_manager['point'] = None
        self.init_particle(particle)
        self.draw_particle(entity)

    def draw_particle(self, dict entity):
        cdef dict particle_manager = entity['particle_manager']
        cdef Particle particle = particle_manager['particle']
        group_id = str(entity['id'])
        current_scroll = self.current_scroll
        cdef list color = particle.color[:]
        with self.particle_manager.canvas:
        #with self.fbo:
            PushMatrix(group=group_id)
            particle_manager['color'] = Color(color[0], color[1], 
                color[2], color[3], group=group_id)
            particle_manager['translate'] = Translate(group=group_id)
            particle_manager['scale'] = Scale(x=particle.scale, 
                y=particle.scale, group=group_id)
            particle_manager['rotate'] = Rotate(group=group_id)
            particle_manager['rotate'].set(particle.rotation, 0, 0, 1)
            particle_manager['rect'] = Point(texture=self.texture, 
                points=(0,0), group=group_id)   
            particle_manager['translate'].xy = (particle.x + 
                current_scroll[0], 
                particle.y + current_scroll[1])
            PopMatrix(group=group_id)

    def render_particle(self, dict entity):
        cdef dict particle_manager = entity['particle_manager']
        cdef Particle particle = particle_manager['particle']
        current_scroll = self.current_scroll
        particle_manager['rotate'].angle = particle.rotation
        particle_manager['scale'].x = particle.scale
        particle_manager['scale'].y = particle.scale
        particle_manager['translate'].xy = (particle.x + 
            current_scroll[0], 
            particle.y + current_scroll[1])
        particle_manager['color'].rgba = particle.color

    def free_all_particles(self):
        cdef list particles_to_free = [particle for particle in self.particles]
        cdef int entity_id
        for entity_id in particles_to_free:
            self.free_particle(entity_id)


    def free_particle(self, int entity_id):
        cdef list particles = self.particles
        self.particle_manager.canvas.remove_group(str(entity_id))
        self.particle_manager.free_particle(particles.pop(particles.index(entity_id)))

    def on_life_span(self,instance,value):
        self.emission_rate = self.max_num_particles/value

    def init_particle(self, Particle particle):
        cdef double life_span = random_variance(self.life_span, 
            self.life_span_variance)
        if life_span <= 0.0:
            return
        pos = self.pos

        particle.current_time = 0.0
        particle.total_time = life_span
        particle.x = random_variance(pos[0], self.emitter_x_variance)
        particle.y = random_variance(pos[1], self.emitter_y_variance)
        particle.start_x = pos[0]
        particle.start_y = pos[1]

        cdef double angle = random_variance(self.emit_angle, 
            self.emit_angle_variance)
        cdef double speed = random_variance(self.speed, self.speed_variance)
        particle.velocity_x = speed * cos(angle)
        particle.velocity_y = speed * sin(angle)

        particle.emit_radius = random_variance(self.max_radius, 
            self.max_radius_variance)
        particle.emit_radius_delta = (self.max_radius - 
            self.min_radius) / life_span

        particle.emit_rotation = random_variance(self.emit_angle, 
            self.emit_angle_variance)
        particle.emit_rotation_delta = random_variance(self.rotate_per_second, 
            self.rotate_per_second_variance)

        particle.radial_acceleration = random_variance(
            self.radial_acceleration, 
            self.radial_acceleration_variance)
        particle.tangent_acceleration = random_variance(
            self.tangential_acceleration, 
            self.tangential_acceleration_variance)

        cdef double start_size = random_variance(self.start_size, 
            self.start_size_variance)
        cdef double end_size = random_variance(self.end_size, 
            self.end_size_variance)

        start_size = max(0.1, start_size)
        end_size = max(0.1, end_size)

        particle.scale = start_size / 2.
        particle.scale_delta = ((end_size - start_size) / life_span) / 2.

        # colors
        cdef list start_color = random_color_variance(self.start_color[:], 
            self.start_color_variance[:])
        cdef list end_color = random_color_variance(self.end_color[:], 
            self.end_color_variance[:])

        particle.color_delta = [(end_color[i] - 
            start_color[i]) / life_span for i in range(4)]
        particle.color = start_color

        # rotation
        cdef double start_rotation = random_variance(self.start_rotation, 
            self.start_rotation_variance)
        cdef double end_rotation = random_variance(self.end_rotation, 
            self.end_rotation_variance)
        particle.rotation = start_rotation
        particle.rotation_delta = (end_rotation - start_rotation) / life_span

    def advance_particle_gravity(self, Particle particle, float passed_time):
        cdef double distance_x = particle.x - particle.start_x
        cdef double distance_y = particle.y - particle.start_y
        cdef tuple start_pos = (particle.start_x, particle.start_y)
        cdef tuple current_pos = (particle.x, particle.y)
        cdef double distance_scalar = calc_distance(start_pos, current_pos)
        if distance_scalar < 0.01:
            distance_scalar = 0.01

        cdef double radial_x = distance_x / distance_scalar
        cdef double radial_y = distance_y / distance_scalar
        cdef double tangential_x = radial_x
        cdef double tangential_y = radial_y

        radial_x *= particle.radial_acceleration
        radial_y *= particle.radial_acceleration

        cdef double new_y = tangential_x
        tangential_x = -tangential_y * particle.tangent_acceleration
        tangential_y = new_y * particle.tangent_acceleration

        particle.velocity_x += passed_time * (self.gravity_x + 
            radial_x + tangential_x)
        particle.velocity_y += passed_time * (self.gravity_y + 
            radial_y + tangential_y)

        particle.velocity_x -= particle.velocity_x * self.friction
        particle.velocity_y -= particle.velocity_y * self.friction

        particle.x += particle.velocity_x * passed_time
        particle.y += particle.velocity_y * passed_time

    def advance_particle(self, Particle particle, float passed_time):
        passed_time = min(passed_time, particle.total_time - 
            particle.current_time)
        particle.current_time += passed_time

        if self.emitter_type == EMITTER_TYPE_RADIAL:
            pos = self.pos
            particle.emit_rotation += (particle.emit_rotation_delta * 
                passed_time)
            particle.emit_radius -= particle.emit_radius_delta * passed_time
            particle.x = (pos[0] - 
                cos(particle.emit_rotation) * particle.emit_radius)
            particle.y = (pos[1] - 
                sin(particle.emit_rotation) * particle.emit_radius)

            if particle.emit_radius < self.min_radius:
                particle.current_time = particle.total_time

        else:
            self.advance_particle_gravity(particle, passed_time)

        particle.scale += particle.scale_delta * passed_time
        particle.rotation += particle.rotation_delta * passed_time

        particle.color = [particle.color[i] + particle.color_delta[i] * 
            passed_time for i in range(4)]


    def update(self, float dt):
        '''
        loop through particles
        if total_time < current_time:
            free particle
        else:
            advance_particle
        '''
        gameworld = self.gameworld
        cdef list entities = gameworld.entities
        cdef Particle particle
        cdef dict entity
        cdef list particles = self.particles
        for entity_id in particles:
            entity = entities[entity_id]
            particle = entity['particle_manager']['particle']
            if particle.total_time <= particle.current_time:
                self.free_particle(entity_id)
            else:
                self.advance_particle(particle, dt)
                self.render_particle(entity)

