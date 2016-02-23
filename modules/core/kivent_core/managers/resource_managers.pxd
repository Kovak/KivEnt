cdef class TextureManager:
    cdef dict _textures
    cdef dict _keys
    cdef dict _sizes
    cdef dict _uvs
    cdef dict _groups
    cdef dict _key_index
    cdef dict _texkey_index
    cdef int _key_count

cdef class ModelManager:
    cdef dict memory_blocks
    cdef unsigned int allocation_size
    cdef dict _models
    cdef dict _key_counts
    cdef dict _model_register
    cdef dict _svg_index