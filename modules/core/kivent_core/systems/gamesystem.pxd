from kivent_core.uix.cwidget cimport CWidget

cdef class GameSystem(CWidget):
    cdef float _frame_time
    cdef list py_components
    cdef unsigned int component_count
    cdef object free_indices
    cdef dict copied_components