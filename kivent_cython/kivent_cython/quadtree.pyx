
cdef class QuadTree(object):
    cdef float center_x
    cdef float center_y
    cdef QuadTree nw
    cdef QuadTree se
    cdef QuadTree sw
    cdef QuadTree ne
    cdef tuple bounding_rect
    cdef list items
    cdef int depth
    cdef object gameworld
    cdef object position_system
    cdef object size_system

    def __init__(self, object gameworld, object position_system, object size_system, list items, int depth=7, tuple bounding_rect=None):
        self.bounding_rect = bounding_rect
        self.center_x = 0
        self.center_y = 0
        self.nw = None
        self.se = None
        self.sw = None
        self.ne = None
        self.gameworld = gameworld
        self.position_system = position_system
        self.size_system = size_system

        depth -= 1
        self.depth = depth 
        if self.depth == 0:
            self.items = items
            return
 
        if bounding_rect:
            l, t, r, b = bounding_rect
        else:
            print 'no bounding_rect given'

        cdef float center_x = (l + r) * 0.5
        cdef float center_y = (t + b) * 0.5
        self.center_x = center_x
        self.center_y = center_y
        
        self.items = []
        cdef list nw_items = []
        cdef list ne_items = []
        cdef list se_items = []
        cdef list sw_items = []
        cdef list entities = gameworld.entities
        for entity_id in items:
            entity = entities[entity_id]
            pos = entity[position_system]['position']
            size = entity[size_system]['size']
            left = pos[0] - size[0]
            top = pos[1] + size[1]
            right = pos[0] + size[0]
            bottom = pos[1] - size[1]
            in_nw = left <= center_x and top >= center_y
            in_sw = left <= center_x and bottom <= center_y
            in_ne = right >= center_x and top >= center_y
            in_se = right >= center_x and bottom <= center_y
            if in_nw and in_ne and in_se and in_sw:
                self.items.append(entity_id)
            else:
                if in_nw: nw_items.append(entity_id)
                if in_ne: ne_items.append(entity_id)
                if in_se: se_items.append(entity_id)
                if in_sw: sw_items.append(entity_id)
            
        self.nw = QuadTree(gameworld, position_system, size_system, nw_items, depth, (l, t, center_x, center_y))
        self.ne = QuadTree(gameworld, position_system, size_system, ne_items, depth, (center_x, t, r, center_y))
        self.se = QuadTree(gameworld, position_system, size_system, se_items, depth, (center_x, center_y, r, b))
        self.sw = QuadTree(gameworld, position_system, size_system, sw_items, depth, (l, center_y, center_x, b))

    def print_trees(self):
        print 'tree: ', self.depth, self.items
        trees = [self.nw, self.ne, self.se, self.sw]
        for tree in trees:
            if tree:
                tree.print_trees()

    def remove_item(self, int item):
        cdef object position_system = self.position_system
        cdef object size_system = self.size_system
        cdef list entities = self.gameworld.entities
        cdef float center_x = self.center_x
        cdef float center_y = self.center_y
        cdef QuadTree nw = self.nw
        cdef QuadTree sw = self.sw
        cdef QuadTree ne = self.ne
        cdef QuadTree se = self.se
        cdef dict entity = entities[item]
        cdef tuple pos = entity[position_system]['position']
        cdef tuple size = entity[size_system]['size']
        cdef float item_left = pos[0] - size[0]
        cdef float item_top = pos[1] + size[1]
        cdef float item_right = pos[0] + size[0]
        cdef float item_bottom = pos[1] - size[1]

        if item in self.items:
            print 'removing item', item, 'from', self.depth
            self.items.remove(item)

        if nw and item_left <= center_x and item_top >= center_y:
            nw.remove_item(item)
        if sw and item_left <= center_x and item_bottom <= center_y:
            sw.remove_item(item)
        if ne and item_right >= center_x and item_top >= center_y:
            ne.remove_item(item)
        if se and item_right >= center_x and item_bottom <= center_y:
            se.remove_item(item)

    def remove_items(self, list list_of_items):
        for item in list_of_items:
            self.remove_item(item)

    def add_items(self, list list_of_items, int depth):
        depth -= 1
        if depth == 0:
            for item in list_of_items:
                self.items.append(item)
            return
        
        cdef list nw_items = []
        cdef list ne_items = []
        cdef list se_items = []
        cdef list sw_items = []
        cdef tuple l, t, r, b = self.bounding_rect
        cdef float center_x = self.center_x
        cdef float center_y = self.center_y

        cdef list entities = self.gameworld.entities
        cdef object position_system = self.position_system
        cdef object size_system = self.size_system

        cdef tuple pos
        cdef tuple size
        cdef float left
        cdef float top
        cdef float right
        cdef float bottom

        for entity_id in list_of_items:
            entity = entities[entity_id]
            pos = entity[position_system]['position']
            size = entity[size_system]['size']
            left = pos[0] - size[0]
            top = pos[1] + size[1]
            right = pos[0] + size[0]
            bottom = pos[1] - size[1]
            in_nw = left <= center_x and top >= center_y
            in_sw = left <= center_x and bottom <= center_y
            in_ne = right >= center_x and top >= center_y
            in_se = right >= center_x and bottom <= center_y
            if in_nw and in_ne and in_se and in_sw:
                self.items.append(entity_id)
            else:
                if in_nw: nw_items.append(entity_id)
                if in_ne: ne_items.append(entity_id)
                if in_se: se_items.append(entity_id)
                if in_sw: sw_items.append(entity_id)
        
        if nw_items:
            self.nw.add_items(nw_items, depth)
        if ne_items:
            self.ne.add_items(ne_items, depth)
        if se_items:
            self.se.add_items(se_items, depth)
        if sw_items:
            self.sw.add_items(sw_items, depth)

    def update_quads(self):
        items_to_add = self.check_items()
        self.add_items(items_to_add, self.depth)

    def check_items(self):
        cdef QuadTree sw = self.sw
        cdef QuadTree nw = self.nw
        cdef QuadTree se = self.se
        cdef QuadTree ne = self.ne
        cdef tuple l, t, r, b = self.bounding_rect
        cdef object position_system = self.position_system
        cdef object size_system = self.size_system
        cdef list entities = self.gameworld.entities

        def is_in_bounding_box(int entity_id):
            cdef dict entity = entities[entity_id]
            cdef tuple pos = entity[position_system]['position']
            cdef tuple size = entity[size_system]['size']
            cdef float item_left = pos[0] - size[0]
            cdef float item_top = pos[1] + size[1]
            cdef float item_right = pos[0] + size[0]
            cdef float item_bottom = pos[1] - size[1]

            return item_left >= l and item_right <= r and item_top <= t and item_bottom >= b 

        cdef set items_to_re_add = set(item for item in self.items if not is_in_bounding_box(item))
        for item in items_to_re_add:
            self.items.remove(item)
        if nw:
            items_to_re_add |= nw.check_items()
        if sw:
            items_to_re_add |= sw.check_items()
        if ne:
            items_to_re_add |= ne.check_items()
        if se:
            items_to_re_add |= se.check_items()
        
        return items_to_re_add


    def bb_hit(self, float right, float left, float top, float bottom):
        cdef float test_r = right
        cdef float test_l = left
        cdef float test_t = top
        cdef float test_b = bottom
        cdef object position_system = self.position_system
        cdef object size_system = self.size_system
        cdef list entities = self.gameworld.entities

        def overlaps(int entity_id):
            cdef dict entity = entities[entity_id]
            cdef tuple pos = entity[position_system]['position']
            cdef tuple size = entity[size_system]['size']
            cdef float item_left = pos[0] - size[0]
            cdef float item_top = pos[1] + size[1]
            cdef float item_right = pos[0] + size[0]
            cdef float item_bottom = pos[1] - size[1]
            return test_r >= item_left and test_l <= item_right and \
                   test_b <= item_top and test_t >= item_bottom
        
        cdef set hits = set(item for item in self.items if overlaps(item))

        cdef float center_x = self.center_x
        cdef float center_y = self.center_y
        cdef QuadTree nw = self.nw
        cdef QuadTree sw = self.sw
        cdef QuadTree ne = self.ne
        cdef QuadTree se = self.se
        if nw and test_l <= center_x and test_t >= center_y:
            hits |= nw.bb_hit(right, left, top, bottom)
        if sw and test_l <= center_x and test_b <= center_y:
            hits |= sw.bb_hit(right, left, top, bottom)
        if ne and test_r >= center_x and test_t >= center_y:
            hits |= ne.bb_hit(right, left, top, bottom)
        if se and test_r >= center_x and test_b <= center_y:
            hits |= se.bb_hit(right, left, top, bottom)
        return hits


