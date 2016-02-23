from cython cimport Py_ssize_t
from kivy.graphics.vertex cimport VertexFormat

cdef class KEVertexFormat(VertexFormat):
    cdef Py_ssize_t* attr_offsets
    cdef int* attr_normalize
    cdef object fmt

    cdef void bind(self)