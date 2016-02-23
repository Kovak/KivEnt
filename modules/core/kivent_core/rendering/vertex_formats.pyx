from cython cimport Py_ssize_t
cdef extern from "Python.h":
    ctypedef int Py_intptr_t


cdef class FormatConfig:
    '''
    FormatConfig keeps track of data describing the structure of vertex data 
    for GL. This data is needed both in the construction and submission of GL 
    VBO's and the creation of kivent_core.rendering.model.VertexModel. 

    **Attributes:**
        **format** (list): The format list description that gets used during 
        the binding of a vertex format and ultimately the glVertexAttribPointer
        calls that tells GL what our vertex data will look like.

        **format_dict** (dict): The same information as found in **format**, 
        formated so that we can more easily use it for accessing the underlying
        struct through the kivent_core.rendering.model.Vertex.

        **size** (unsigned int): The size in bytes of the actual struct.

        **name** (str): The name of this vertex format, as registered with the 
        VertexFormatRegister.

    '''

    def __cinit__(self, str format_name, list format, unsigned int size):
        self._name = format_name
        self._format = format
        self._size = size
        format_dict = {}
        for each in format:
            format_dict[each[0]] = each[1:]
        self._format_dict = format_dict

    property format_dict:
        def __get__(self):
            return self._format_dict

    property size:
        def __get__(self):
            return self._size

    property format:
        def __get__(self):
            return self._format

    property name:
        def __get__(self):
            return self._name


cdef class VertexFormatRegister:
    '''
    Registers FormatConfigs for vertex_format lists so that we can use the 
    formats throughout the engine. A global instance of this class is declared
    in the module so that you can register new vertex formats in your own code.
    If you need to register a format, do not instantiate this class instead use
    kivent_core.rendering.vertex_formats.format_registrar.

    A vertex_format list looks like:

    .. code-block:: python

        vertex_format_4f = [
            (b'pos', 2, b'float', pos_offset), 
            (b'uvs', 2, b'float', uvs_offset),
            ]

    Which in turn describes the structure:

    .. code-block:: cython

        ctypedef struct VertexFormat4F:
            GLfloat[2] pos
            GLfloat[2] uvs

    The first value in the tuple is the bytes name of the attribute, this will 
    be the name of the attribute used in your vertex shader. It does not need 
    to be the same name as the name of the attribute in the struct, but it is 
    probably easier if you do keep them consistent. The second value is the 
    count for how many values are in the array for this attribute. The third 
    is the type of the attribute. 

    Supported attribute types are:
        'float': GLfloat
        'byte': GLbyte 
        'ubyte': GLubyte
        'int': GLint
        'uint': GLuint
        'short': GLshort
        'ushort': GLushort

    Finally, the last value is where in the struct this value begins. It 
    is the equivalent of calling offsetof on your struct's attribute. 

    .. code-block:: c

        offsetof(struct VertexFormat4F, pos)

    However, in cython we do not have access tot his macro. The workaround is 
    a bit more verbose and looks like:

    .. code-block:: cython

        cdef VertexFormat4F* tmp1 = <VertexFormat4F*>NULL
        pos_offset = <Py_ssize_t> (<Py_intptr_t>(tmp1.pos) - <Py_intptr_t>(
            tmp1))

    **Attributes:**
        **vertex_formats** (dict): Dict of FormatConfig, keyed by their 
        **name**.

    '''

    def __cinit__(self):
        self._vertex_formats = {}

    def register_vertex_format(self, str format_name, list format, 
        unsigned int size):
        '''
        Call this function to register a new FormatConfig. 

        Args:
            format_name (str): Name of this format. We will use the name to 
            reference the format throughout the engine.

            format (list): List of the tuples describing the vertex format.

            size (unsigned int): Result of calling sizeof on the underlying 
            struct.

        '''
        self._vertex_formats[format_name] = FormatConfig(format_name, format,
            size)

    property vertex_formats:

        def __get__(self):
            return self._vertex_formats

format_registrar = VertexFormatRegister()

cdef VertexFormat4F* tmp1 = <VertexFormat4F*>NULL
pos_offset = <Py_ssize_t> (<Py_intptr_t>(tmp1.pos) - <Py_intptr_t>(tmp1))
uvs_offset = <Py_ssize_t> (<Py_intptr_t>(tmp1.uvs) - <Py_intptr_t>(tmp1))

