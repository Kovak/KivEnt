# cython: embedsignature=True
cdef extern from "string.h":
    void *memcpy(void *dest, void *src, size_t n)
from vertex_formats cimport VertexFormat4F, FormatConfig
from vertex_formats import vertex_format_4f, vertex_format_7f
from kivy.graphics.c_opengl cimport (GLfloat, GLbyte, GLubyte, GLint, GLuint,
    GLshort, GLushort)
from kivent_core.memory_handlers.membuffer cimport Buffer
from kivent_core.memory_handlers.block cimport MemoryBlock

def get_test_model():
    cdef Buffer index_buffer = Buffer(1024*10, 1, 1)
    index_buffer.allocate_memory()
    cdef Buffer vertex_buffer = Buffer(1024*10, 1, 1)
    vertex_buffer.allocate_memory()
    test_config = FormatConfig(vertex_format_4f, sizeof(VertexFormat4F))
    test_model = VertexModel(4, 6, test_config, index_buffer, vertex_buffer)
    return test_model

# def get_test_vertex():
#     format_dict = {}
#     for each in vertex_format_7f:
#         format_dict[each[0]] = each[1:]

#     cdef void* data_p = PyMem_Malloc(sizeof(float)*4)
#     if not data_p:
#         raise MemoryError()
#     cdef Vertex vertex = Vertex(format_dict)
#     vertex.vertex_pointer = data_p
#     return vertex

class AttributeCountError(Exception):
    pass

cdef class Vertex:
    '''
    The Vertex class allows you to interface with the underlying C structs
    representing a VertexModel's vertices from Python. It does this by 
    automatically wrapping the struct based on data from 
    kivent_core.rendering.vertex_formats. 

    You will not create a Vertex manually, instead it will typically be 
    returned from indexing into a VertexModel. For instance:

    .. code-block:: python 
    
        vertex = instance_of_VertexModel[0] #retrieve the first vertex
        pos = vertex.pos #retrieve data from a vertex
        vertex.pos = [1., 2.] #set data

    The attributes for a Vertex will depend on the actual vertex format of the
    model. See the documentation for 
    kivent_core.rendering.vertex_formats.VertexFormatRegister for more 
    information. 

    Keep in mind: When getting data from a Vertex you are retrieving a copy of 
    that data. Not the original, modifying the returned list will not affect 
    the underlying data, instead you must call set. 

    '''

    def __cinit__(self, dict format):
        self.vertex_format = format 

    def __getattr__(self, name):
        cdef int count
        cdef unsigned int offset
        cdef bytes attr_type
        cdef char* data = <char*>self.vertex_pointer
        cdef GLfloat* f_data
        cdef GLint* i_data
        cdef GLuint* ui_data
        cdef GLshort* s_data
        cdef GLushort* us_data
        cdef GLbyte* b_data
        cdef GLubyte* ub_data
        if isinstance(name, unicode):
            name = bytes(name, 'utf-8')
        if name in self.vertex_format:
            attribute_tuple = self.vertex_format[name]
            count = attribute_tuple[0]
            attr_type = attribute_tuple[1]
            offset = attribute_tuple[2]
            if attr_type == b'float':
                f_data = <GLfloat*>&data[offset]
                ret = [<float>f_data[x] for x in range(count)]
            elif attr_type == b'int':
                i_data = <GLint*>&data[offset]
                ret = [<int>i_data[x] for x in range(count)]
            elif attr_type == b'uint':
                ui_data = <GLuint*>&data[offset]
                ret = [<unsigned int>ui_data[x] for x in range(count)]
            elif attr_type == b'short':
                s_data = <GLshort*>&data[offset]
                ret = [<short>s_data[x] for x in range(count)]
            elif attr_type == b'ushort':
                us_data = <GLushort*>&data[offset]
                ret = [<unsigned short>us_data[x] for x in range(count)]
            elif attr_type == b'byte':
                b_data = <GLbyte*>&data[offset]
                ret = [<char>b_data[x] for x in range(count)]
            elif attr_type == b'ubyte':
                ub_data = <GLubyte*>&data[offset]
                ret = [<unsigned char>ub_data[x] for x in range(count)]
            else:
                raise TypeError()
            if len(ret) == 1:
                return ret[0]
            else:
                return ret
        else:
            raise AttributeError()
        
    def __setattr__(self, name, value):
        cdef int count
        cdef unsigned int offset
        cdef bytes attr_type
        cdef char* data = <char*>self.vertex_pointer
        cdef GLfloat* f_data
        cdef GLint* i_data
        cdef GLuint* ui_data
        cdef GLshort* s_data
        cdef GLushort* us_data
        cdef GLbyte* b_data
        cdef GLubyte* ub_data
        if isinstance(value, tuple):
            value = list(value)
        if not isinstance(value, list):
            value = [value]
        if isinstance(name, unicode):
            name = bytes(name, 'utf-8')
        if name in self.vertex_format:
            attribute_tuple = self.vertex_format[name]
            count = attribute_tuple[0]
            attr_type = attribute_tuple[1]
            offset = attribute_tuple[2]
            if len(value) != count:
                raise AttributeCountError('Expected list of length {count} got'
                    'list of size {length}'.format(count=count, 
                    length=len(value)))
            for x in range(count):
                if attr_type == b'float':
                    f_data = <GLfloat*>&data[offset + x*sizeof(GLfloat)]
                    f_data[0] = <GLfloat>value[x]
                elif attr_type == b'int':
                    i_data = <GLint*>&data[offset + x*sizeof(GLint)]
                    i_data[0] = <GLint>value[x]
                elif attr_type == b'uint':
                    ui_data = <GLuint*>&data[offset + x*sizeof(GLuint)]
                    ui_data[0] = <GLuint>value[x]
                elif attr_type == b'short':
                    s_data = <GLshort*>&data[offset + x*sizeof(GLshort)]
                    s_data[0] = <GLshort>value[x]
                elif attr_type == b'ushort':
                    us_data = <GLushort*>&data[offset + x*sizeof(GLushort)]
                    us_data[0] = <GLushort>value[x]
                elif attr_type == b'byte':
                    b_data = <GLbyte*>&data[offset + x*sizeof(GLbyte)]
                    b_data[0] = <GLbyte>value[x]
                elif attr_type == b'ubyte':
                    ub_data = <GLubyte*>&data[offset + x*sizeof(GLubyte)]
                    ub_data[0] = <GLubyte>value[x]
                else:
                    raise TypeError()
        else:
            raise AttributeError()


