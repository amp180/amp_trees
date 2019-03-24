from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.ref cimport PyObject, Py_DECREF
cimport cython
from memstack cimport MemStack

@cython.final
@cython.no_gc_clear
cdef class MemStack:
    """ A preallocated stack of object references."""

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __cinit__(MemStack self, size_t size):
        """ Initialiser
        Args:
            size (long): The fixed maximum size of the stack.
        Raises:
            MemoryError: Size too large.
        Returns:
            None
        """
        self.size = size
        self.num_items = 0
        self.arr = <PyObject **> PyMem_Malloc(size * sizeof(PyObject *))
        if self.arr == NULL:
            raise MemoryError("Cannot allocate stack of size %i pointers." % size)

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __dealloc__(MemStack self):
        # Safely de-allocate the memory and decrement reference counts.
        cdef PyObject *p
        for p in self.arr[0:self.num_items]:
            Py_DECREF(<object> p)
        PyMem_Free(self.arr)
        self.num_items = 0
        self.size = 0
        self.arr = NULL

    def push(MemStack self, object obj):
        """ Push an item onto the stack.
        Args:
            obj (object): The object to push onto the stack.
        Raises:
            IndexError: Failed to push because the stack is full.
        """
        return self.c_push(obj)
    
    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def pop(MemStack self):
        """ Pop an item off the stack.
        Raises:
            IndexError: No item can be popped because the stack is empty.
        """
        return self.c_pop()

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def peek(MemStack self):
        """ Get the item from the top of the stack without removing it.
        Raises:
            IndexError: The stack is empty.
        """
        return self.c_peek()

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def copy(MemStack self) -> MemStack:
        return self.c_copy()
    
    def __bool__(MemStack self):
        return self.num_items > 0

    def __len__(MemStack self):
        return self.num_items