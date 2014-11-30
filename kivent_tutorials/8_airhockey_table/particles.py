__author__ = 'chozabu'

gameref = None

from random import random

particles = []

class particle:
    def __init__(self, ent, vel,lifespan, drag):
        self.ent=ent
        self.vel=vel
        self.lifespan=lifespan
        self.maxlifespan=lifespan
        self.drag=drag

def spawn_particles_at(pos, count=1, maxvel=10, color=(1,1,1,1), lifespan=1.,drag=.95):
    for np in range(count):
        pid = create_visual(pos, color=color)
        ent = gameref.gameworld.entities[pid]
        vel= (random()*maxvel-maxvel*.5,random()*maxvel-maxvel*.5)
        newp = particle(ent,vel,lifespan=lifespan, drag=drag)
        particles.append(newp)

def update(dt):
    global particles
    remlist=[]
    for p in particles:
        ent = p.ent
        p.vel=(p.vel[0]*p.drag, p.vel[1]*p.drag)
        ent.position.x+=p.vel[0]
        ent.position.y+=p.vel[1]
        ent.color.a=p.lifespan/p.maxlifespan
        p.lifespan-=dt
        if p.lifespan<0:
            remlist.append(p)
            gameref.gameworld.remove_entity(ent.entity_id)
    for r in remlist:
        particles.remove(r)



def create_visual(pos, color,start_scale=1.):

    create_component_dict = {
        'puck_renderer': {'texture': 'particle',
        'size': (64, 64)},
        'position': pos, 'rotate': 0, 'color': color,
        #'lerp_system': {},
        'scale':start_scale}
    component_order = ['position', 'rotate', 'color',
        'puck_renderer','scale']
    eid = gameref.gameworld.init_entity(create_component_dict,
        component_order)
    return eid