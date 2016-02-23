# cython: embedsignature=True
from kivy.graphics.context cimport Context, get_context
from kivy.graphics.c_opengl cimport (GL_ARRAY_BUFFER, GL_STREAM_DRAW,
    GL_ELEMENT_ARRAY_BUFFER, glGenBuffers, glBindBuffer, glBufferData,
    glBufferSubData, glDeleteBuffers)
from kivent_core.rendering.gl_debug cimport gl_log_debug_message
from kivent_core.memory_handlers.block cimport MemoryBlock
from vertex_format cimport KEVertexFormat

cdef short V_NEEDGEN = 1 << 0
cdef short V_NEEDUPLOAD = 1 << 1
cdef short V_HAVEID = 1 << 2

class VBOTargetException(Exception):
    pass

class VBOUsageException(Exception):
    pass



cdef class FixedVBO:
    '''
    This is a VBO that has a fixed size for the amount of vertex data. While
    the MemoryBlock will hold a fixed amount of data, it is possible we will 
    upload a different amount of data per-frame to GL. This allows us to render
    up to the maximum amount that will fill MemoryBlock without having to 
    reallocate memory on the cpu side of things.
 
    **Attributes: (Cython Access Only)**
        **memory_block** (MemoryBlock): MemoryBlock holding the data for this 
        VBO.

        **usage** (int): The usage hint for this VBO, currently only 
        GL_STREAM_DRAW is supported. Pass in 'stream' when initializing.
        Any other argument will raise VBOUsageException.

        **target** (int): The target of the buffer when binding. Can be either
        GL_ARRAY_BUFFER or GL_ELEMENT_ARRAY_BUFFER at the moment. When 
        initializing pass in either 'array' or 'elements' respectively. Any 
        other argument with raise a VBOTargetException

        **flags** (short): State used by Kivy during rendering.

        **id** (GLuint): The id assigned by GL for this buffer. Returned from 
        glGenBuffers.

        **size_last_frame** (unsigned int): The number of elements rendered
        during the last frame. Used to determine whether we should 
        glBufferData or glBufferSubData when updating the vbo.

        **data_size** (unsigned int): The amount of data to be rendered next 
        frame. 

        **vertex_format** (KEVertexFormat): The object containing data about 
        the vertex format for this VBO.
    '''

    def __cinit__(self, KEVertexFormat vertex_format, MemoryBlock memory_block, 
        str usage, str target):
        '''During initialization we must pass in the KEVertexFormat for this 
        VBO, the MemoryBlock to hold the data, and the usage, and target 
        information for binding the glBuffer.
        Args:
            vertex_format (KEVertexFormat): Vertex format this vbo will use.

            memory_block (MemoryBlock): MemoryBlock that will hold this VBO
            data prior to upload to gpu.

            usage (str): Usage hint for the buffer, can be 'stream', other 
            usages will be implemented in the future.

            target (str): Target type for the buffer, can be either 'array' 
            or 'elements'.
        '''
        if target == 'array':
            self.target = GL_ARRAY_BUFFER
        elif target == 'elements':
            self.target = GL_ELEMENT_ARRAY_BUFFER
        else:
            raise VBOTargetException('Unknown type for VBO target:', target, 
                "Only accepts: 'array', 'elements'")
        if usage == 'stream':
            self.usage  = GL_STREAM_DRAW
        else:
            raise VBOUsageException('Unknown type for VBO usage:', usage,
                "Only accepts: 'stream',")
        
        self.vertex_format = vertex_format
        self.flags = V_NEEDGEN
        self.memory_block = memory_block
        self.size_last_frame = 0
        self.data_size = memory_block.real_size
        
    def __dealloc__(self):
        cdef Context context = get_context()
        if self.have_id():
            arr = context.lr_vbo
            arr.append(self.id)
            context.trigger_gl_dealloc()

    cdef int have_id(self):
        '''Used during deallocation to determine whether or not this 
        VBO need to have gl deallocation run on it.
        Return:
            int: 1 if the buffer have been assigned an id from GL else 0.'''
        return self.flags & V_HAVEID  

    cdef void generate_buffer(self):
        '''Generates the glBuffer by calling glGenBuffers and glBindBuffer
        the buffer will initially be made the entire size of **memory_block**
        and pointed at a NULL data.'''
        #commentout for sphinx
        glGenBuffers(1, &self.id)
        gl_log_debug_message('FixedVBO.generate_buffer-glGenBuffer')
        glBindBuffer(self.target, self.id)
        gl_log_debug_message('FixedVBO.generate_buffer-glBindBuffer')
        glBufferData(self.target, self.memory_block.real_size, 
            NULL, self.usage)
        gl_log_debug_message('FixedVBO.generate_buffer-glBufferData')

    cdef void update_buffer(self):
        '''Updates the buffer, uploading the latest data from **memory_block**
        If the data is the same size as the last call of **update_buffer**
        glBufferSubData will be used, if it is different glBufferData will be 
        used. If V_NEEDGEN has been set for **flags**, **generate_buffer** 
        will be called.
        '''
        #commontout for sphinx
        cdef unsigned int data_size = self.data_size
        if self.flags & V_NEEDGEN:
            self.generate_buffer()
            self.flags &= ~V_NEEDGEN
            self.flags |= V_HAVEID
        glBindBuffer(self.target, self.id)
        gl_log_debug_message('FixedVBO.update_buffer-glBindBuffer')
        if data_size != self.size_last_frame:
            glBufferData(
                self.target, data_size, self.memory_block.data, self.usage)
            gl_log_debug_message('FixedVBO.update_buffer-glBufferData')
        else:
            glBufferSubData(self.target, 0, data_size, self.memory_block.data)
            gl_log_debug_message('FixedVBO.update_buffer-glBufferSubData')
        self.size_last_frame = data_size

    cdef void bind(self):
        '''Binds this buffer for rendering, calling **update_buffer** in the 
        process. Will call the bind function of **vertex_format** if 
        target is GL_ARRAY_BUFFER.'''
        self.update_buffer()
        if self.target == GL_ARRAY_BUFFER:
            self.vertex_format.bind()

    cdef void unbind(self):
        '''Unbinds the buffer after rendering'''
        #commentout for sphinx
        glBindBuffer(self.target, 0)
        gl_log_debug_message('FixedVBO.unbind-glBindBuffer')

    cdef void return_memory(self):
        '''Will return the memory claimed by this VBO's **memory_block**.'''
        self.memory_block.remove_from_buffer()
        
    cdef void reload(self):
        '''Will flag this VBO as V_NEEDGEN, set the **size_last_frame** to 0,
        and clear the **memory_block**.'''
        self.flags = V_NEEDGEN
        self.size_last_frame = 0
        glDeleteBuffers(1, &self.id)
        gl_log_debug_message('FixedVBO.reload-glDeleteBuffers')
        if self.target == GL_ELEMENT_ARRAY_BUFFER:
            self.data_size = 0
        self.memory_block.clear()

    def __repr__(self):
        return '<FixedVBO at %x id=%r>' % (
                id(self), self.id if self.flags & V_HAVEID else None)