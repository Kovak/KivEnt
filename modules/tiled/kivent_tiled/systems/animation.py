from fractions import gcd
from itertools import ifilter

from kivy.factory import Factory
from kivent_core.systems.gamesystem import GameSystem
from kivy.properties import ListProperty, ObjectProperty, BooleanProperty


class TiledAnimator(GameSystem):
    durations = ListProperty()
    dirty = BooleanProperty(False)
    renderer_obj = ObjectProperty(None)

    @property
    def has_animations(self):
        return bool(self.durations)

    def set_update_time(self):
        self.update_time = float(reduce(gcd, self.durations)) / 1000

    def update(self, dt):
        system_id = self.system_id
        renderer = self.renderer_obj
        renderer_id = renderer.system_id
        entities = self.gameworld.entities
        for component in ifilter(None, self.components):
            entity = entities[component.entity_id]
            animation_comp = getattr(entity, system_id)
            frame = animation_comp.current_frame
            animation_comp.timer += dt
            if animation_comp.timer >= frame.duration_seconds:
                animation_comp.timer = 0
                animation_comp.current_frame = frame = next(animation_comp.frames)
                render_comp = getattr(entity, renderer_id)
                render_comp.texture_key = frame.image
                if not self.dirty:
                    self.dirty = True

        if self.dirty:
            renderer.update_trigger()
            self.dirty = False


Factory.register('TiledAnimator', cls=TiledAnimator)
