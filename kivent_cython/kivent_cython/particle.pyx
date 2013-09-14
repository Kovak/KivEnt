
cdef class Particle:
    cdef double x
    cdef double y
    cdef double rotation
    cdef double current_time
    cdef double scale
    cdef double total_time
    cdef double start_x
    cdef double start_y
    cdef double velocity_x
    cdef double velocity_y
    cdef double radial_acceleration
    cdef double tangent_acceleration
    cdef double emit_radius
    cdef double emit_radius_delta
    cdef double emit_rotation
    cdef double emit_rotation_delta
    cdef double rotation_delta
    cdef double scale_delta
    cdef list color
    cdef list color_delta 

    def __cinit__(self):
        x, y, rotation, current_time = -256, -256, 0, 0
        scale, total_time = 1.0, 0.
        start_x, start_y, velocity_x, velocity_y = 0, 0, 0, 0
        radial_acceleration, tangent_acceleration = 0, 0
        emit_radius, emit_radius_delta = 0, 0
        emit_rotation, emit_rotation_delta = 0, 0
        rotation_delta, scale_delta = 0, 0
        color = [1.0, 1.0, 1.0, 1.0]
        color_delta = [0.0, 0.0, 0.0, 0.0]
        

    property color:
        def __get__(self):
            return self.color
        def __set__(self, value):
            self.color = value

    property color_delta:
        def __get__(self):
            return self.color_delta
        def __set__(self, value):
            self.color_delta = value

    property current_time:
        def __get__(self):
            return self.current_time
        def __set__(self, value):
            self.current_time = value

    property total_time:
        def __get__(self):
            return self.total_time
        def __set__(self, value):
            self.total_time = value

    property x:
        def __get__(self):
            return self.x
        def __set__(self, value):
            self.x = value

    property y:
        def __get__(self):
            return self.y
        def __set__(self, value):
            self.y = value

    property rotation:
        def __get__(self):
            return self.rotation
        def __set__(self, value):
            self.rotation = value

    property scale:
        def __get__(self):
            return self.scale
        def __set__(self, value):
            self.scale = value

    property start_x:
        def __get__(self):
            return self.start_x
        def __set__(self, value):
            self.start_x = value

    property start_y:
        def __get__(self):
            return self.start_y
        def __set__(self, value):
            self.start_y = value

    property velocity_x:
        def __get__(self):
            return self.velocity_x
        def __set__(self, value):
            self.velocity_x = value

    property velocity_y:
        def __get__(self):
            return self.velocity_y
        def __set__(self, value):
            self.velocity_y = value

    property radial_acceleration:
        def __get__(self):
            return self.radial_acceleration
        def __set__(self, value):
            self.radial_acceleration = value

    property tangent_acceleration:
        def __get__(self):
            return self.tangent_acceleration
        def __set__(self, value):
            self.tangent_acceleration = value

    property emit_radius:
        def __get__(self):
            return self.emit_radius
        def __set__(self, value):
            self.emit_radius = value

    property emit_radius_delta:
        def __get__(self):
            return self.emit_radius_delta
        def __set__(self, value):
            self.emit_radius_delta = value

    property emit_rotation:
        def __get__(self):
            return self.emit_rotation
        def __set__(self, value):
            self.emit_rotation = value

    property emit_rotation_delta:
        def __get__(self):
            return self.emit_rotation_delta
        def __set__(self, value):
            self.emit_rotation_delta = value
            
    property rotation_delta:
        def __get__(self):
            return self.rotation_delta
        def __set__(self, value):
            self.rotation_delta = value

    property scale_delta:
        def __get__(self):
            return self.scale_delta
        def __set__(self, value):
            self.scale_delta = value