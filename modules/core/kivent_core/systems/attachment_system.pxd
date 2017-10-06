# distutils: language = c++
from kivent_core.systems.staticmemgamesystem cimport StaticMemGameSystem, MemComponent
from kivent_core.systems.position_systems cimport PositionStruct2D
from kivent_core.systems.rotate_systems cimport RotateStruct2D

from libcpp.set cimport set as cpp_set
from libcpp.unordered_set cimport unordered_set
from libcpp.queue cimport queue as cpp_queue
from libcpp.stack cimport stack
from libcpp.vector cimport vector
from cython cimport bint
from libc.stdint cimport uintptr_t

ctypedef struct RelationStruct:
    unsigned int entity_id
    cpp_set[RelationStruct*] *children
    RelationStruct *parent
    unsigned int components_index
    uintptr_t user_data
      
cdef class RelationComponent(MemComponent):
    cdef void* get_descendants(self, vector[RelationStruct*] *output) except NULL

cdef class RelationTreeSystem(StaticMemGameSystem):
    cdef unordered_set[RelationStruct*] root_nodes
    cdef unsigned int _state
    
    cdef RelationStruct* _attach_child(self, RelationStruct* parent_socket,
                       RelationStruct *child_socket) except NULL
    cdef RelationStruct* _attach_child_by_id(self, unsigned int parent_id,
                             unsigned int child_id) except NULL
                             
    cdef unsigned int _detach_child(self, RelationStruct* parent_socket) except 0
    cdef unsigned int _detach_child_by_id(self, unsigned int child_id) except 0
    
    cdef void* get_descendants(self, RelationStruct *parent, 
                               vector[RelationStruct*] *output) except NULL
    cdef void* get_topdown_iterator(self, vector[RelationStruct*] *output) except NULL
    cdef bint has_ancestor(self, RelationStruct* entity, unsigned int ancestor)
    cpdef bint has_ancestor_by_id(self, unsigned int entity_id, unsigned int ancestor)

cdef class LocalPositionSystem2D(RelationTreeSystem):
    cdef bint _allocated
    cdef vector[RelationStruct*] _work_queue
    cdef unsigned int _parent_offset
    cdef unsigned int _last_socket_state
    cdef unsigned int _update(self, float dt,
            vector[RelationStruct*] *work_queue) except 0
    cdef unsigned int _init_component(self, unsigned entity_id,
            unsigned int component_index,
            unsigned int components_index,
            RelationStruct *relation_struct) except 0
    
cdef class LocalPositionRotateSystem2D(LocalPositionSystem2D):
    pass
    