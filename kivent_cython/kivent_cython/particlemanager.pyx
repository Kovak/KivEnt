import kivyparticle
from kivy.properties import StringProperty, BooleanProperty
from math import radians


class ParticleManager(GameSystem):
    ##This widget is currently only designed to work with chipmunk based objects
    system_id = StringProperty('particle_manager')
    position_data_from = StringProperty('cymunk-physics')
    render_information_from = StringProperty('physics_renderer')
    updateable = BooleanProperty(True)

    def generate_component_data(self, dict entity_component_dict):
        for particle_effect in entity_component_dict:
            entity_component_dict[particle_effect]['particle_system'] = particle_system = kivyparticle.ParticleSystem(entity_component_dict[particle_effect]['particle_file'])
            particle_system.stop()
            entity_component_dict[particle_effect]['particle_system_on'] = False
        return entity_component_dict

    def remove_entity(self, entity_id):
        cdef list entities = self.gameworld.entities
        cdef str system_id = self.system_id
        cdef dict entity = entities[entity_id]
        cdef object particle_system 
        cdef dict particle_systems
        particle_systems = entity[self.system_id]
        for particle_effect in particle_systems:
            particle_system = particle_systems[particle_effect]['particle_system']
            particle_system.stop(clear=True)
            del particle_system
        super(ParticleManager, self).remove_entity(entity_id)

    def on_paused(self, instance, value):
        cdef list entities = self.gameworld.entities
        cdef str system_data_from = self.system_id
        cdef dict entity
        cdef dict particle_systems
        cdef object particle_system
        if value == True:
            for entity_id in self.entity_ids:
                entity = entities[entity_id]
                particle_systems = entity[system_data_from]
                for particle_effect in particle_systems:
                    particle_system = particle_systems[particle_effect]['particle_system']
                    particle_system.pause(with_clear = True)

    def update(self, dt):
        cdef dict systems = self.gameworld.systems
        cdef list entities = self.gameworld.entities
        cdef str render_information_from = self.render_information_from
        camera_pos = self.gameworld.systems[self.viewport].camera_pos
        cdef str position_data_from = self.position_data_from
        cdef str system_data_from = self.system_id
        cdef dict entity
        cdef dict particle_systems
        cdef object particle_system
        for entity_id in self.entity_ids:
            entity = entities[entity_id]
            particle_systems = entity[system_data_from]
            for particle_effect in particle_systems:
                particle_system = particle_systems[particle_effect]['particle_system']
                if entity[render_information_from]['render']:
                    if particle_systems[particle_effect]['particle_system_on']:
                        particle_system.current_scroll = camera_pos
                        particle_system.pos = self.calculate_particle_offset(entity_id, particle_effect)
                        particle_system.emit_angle = radians(entity[position_data_from]['angle'])
                        if particle_system._is_paused:
                            particle_system.resume()
                        if particle_system.emission_time <= 0:
                            particle_system.start()
                        if not particle_system in self.children:
                            self.add_widget(particle_system) 
                    elif particle_system.emission_time > 0:
                        particle_system.stop()
                elif not particle_system._is_paused:
                    particle_system.pause(with_clear = True)
                    if particle_system in self.children:
                        self.remove_widget(particle_system)

    def calculate_particle_offset(self, entity_id, particle_effect):
        cdef dict entity = self.gameworld.entities[entity_id]
        cdef dict position_data = entity[self.position_data_from]
        cdef dict system_data = entity[self.system_id]
        cdef int offset = system_data[particle_effect]['offset']
        pos = position_data['position']
        cdef dict unit_vector = position_data['unit_vector']
        cdef tuple effect_pos = (pos[0] - offset * -unit_vector['x'], pos[1] - offset * -unit_vector['y'])
        return effect_pos