from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
cimport cython

cdef class MemStack:
    cdef size_t size
    cdef size_t num_items
    cdef size_t max_depth
    cdef PyObject** arr

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline c_push(MemStack self, object obj):
        """ Push an item onto the stack.
        Args:
            obj (object): The object to push onto the stack.
        Raises:
            IndexError: Failed to push because the stack is full.
        """
        if self.num_items < self.size:
            Py_INCREF(obj)
            self.arr[self.num_items] = <PyObject *> obj
            self.num_items += 1
            if self.num_items > self.max_depth:
                self.max_depth = self.num_items
        else:
            raise IndexError("The stack is full.")

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline c_pop(MemStack self):
        """ Pop an item off the stack.
        Raises:
            IndexError: No item can be popped because the stack is empty.
        """
        if self.num_items > 0:
            obj = <object> self.arr[self.num_items-1]
            Py_DECREF(obj)
            self.num_items -= 1
            return obj
        else:
            raise IndexError("The stack is empty.")

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline c_peek(MemStack self):
        """ Get the item from the top of the stack without removing it.
        Raises:
            IndexError: The stack is empty.
        """
        if self.num_items > 0:
            return <object> self.arr[self.num_items-1]
        else:
            raise IndexError("The stack is empty.")

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline MemStack c_copy(MemStack self):
        cdef MemStack tmp = MemStack(self.size)
        tmp.num_items = self.num_items
        # copy pointers and incref
        cdef size_t i
        cdef PyObject *p
        for i in range(0, self.num_items):
            p = self.arr[i]
            Py_INCREF(<object> p)
            tmp.arr[i] = p
        return tmp