vertex_format_4f = [
    (b'pos', 2, b'float', pos_offset, False), 
    (b'uvs', 2, b'float', uvs_offset, False),
    ]

format_registrar.register_vertex_format(
    'vertex_format_4f', vertex_format_4f, sizeof(VertexFormat4F)
    )

cdef VertexFormat7F* tmp2 = <VertexFormat7F*>NULL
pos_offset = <Py_ssize_t> (<Py_intptr_t>(tmp2.pos) - <Py_intptr_t>(tmp2))
uvs_offset = <Py_ssize_t> (<Py_intptr_t>(tmp2.uvs) - <Py_intptr_t>(tmp2))
rot_offset = <Py_ssize_t> (<Py_intptr_t>(&tmp2.rot) - <Py_intptr_t>(tmp2))
center_offset = <Py_ssize_t> (<Py_intptr_t>(tmp2.center) - <Py_intptr_t>(tmp2))

vertex_format_7f = [
    (b'pos', 2, b'float', pos_offset, False), 
    (b'uvs', 2, b'float', uvs_offset, False),
    (b'rot', 1, b'float', rot_offset, False),
    (b'center', 2, b'float', center_offset, False),
    ]

format_registrar.register_vertex_format(
    'vertex_format_7f', vertex_format_7f, sizeof(VertexFormat7F)
    )

cdef VertexFormat4F4UB* tmp3 = <VertexFormat4F4UB*>NULL
pos_offset = <Py_ssize_t> (<Py_intptr_t>(tmp3.pos) - <Py_intptr_t>(tmp3))
uvs_offset = <Py_ssize_t> (<Py_intptr_t>(tmp3.uvs) - <Py_intptr_t>(tmp3))
color_offset = <Py_ssize_t> (<Py_intptr_t>(tmp3.v_color) - <Py_intptr_t>(tmp3))

vertex_format_4f4ub = [
    (b'pos', 2, b'float', pos_offset, False), 
    (b'uvs', 2, b'float', uvs_offset, False),
    (b'v_color', 4, b'ubyte', color_offset, True),
    ]

format_registrar.register_vertex_format(
    'vertex_format_4f4ub',vertex_format_4f4ub, sizeof(VertexFormat4F4UB)
    )

cdef VertexFormat2F4UB* tmp4 = <VertexFormat2F4UB*>NULL
pos_offset = <Py_ssize_t> (<Py_intptr_t>(tmp4.pos) - <Py_intptr_t>(tmp4))
color_offset = <Py_ssize_t> (<Py_intptr_t>(tmp4.v_color) - <Py_intptr_t>(tmp4))

vertex_format_2f4ub = [
    (b'pos', 2, b'float', pos_offset, False), 
    (b'v_color', 4, b'ubyte', color_offset, True),
    ]

format_registrar.register_vertex_format(
    'vertex_format_2f4ub', vertex_format_2f4ub, sizeof(VertexFormat2F4UB)
    )

cdef VertexFormat7F4UB* tmp5 = <VertexFormat7F4UB*>NULL
pos_offset = <Py_ssize_t> (<Py_intptr_t>(tmp5.pos) - <Py_intptr_t>(tmp5))
uvs_offset = <Py_ssize_t> (<Py_intptr_t>(tmp5.uvs) - <Py_intptr_t>(tmp5))
rot_offset = <Py_ssize_t> (<Py_intptr_t>(&tmp5.rot) - <Py_intptr_t>(tmp5))
center_offset = <Py_ssize_t> (<Py_intptr_t>(tmp5.center) - <Py_intptr_t>(tmp5))
color_offset = <Py_ssize_t> (<Py_intptr_t>(tmp5.v_color) - <Py_intptr_t>(tmp5))

vertex_format_7f4ub = [
    (b'pos', 2, b'float', pos_offset, False), 
    (b'uvs', 2, b'float', uvs_offset, False),
    (b'rot', 1, b'float', rot_offset, False),
    (b'center', 2, b'float', center_offset, False),
    (b'v_color', 4, b'ubyte', color_offset, True),
    ]

format_registrar.register_vertex_format(
    'vertex_format_7f4ub', vertex_format_7f4ub, sizeof(VertexFormat7F4UB)
    )
