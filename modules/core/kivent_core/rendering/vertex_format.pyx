# cython: embedsignature=True
from kivy.graphics.vertex cimport vertex_attr_t, VertexFormat
from kivy.graphics.vertex import VertexFormatException
from cython cimport Py_ssize_t
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from kivy.graphics.shader cimport Shader
from kivy.graphics.c_opengl cimport (GL_FLOAT, GLfloat, GLsizei, GL_FALSE,
    glVertexAttribPointer ,GLvoid, GL_BYTE, GLbyte, GL_SHORT, GLshort, 
    GL_INT, GLint, GL_UNSIGNED_BYTE, GLubyte, GL_UNSIGNED_SHORT, GLushort,
    GL_UNSIGNED_INT, GLuint, GL_TRUE)
from kivy.graphics.instructions cimport getActiveContext
from kivent_core.rendering.gl_debug cimport gl_log_debug_message


cdef class KEVertexFormat(VertexFormat):
    '''VertexFormat is used to describe the layout of the vertex data stored 
    in vertex arrays/vbo's. It differs from the Kivy VertexFormat by tracking
    the offsets of the individual attributes so that you can interleave 
    non-homogenous data types.

    Supported attribute types are:
        'float': GLfloat
        'byte': GLbyte 
        'ubyte': GLubyte
        'int': GLint
        'uint': GLuint
        'short': GLshort
        'ushort': GLushort

    **Attributes: (Cython Access Only)**
        attr_offsets (Py_ssize_t*): Pointer to the array containing the 
        offsets for each attribute of the VertexFormat. Separate from 
        the rest of the data to maintain compatibility with the Kivy 
        VertexFormat.
    '''
    def __cinit__(self, size_in_bytes, *fmt):
        self.attr_offsets = NULL

    def __dealloc__(self):
        if self.vattr != NULL:
            PyMem_Free(self.vattr)
            self.vattr = NULL
        if self.attr_offsets != NULL:
            PyMem_Free(self.attr_offsets)
            self.attr_offsets = NULL

    def __init__(self, size_in_bytes, *fmt):
        '''When creating a KEVertexFormat size_in_bytes should be the sizeof
        result for the struct being used to hold vertex data. The vertex fmt 
        arg differs slightly from the one found in the default kivy by 
        including the offset in bytes of the attr in the struct. You can 
        see examples in the vertex_formats.pyx.

        Args:
            size_in_bytes (unsigned int): The sizeof of the struct being used
            to hold vertex data.

            fmt (list): List of ('vert name' (bytes), count(unsigned int), 
            'type'(str), offsetof(attr)(unsigned int)) tuples representing the 
            vertex data.
        '''
        cdef vertex_attr_t *attr
        cdef Py_ssize_t* attr_offsets
        cdef int index, size
        cdef Py_ssize_t offset
        cdef unsigned int vbytesize
        if not fmt:
            raise VertexFormatException('No format specified')
        self.fmt = fmt

        self.last_shader = None
        self.vattr_count = len(fmt)
        self.vattr = <vertex_attr_t *>PyMem_Malloc(
            sizeof(vertex_attr_t) * self.vattr_count)

        if self.vattr == NULL:
            raise MemoryError()
        self.attr_offsets = attr_offsets = <Py_ssize_t*>PyMem_Malloc(
            sizeof(Py_ssize_t)*self.vattr_count)
        if self.attr_offsets == NULL:
            raise MemoryError()
        self.attr_normalize = attr_normalize = <int*>PyMem_Malloc(
            sizeof(int)*self.vattr_count)
        if self.attr_normalize == NULL:
            raise MemoryError()

        index = 0
        for name, size, tp, offset, do_normalize in fmt:
            attr = &self.vattr[index]
            attr_offsets[index] = offset
            # fill the vertex format
            attr.per_vertex = 1
            attr.name = <bytes>name
            attr.index = 0 # will be set by the shader itself
            attr.size = size
            if do_normalize:
                attr_normalize[index] = GL_TRUE
            else:
                attr_normalize[index] = GL_FALSE

            # only float is accepted as attribute format
            if tp == b'float':
                attr.type = GL_FLOAT
                attr.bytesize = sizeof(GLfloat) * size
            elif tp == b'short':
                attr.type = GL_SHORT
                attr.bytesize = sizeof(GLshort) * size
            elif tp == b'ushort':
                attr.type = GL_UNSIGNED_SHORT
                attr.bytesize = sizeof(GLushort) * size
            elif tp == b'byte':
                attr.type = GL_BYTE
                attr.bytesize = sizeof(GLbyte) * size
            elif tp == b'ubyte':
                attr.type = GL_UNSIGNED_BYTE
                attr.bytesize = sizeof(GLubyte) * size
            elif tp == b'int':
                attr.type = GL_INT
                attr.bytesize = sizeof(GLint) * size
            elif tp == b'uint':
                attr.type = GL_UNSIGNED_INT
                attr.bytesize = sizeof(GLuint) * size
            else:
                raise VertexFormatException('Unknow format type %r' % tp)

            # adjust the size, and prepare for the next iteration.
            index += 1
            self.vsize += attr.size
        self.vbytesize = size_in_bytes

    cdef void bind(self):
        '''Responsible for making the current KEVertexFormat the active one
        by calling glVertexAttribPointer for each of the attributes'''
        cdef Shader shader = getActiveContext()._shader
        cdef vertex_attr_t *attr
        cdef vertex_attr_t* vattr = self.vattr
        cdef Py_ssize_t* offsets = self.attr_offsets
        cdef unsigned int vbytesize = self.vbytesize
        cdef int i
        shader.bind_vertex_format(self)
        gl_log_debug_message('KEVertexFormat.bind-bind_vertex_format')
        for i in xrange(self.vattr_count):
            attr = &vattr[i]
            if attr.per_vertex == 0:
                continue
            #commentout for sphinx
            glVertexAttribPointer(attr.index, attr.size, attr.type,
                    self.attr_normalize[i], <GLsizei>vbytesize, 
                    <GLvoid*><long>offsets[i])
            gl_log_debug_message('KEVertexFormat.bind-glVertexAttribPointer')
