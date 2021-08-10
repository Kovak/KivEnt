from itertools import cycle
import json
import os
import signal

from kivy.logger import Logger
from kivy.vector import Vector
from Polygon import Polygon

#from debugdraw import gv

ZERO = 0.0001
def azero(f):
    """ almost zero """
    return abs(f) < ZERO

def cross(v1, v2):
    return v1.x*v2.y - v1.y*v2.x
    
def area(verts):
    area = 0.0
    for v1,v2,v3 in zip(verts, verts[1:] + verts[:1], verts[2:] + verts[:2]):
        vec1 = Vector(v2) - Vector(v1)
        vec2 = Vector(v3) - Vector(v2)

        area += cross(vec1, vec2)
    return area

def fix_winding(verts):

    poly_area = area(verts)

    if poly_area < 0:
        return verts
    else:
        return verts[::-1]

def simplify_poly(poly):
    """ sometimes, poly IS convex, but cymunk/chipmunk claims that is not. It's
        when eg. v1 x v2 are negative (then clockwise), but so small that chipmunk
        probably calculates it differently, treat them as
        counterclockwise.  In such case, such segments should be joined into
        one. 
    """

    simp_needed = True
    verts = poly[:]
    while simp_needed:
        simp_needed = False
        for v1,v2,v3 in zip(verts, verts[1:] + verts[:1], verts[2:] + verts[:2]):
            vec1 = Vector(v2) - Vector(v1)
            vec2 = Vector(v3) - Vector(v2)

            v1x2 = cross(vec1, vec2)
            if abs(v1x2) < ZERO: #almost parallel, simplify to to one 
                simp_needed = True
                verts.remove(v2) #put middle vertex in trash
                continue

    return verts

        


def is_convex(verts):
    for v1,v2,v3 in zip(verts, verts[1:] + verts[:1], verts[2:] + verts[:2]):
        vec1 = Vector(v2) - Vector(v1)
        vec2 = Vector(v3) - Vector(v2)

        cr = cross(vec1, vec2)
        if azero(cr) and vec1.dot(vec2) < 0:
            return False
        if cross(vec1, vec2) > - ZERO:
            return False

    return True


def add_polys(ppoly, triangle):
    if not ppoly:
        return triangle
    poly = ppoly[:]
    adjacent = False
    for v1,v2,v3 in zip(triangle, triangle[1:] + triangle[:1], triangle[2:] + triangle[:2]):
        if not (v1 in poly and v2 in poly):
            continue
        adjacent = True
        v1idx = poly.index(v1)
        if v1idx + 1 < len(poly) and poly[v1idx + 1] == v2:
            poly[v1idx + 1:v1idx + 1] = [v3]
            break
        elif v1idx > 0 and poly[v1idx -1] == v2:
            poly[v1idx: v1idx] = [v3]
            break
        else:
            return None
    if not adjacent: 
        return None
    poly = simplify_poly(poly)
    return poly

def calc_triangles(poly):
    opoly = Polygon(poly)
    for trisentry in opoly.triStrip():
        for triangle in zip(trisentry[:-2], trisentry[1:-1], trisentry[2:]):
            yield fix_winding(list(triangle))



def merge_triangles(poly, min_area=None):
    #if is concave, do nothing, just return poly
    if is_convex(poly):
        yield poly
        return
    triangles = list(calc_triangles(poly))
    #gv(triangles)
    remaining = []
    while triangles:
        piece = []
        for i, triangle in enumerate(triangles):
            if not is_convex(triangle):
                continue
            print "processing triangle#%s"%i
            cand = add_polys(piece, triangle)

            if cand != None and is_convex(cand):
                piece = cand
                continue
            remaining.append(triangle)
            #gv(triangles, [piece], [triangle], [triangle, piece], remaining)
        assert piece 
        assert is_convex(piece)
        assert area(piece) != 0
        yield fix_winding(piece)
        piece = []
        triangles = remaining
        remaining = []


def cached_mtr(path, cache_dir=".convexpolys", **kwargs):
    pathhash = str(hash(tuple(path + kwargs.items())))
    fname = os.path.join(cache_dir, pathhash)
    try:
        fp = open(fname, "r")
        return json.load(fp)
    except IOError:
        try: 
            os.makedirs(cache_dir)
        except OSError:
            if not os.path.isdir(cache_dir):
                raise
        fp = open(fname, "w")
        ret = list(merge_triangles(path, **kwargs))
        json.dump(ret, fp)
        fp.close()
        return ret