cdef class VertexModel:
    '''
    A VertexModel allows you to interact with arbitrary structs with GL types. 
    A Model is made up of 2 main parts, the vertex data associated with each 
    vertex in the model, and the indices describing how those vertices are 
    related. For instance a sprite would be represented as a 4 vertex quad, 
    with indices: [0, 1, 2, 2, 3, 0]

    The quad is constructed out of 2 triangle faces, the triangle reprsented by 
    vertices 0, 1, 2, and the triangle represented by 2, 3, 0, this looks like:

    1__2
    | /|  
    0/_3

    A Vertex can hold arbitrary data, but it will typically hold its x, y 
    position on the screen at the very least, and very often the u,v position
    mapping texture coordinates to the geometric. 

    A vertex of the model can be accessed by indexing into the object

    .. code-block:: python 

        vertex_model = VertexModel(4, 6, format_config, index_buffer, 
            vertex_buffer, 'my_model_name')
        vertex = vertex_model[0]

    This will retrieve a Vertex object that can manipulate the data of the 
    specified vertex. You should be careful about holding onto the vertex 
    objects as if you either adjust the **index_count** or **vertex_count** 
    the location in memory WILL change, and the old objects will not manipulate 
    the correct data. In addition it is possible for a VertexModel to be GC'd 
    while you keep a Vertex alive, also resulting into the Vertex manipulating 
    the wrong data.

    You can change the size of either the index or vertex data on a model, but 
    you cannot change its FormatConfig. If you need to change a model's vertex 
    format, you should instead create a new model. If you change a model, you 
    should first unbatch all entities that are using that model and then 
    rebatch them after changes have been completed. If your model is only used 
    by a single entity, the RenderComponent properties will assist in doing 
    this. 

    [Add Note about model entity tracking when implemented]

    **Attributes:**

    **Attributes: (Cython Access Only)**
        **vertices_block** (MemoryBlock): The MemoryBlock holding the vertex 
        data for this model.

        **indices_block** (MemoryBlock): The MemoryBlock holding the indices 
        data for this model.

        **index_buffer** (Buffer):  The Buffer from which we will actually 
        allocate the **indices_block**. Used when **index_count** changes.

        **vertex_buffer** (Buffer):  The Buffer from which we will actually
        allocate the **vertices_block**. Used when **vertex_count** changes.

    **Attributes:**
        **index_count** (unsigned int): The number of indices in your model. 
        Unbatch any active entities before setting and rebatch afterwards.

        **vertex_count** (unsigned int): The number of vertices in your model. 
        Unbatch any active entities before setting and rebatch afterwards.

        **name** (str): The name of this model, as kept track of by the 
        ModelManager.

        **format_config** (FormatConfig): The vertex format for this model. 
        Will be set on creation and should not be changed.

        **vertices** (list): Returns a list of Vertex objects for every vertex 
        in the model. Be careful about keeping the results around. You need to 
        retrieve a new copy of the list if you for instance change 
        **vertex_count**. You can supply a dict of key: index of vertex, value 
        dict of attribute, value pairs in order to set all vertices at once.

        For instance:

            .. code-block:: python

                model.vertices = {
                    1: {'pos': (-5., -5.), uvs: (0., 0.)},
                    2: {'pos': (-5., 5.), uvs: (0., 1.)},
                    3: {'pos': (5., 5.), uvs: (1., 1.)},
                    4: {'pos': (5., -5.), uvs: (1., 0.)},
                }

        **indices** (list): Returns a list of unsigned shorts specifying the 
        indices for this model. This is a copy of the actual data, do not 
        manipulate the returned list directly instead:

            .. code-block:: python

                vertex_model.indices = [new index data]
                
    '''
    
    def __cinit__(self, unsigned int vert_count, unsigned int index_count,
        FormatConfig config, Buffer index_buffer, Buffer vertex_buffer, 
        str name):
        self._format_config = config
        self._vertex_count = vert_count
        self._index_count = index_count
        self._name = name
        cdef MemoryBlock indices_block = MemoryBlock(
            index_count*sizeof(GLushort), sizeof(GLushort), 1)
        indices_block.allocate_memory_with_buffer(index_buffer)
        self.indices_block = indices_block
        cdef MemoryBlock vertices_block = MemoryBlock(
            vert_count*config._size, config._size, 1)
        vertices_block.allocate_memory_with_buffer(vertex_buffer)
        self.vertices_block = vertices_block
        self.index_buffer = index_buffer
        self.vertex_buffer = vertex_buffer

    def __dealloc__(self):
        if self.indices_block is not None:
            self.indices_block.remove_from_buffer()
            self.indices_block = None
        if self.vertices_block is not None:
            self.vertices_block.remove_from_buffer()
            self.vertices_block = None
        self.index_buffer = None
        self.vertex_buffer = None
        self._format_config = None

    def __getitem__(self, unsigned int index):
        cdef int vert_count = self._vertex_count
        if not index < vert_count:
            raise IndexError()
        cdef Vertex vertex = Vertex(self._format_config._format_dict)
        vertex.vertex_pointer = self.vertices_block.get_pointer(index)
        return vertex

    property index_count:

        def __set__(self, unsigned int new_count):
            cdef unsigned int old_count = self._index_count
            cdef MemoryBlock new_indices
            if new_count != old_count:
                self._index_count = new_count
                new_indices = MemoryBlock(
                    new_count*sizeof(GLushort), sizeof(GLushort), 1)
                new_indices.allocate_memory_with_buffer(self.index_buffer)
                if new_count < old_count:
                    old_count = new_count
                memcpy(<char*>new_indices.data, self.indices_block.data, 
                    old_count*sizeof(GLushort))
                self.indices_block.remove_from_buffer()
                self.indices_block = new_indices
 
        def __get__(self):
            return self._index_count

    property name:

        def __get__(self):
            return self._name

    property vertex_count:

        def __set__(self, unsigned int new_count):
            cdef unsigned int old_count = self._vertex_count
            cdef MemoryBlock new_vertices
            if new_count != old_count:
                self._vertex_count = new_count
                new_vertices = MemoryBlock(
                    new_count*self._format_config._size, 
                    self._format_config._size, 1)
                new_vertices.allocate_memory_with_buffer(self.vertex_buffer)
                if new_count < old_count:
                    old_count = new_count
                memcpy(<char*>new_vertices.data, self.vertices_block.data, 
                    old_count*self._format_config._size)
                self.vertices_block.remove_from_buffer()
                self.vertices_block = new_vertices

        def __get__(self):
            return self._vertex_count

    def free_memory(self):
        '''
        Frees the allocated memory. Do not use the VertexModel after
        free_memory has been called. Typically called internally by the 
        ModelManager.
        '''
        if self.indices_block is not None:
            self.indices_block.remove_from_buffer()
            self.indices_block = None
        if self.vertices_block is not None:
            self.vertices_block.remove_from_buffer()
            self.vertices_block = None

    def center_model(self):
        '''
        Centers the models vertices around (0, 0). Only works if the 
        vertex format has a pos method.
        '''
        cdef float top, left, right, bot, x, y
        initial_pos = self[0].pos
        top = bot = initial_pos[1]
        left = right = initial_pos[0]
        for i in range(self.vertex_count):
            x, y = self[i].pos
            if x < left:
                left = x
            elif x > right:
                right = x
            if y < bot:
                bot = y
            elif y > top:
                top = y
        bot_left = (bot, left)
        top_left = (top, left)
        bot_right = (bot, right)
        top_right = (top, right)
        center_y = bot + (top - bot) / 2.
        center_x = left + (right - left) / 2.
        self.add_all_vertex_attribute('pos', [-center_x, -center_y])
        return (center_x, center_y)


    def copy_vertex_model(self, VertexModel to_copy):
        '''Copies all the data from the provided VertexModel to this one. Will 
        possibly change **vertex_count** and **index_count** so make sure to 
        unbatch and rebatch any Entity referencing this model before and after 
        calling copy_vertex_model. If you know the models have the same counts 
        you do not need to do so. 

        Args:
            to_copy (VertexModel): The model to copy.

        '''
        self.vertex_count = to_copy._vertex_count
        self.index_count = to_copy._index_count
        self._format_config = to_copy._format_config
        memcpy(<char *>self.indices_block.data, to_copy.indices_block.data, 
            self._index_count*sizeof(GLushort))
        memcpy(<char *>self.vertices_block.data, to_copy.vertices_block.data, 
            self._vertex_count * self._format_config._size)

    def set_all_vertex_attribute(self, str attribute_name, value):
        '''
        Sets all vertices attribute to the provided value. More optimized than 
        doing the same thing on the list provided by **vertices** as only one 
        Vertex will be made and its pointer shifted.

        Args:
            attribute_name (str): The name of the attribute we will be
            modifying.

            value (any): The value or values to set the attributes of each 
            vertex to.

        '''
        cdef int vert_count = self._vertex_count
        if not attribute_name in self._format_config._format_dict:
            raise AttributeError()
        cdef Vertex vertex = Vertex(self._format_config._format_dict)
        for i from 0 <= i < vert_count:
            vertex.vertex_pointer = self.vertices_block.get_pointer(i)
            setattr(vertex, attribute_name, value)

    def add_all_vertex_attribute(self, str attribute_name, value):
        '''
        Adds value to the specified attribute of all vertices. More optimized 
        than doing the same thing on the list provided by **vertices** as only 
        one Vertex will be made and its pointer shifted.

        Args:
            attribute_name (str): The name of the attribute we will be
            modifying.

            value (any): The value or values to set the attributes of each 
            vertex to. If the attribute is an array, you can either provide 
            a separate value for each place or one value that will be added 
            to all places.

        '''
        cdef int vert_count = self._vertex_count
        if not attribute_name in self._format_config._format_dict:
            raise AttributeError()
        cdef Vertex vertex = Vertex(self._format_config._format_dict)
        for i from 0 <= i < vert_count:
            vertex.vertex_pointer = self.vertices_block.get_pointer(i)
            old_value = getattr(vertex, attribute_name)
            if isinstance(old_value, list) and isinstance(value, list):
                new_value = [x + y for x, y in zip(old_value, value)]
            elif isinstance(old_value, list) and not isinstance(value, list):
                new_value = [x + value for x in old_value]
            else:
                new_value = old_value + value
            setattr(vertex, attribute_name, new_value)

    def mult_all_vertex_attribute(self, str attribute_name, value):
        '''
        Mulitplies value to the specified attribute of all vertices. More 
        optimized than doing the same thing on the list provided by **vertices**
        as only one Vertex will be made and its pointer shifted.

        Args:
            attribute_name (str): The name of the attribute we will be
            modifying.

            value (any): The value or values to set the attributes of each 
            vertex to. If the attribute is an array, you can either provide 
            a separate value for each place or one value that will be mulitplied 
            to all places.

        '''
        cdef int vert_count = self._vertex_count
        if not attribute_name in self._format_config._format_dict:
            raise AttributeError()
        cdef Vertex vertex = Vertex(self._format_config._format_dict)
        for i from 0 <= i < vert_count:
            vertex.vertex_pointer = self.vertices_block.get_pointer(i)
            old_value = getattr(vertex, attribute_name)
            if isinstance(old_value, list) and isinstance(value, list):
                new_value = [x * y for x, y in zip(old_value, value)]
            elif isinstance(old_value, list) and not isinstance(value, list):
                new_value = [x * value for x in old_value]
            else:
                new_value = old_value * value
            setattr(vertex, attribute_name, new_value)

    def set_textured_rectangle(self, float width, float height, list uvs):
        '''
        Prepare a 4 vertex_count, 6 index_count textured quad (sprite) of 
        size: width x height. Normally called internally when creating sprites. 
        Will assume your vertex format have a 'pos' and 'uvs' array of size 2.

        Args:
            width (float): Width of the quad.

            height (float): Height of the quad

            uvs (list): Should be a list of 4 values representing the uv texture 
            coordinates of the quad. For a texture that took up the whole size 
            of the image this will be [0., 0., 1., 1.]. uv coordinates are 
            normalized inside their texture.

        '''
        self.vertex_count = 4
        self.index_count = 6
        self.indices = [0, 1, 2, 2, 3, 0]
        w = .5*width
        h = .5*height
        u0, v0, u1, v1 = uvs
        vertex1 = self[0]
        vertex1.pos = [-w, -h]
        vertex1.uvs = [u0, v0]
        vertex2 = self[1]
        vertex2.pos = [-w, h]
        vertex2.uvs = [u0, v1]
        vertex3 = self[2]
        vertex3.pos = [w, h]
        vertex3.uvs = [u1, v1]
        vertex4 = self[3]
        vertex4.pos = [w, -h]
        vertex4.uvs = [u1, v0]

    property vertices:

        def __get__(self):
            return_list = []
            cdef int i
            r_append = return_list.append
            for i in range(self._vertex_count):
                r_append(self[i])
            return return_list

        def __set__(self, dict vert_dict):
            cdef int vert_count = max(vert_dict)
            cdef int i 
            cdef dict vertex_data
            if vert_count + 1 != self._vertex_count:
                raise Exception("Provided data doesn't match internal size")
            for i in range(vert_count + 1):
                vertex_data = vert_dict[i]
                vertex = self[i]
                for key in vertex_data:
                    setattr(vertex, key, vertex_data[key])

    property format_config:

        def __get__(self):
            return self._format_config

    property indices:

        def __get__(self):
            cdef GLushort* indices = <GLushort*>self.indices_block.data
            cdef list return_list = []
            cdef int index_count = self._index_count
            r_append = return_list.append
            cdef int i
            cdef unsigned short index
            for i from 0 <= i < index_count:
                index = <unsigned short>indices[i]
                r_append(index)
            return return_list

        def __set__(self, list new_indices):
            cdef int index_count = self._index_count
            if len(new_indices) != index_count:
                raise Exception("Provided data doesn't match internal size")
            cdef GLushort* indices = <GLushort*>self.indices_block.data
            for i from 0 <= i < index_count:
                indices[i] = <GLushort>new_indices[i]