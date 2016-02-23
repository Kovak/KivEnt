# cython: embedsignature=True
from xml.dom.minidom import parse as parse_xml
import json
from libc.math cimport trunc, sin, cos, fmin, fmax
from kivent_particles.emitter cimport ParticleEmitter
from kivent_core.systems.rotate_systems cimport RotateStruct2D
from kivent_core.systems.color_systems cimport ColorStruct
from kivent_core.systems.position_systems cimport PositionStruct2D
from kivent_core.systems.scale_systems cimport ScaleStruct2D
from kivent_core.systems.staticmemgamesystem cimport (StaticMemGameSystem, 
    MemComponent)
from kivy.properties import (StringProperty, NumericProperty, ListProperty,
    BooleanProperty, ObjectProperty)
from kivy.factory import Factory
from kivent_core.memory_handlers.zone cimport MemoryZone

include "particle_math.pxi"
include "particle_config.pxi"
    

cdef class ParticleComponent(MemComponent):
    '''The component associated with ParticleSystem

    **Attributes:**
        **entity_id** (unsigned int): The entity_id this component is currently
        associated with. Will be <unsigned int>-1 if the component is 
        unattached.

        **current_time** (float): The current time of this particle.

        **total_time** (float): The total time for this particle, when 
        current_time exceeds total_time the particle entity will be removed.

        **start_pos** (tuple): The starting position of this particle. This 
        property returns a copy of the data, not the data itself. Do not modify
        returned values directly, instead set start_pos again.

        **start_x** (float): The x component of start_pos.

        **start_y** (float): The y component of start_pos.
        
        **velocity** (tuple): The velocity of this particle. This 
        property returns a copy of the data, not the data itself. Do not modify
        returned values directly, instead set velocity again.

        **velocity_x** (float): The x component of velocity.

        **velocity_y** (float): The y component of velocity.

        **radial_acceleration** (float): The radial acceleration for this 
        particle.

        **tangential_acceleration** (float): The tangential acceleration 
        for this particle.

        **emit_radius** (float): The current location on the radius of this 
        particle, used for emitter_type 1 emitters (Radial behavior).

        **emit_radius_delta** (float): The rate of change for the emit_radius
        property.

        **rotation_delta** (float): The rate of change for the rotation of 
        this particle.

        **scale_delta** (float): The rate of change for the scale of this 
        particle.

        **emitter** (ParticleEmitter): The emitter that this particle was 
        created by.

        **color_delta** (list): The rate of change for the color of this 
        particle. Do not modify returned values directly, instead set velocity
        again.

    '''
    property entity_id:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.entity_id

    property current_time:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.current_time

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.current_time = value

    property total_time:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.total_time

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.total_time = value

    property start_x:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.start_pos[0]

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.start_pos[0] = value

    property start_y:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.start_pos[1]

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.start_pos[1] = value

    property start_pos:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return [data.start_pos[i] for i in range(2)]

        def __set__(self, value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointers
            for i in range(2):
                data.start_pos[i] = value[i]

    property velocity_x:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.velocity[0]

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.velocity[0] = value

    property velocity_y:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.velocity[1]

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.velocity[1] = value

    property velocity:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return [data.velocity[i] for i in range(2)]

        def __set__(self, value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            for i in range(2):
                data.velocity[i] = value[i]

    property radial_acceleration:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.radial_acceleration

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.radial_acceleration = value

    property tangential_acceleration:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.tangential_acceleration

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.tangential_acceleration = value

    property emit_radius:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.emit_radius

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.emit_radius = value

    property emit_radius_delta:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.emit_radius_delta

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.emit_radius_delta = value

    property rotation_delta:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.rotation_delta

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.rotation_delta = value

    property scale_delta:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return data.scale_delta

        def __set__(self, float value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            data.scale_delta = value

    property emitter:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return <ParticleEmitter>data.emitter

    property color_delta:

        def __get__(self):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            return [data.color_delta[i] for i in range(4)]

        def __set__(self, value):
            cdef ParticleStruct* data = <ParticleStruct*>self.pointer
            for i in range(4):
                data.color_delta[i] = value[i]


cdef class ParticleSystem(StaticMemGameSystem):
    '''
    Processing Depends On: ParticleSystem, PositionSystem2D, RotateSystem2D,
    ScaleSystem2D, ColorSystem

    The ParticleSystem class handles creation, removal, and updating of 
    individual particles created by an EmitterSystem.

    Be sure to set 'renderer_name' to the system_id of the PartclesRenderer 
    you want to render each particle.

    You will typically not create an entity using ParticleSystem directly,
    instead an EmitterSystem will create the particle entities for you.

    **Attributes:**

        **renderer_name** (StringProperty): The system_id of the
        PartclesRenderer the particles will use.

        **particle_zone** (StringProperty): The zone in memory particles will
        be created in.

    '''
    system_id = StringProperty('particles')
    updateable = BooleanProperty(True)
    type_size = NumericProperty(sizeof(ParticleStruct))
    component_type = ObjectProperty(ParticleComponent)
    processor = BooleanProperty(True)
    system_names = ListProperty(['particles','position', 'rotate', 'scale',
        'color'])
    renderer_name = StringProperty('particle_renderer')
    particle_zone = StringProperty('particles')

    def __init__(self, **kwargs):
        super(ParticleSystem, self).__init__(**kwargs)
        self._system_names = [x for x in self.system_names]

    cdef unsigned int create_particle(self, ParticleEmitter emitter) except -1:
        cdef list system_names = self._system_names
        cdef str renderer_name = self.renderer_name
        create_dict = {
            system_names[0]: emitter,
            system_names[1]: (0., 0.),
            system_names[2]: 0.,
            system_names[3]: 0.,
            system_names[4]: (255, 255, 255, 255),
            renderer_name: {'texture': emitter._texture},
        }
        create_order = [system_names[1], system_names[2], system_names[3], 
                        system_names[4], system_names[0], renderer_name]
        return self.gameworld.init_entity(create_dict, create_order, 
            zone=self.particle_zone)

    def on_system_names(self, instance, value):
        self._system_names = [x for x in value]

    def init_component(self, unsigned int component_index, 
        unsigned int entity_id, str zone, ParticleEmitter emitter):
        '''
        Args:
            emitter (ParticleEmitter): The emitter the particle is coming from.

        The initialization arg for a ParticleComponent is just the
        ParticleEmitter that is creating the component. Typically you will not
        initialize a particle yourself, instead EmitterSystem will call
        ParticleSystem.create_particle (a cdef'd function).
        '''
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef ParticleStruct* pointer = <ParticleStruct*>memory_zone.get_pointer(
            component_index)
        pointer.entity_id = entity_id
        pointer.emitter = <void*>emitter
        pointer.current_time = 0.0
        pointer.start_pos[0] = emitter._pos[0]
        pointer.start_pos[1] = emitter._pos[1]
        cdef float angle = random_variance(emitter._emit_angle, 
            emitter._emit_angle_variance)
        cdef float speed = random_variance(emitter._speed, 
            emitter._speed_variance)
        pointer.velocity[0] = speed * cos(angle)
        pointer.velocity[1] = speed * sin(angle)
        cdef float life_span = random_variance(emitter._life_span, 
            emitter._life_span_variance)
        while life_span <= 0.0:
            life_span = random_variance(emitter._life_span, 
                emitter._life_span_variance)
        pointer.total_time = life_span
        pointer.emit_radius = random_variance(emitter._max_radius, 
            emitter._max_radius_variance)
        pointer.emit_radius_delta = (emitter._max_radius - 
            emitter._min_radius) / life_span
        pointer.emit_rotation = angle
        pointer.emit_rotation_delta = random_variance(
            emitter._rotate_per_second, emitter._rotate_per_second_variance)
        pointer.radial_acceleration = random_variance(
            emitter._radial_acceleration, emitter._radial_acceleration_variance)
        pointer.tangential_acceleration = random_variance(
            emitter._tangential_acceleration, 
            emitter._tangential_acceleration_variance)
        cdef float start_scale = fmax(MIN_PARTICLE_SIZE, random_variance(
            emitter._start_scale, emitter._start_scale_variance))
        cdef float end_scale = fmax(MIN_PARTICLE_SIZE, random_variance(
            emitter._end_scale, emitter._end_scale_variance))
        pointer.scale_delta = (end_scale - start_scale) / life_span
        cdef unsigned char[4] start_color
        cdef unsigned char[4] end_color
        color_variance(emitter._start_color, emitter._start_color_variance, 
            start_color)
        color_variance(emitter._end_color, emitter._end_color_variance, 
            end_color)
        color_delta(start_color, end_color, pointer.color_delta, life_span)
        cdef float start_rotation = random_variance(emitter._start_rotation, 
            emitter._start_rotation_variance)
        cdef float end_rotation = random_variance(emitter._end_rotation, 
            emitter._end_rotation_variance)
        pointer.rotation_delta = (end_rotation - start_rotation) / life_span

        cdef unsigned int ent_comps_ind = self.entity_components.add_entity(
            entity_id, zone)
        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int real_index = ent_comps_ind * component_count
        cdef PositionStruct2D* pos_comp = <PositionStruct2D*>component_data[
            real_index+1]
        cdef RotateStruct2D* rotate_comp = <RotateStruct2D*>component_data[
            real_index+2]
        cdef ScaleStruct2D* scale_comp = <ScaleStruct2D*>component_data[
            real_index+3]
        cdef ColorStruct* color_comp = <ColorStruct*>component_data[
            real_index+4]
 
        #write scale, color, position, and rotate data to components
        if emitter._emitter_type == 0:
            pos_comp.x = random_variance(emitter._pos[0], 
                emitter._pos_variance[0])
            pos_comp.y = random_variance(emitter._pos[1], 
                emitter._pos_variance[1])
        elif emitter._emitter_type == 1:
            pos_comp.x = (emitter._pos[0] - cos(
                pointer.emit_rotation) * pointer.emit_radius)
            pos_comp.y = (emitter._pos[1] - sin(
                pointer.emit_rotation) * pointer.emit_radius)
        scale_comp.sx = start_scale
        scale_comp.sy = start_scale
        rotate_comp.r = start_rotation
        cdef int i
        for i in range(4):
            pointer.color[i] = <float>start_color[i]
            color_comp.color[i] = start_color[i]

    def remove_component(self, unsigned int component_index):
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef ParticleStruct* pointer = <ParticleStruct*>memory_zone.get_pointer(
            component_index)
        self.entity_components.remove_entity(pointer.entity_id)
        super(ParticleSystem, self).remove_component(component_index)

    def clear_component(self, unsigned int component_index):
        cdef MemoryZone memory_zone = self.imz_components.memory_zone
        cdef ParticleStruct* pointer = <ParticleStruct*>memory_zone.get_pointer(
            component_index)
        pointer.entity_id = -1
        pointer.current_time = 0.
        pointer.total_time = 0.
        cdef int i 
        for i in range(2):
            pointer.start_pos[i] = 0.
            pointer.velocity[i] = 0.
        pointer.radial_acceleration = 0.
        pointer.tangential_acceleration = 0.
        pointer.emit_radius = 0.
        pointer.emit_radius_delta = 0.
        pointer.emit_rotation = 0.
        pointer.emit_rotation_delta = 0.
        pointer.rotation_delta = 0.
        pointer.scale_delta = 0.
        pointer.emitter = NULL
        for i in range(4):
            pointer.color_delta[i] = 0.
            pointer.color[i] = 255.

    def update(self, float dt):
        cdef ParticleEmitter emitter
        cdef float passed_time, total_time
        cdef float start_x, start_y
        cdef float current_x, current_y
        cdef float distance_x, distance_y
        cdef float distance_scalar
        cdef float radial_x, radial_y
        cdef float rad_accel
        cdef float tangential_x, tangential_y
        cdef float new_y
        cdef float tan_accel

        cdef void** component_data = <void**>(
            self.entity_components.memory_block.data)
        cdef unsigned int component_count = self.entity_components.count
        cdef unsigned int count = self.entity_components.memory_block.count
        cdef unsigned int i, real_index

        cdef ParticleStruct* particle_comp
        cdef PositionStruct2D* pos_comp
        cdef RotateStruct2D* rotate_comp
        cdef ScaleStruct2D* scale_comp
        cdef ColorStruct* color_comp

        gameworld = self.gameworld
        remove_entity = gameworld.remove_entity
        for i in range(count):
            real_index = i*component_count
            if component_data[real_index] == NULL:
                continue
            particle_comp = <ParticleStruct*>component_data[real_index]
            pos_comp = <PositionStruct2D*>component_data[real_index+1]
            rotate_comp = <RotateStruct2D*>component_data[real_index+2]
            scale_comp = <ScaleStruct2D*>component_data[real_index+3]
            color_comp = <ColorStruct*>component_data[real_index+4]
            passed_time = fmin(dt, 
                particle_comp.total_time - particle_comp.current_time)
            emitter = <ParticleEmitter>particle_comp.emitter
            particle_comp.current_time += passed_time

            if emitter._emitter_type == EMITTER_TYPE_RADIAL:
                particle_comp.emit_rotation += (
                    particle_comp.emit_rotation_delta * passed_time)
                particle_comp.emit_radius -= (
                    particle_comp.emit_radius_delta * passed_time)
                pos_comp.x = (emitter._pos[0] - cos(
                    particle_comp.emit_rotation) * particle_comp.emit_radius)
                pos_comp.y = (emitter._pos[1] - sin(
                    particle_comp.emit_rotation) * particle_comp.emit_radius)

                if particle_comp.emit_radius < emitter._min_radius:
                    particle_comp.current_time = particle_comp.total_time
            else:
                start_x = particle_comp.start_pos[0]
                start_y = particle_comp.start_pos[1]
                current_x = pos_comp.x
                current_y = pos_comp.y
                distance_x = current_x - start_x
                distance_y = current_y - start_y
                distance_scalar = calc_distance(start_x, start_y, 
                    current_x, current_y)
                if distance_scalar < 0.01:
                    distance_scalar = 0.01
                radial_x = distance_x / distance_scalar
                radial_y = distance_y / distance_scalar
                tangential_x = radial_x
                tangential_y = radial_y
                rad_accel = particle_comp.radial_acceleration
                radial_x *= rad_accel
                radial_y *= rad_accel
                new_y = tangential_x
                tan_accel = particle_comp.tangential_acceleration
                tangential_x = -tangential_y * tan_accel
                tangential_y = new_y * tan_accel
                particle_comp.velocity[0] += passed_time * (
                    emitter._gravity[0] + radial_x + tangential_x)
                particle_comp.velocity[1] += passed_time * (
                    emitter._gravity[1] + radial_y + tangential_y)
                pos_comp.x += particle_comp.velocity[0] * passed_time
                pos_comp.y += particle_comp.velocity[1] * passed_time

            scale_comp.sx += particle_comp.scale_delta * passed_time
            scale_comp.sy += particle_comp.scale_delta * passed_time
            rotate_comp.r += particle_comp.rotation_delta * passed_time
            color_integrate(particle_comp.color, particle_comp.color_delta, 
                particle_comp.color, passed_time)
            color_copy(particle_comp.color, color_comp.color)
            if particle_comp.current_time >= particle_comp.total_time:
                emitter._current_particles -= 1
                emitter.active_particles.remove(particle_comp.entity_id)
                remove_entity(particle_comp.entity_id)



Factory.register('ParticleSystem', cls=ParticleSystem)
