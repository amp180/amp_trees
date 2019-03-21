#!python
#cython: language_level=3

from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from cpython.weakref cimport PyWeakref_CheckRef, PyWeakref_NewRef, PyWeakref_GetObject
cimport cython


@cython.final
@cython.no_gc_clear
cdef class _MemStack():
    """ A preallocated stack of object references.
    Args:
        size (long): The fixed maximum size of the stack.
    Raises:
        MemoryError: Size too large.
    """
    cdef:
        size_t size
        size_t num_items
        PyObject** arr

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __cinit__(_MemStack self, size_t size):
        self.size = size
        self.num_items = 0
        self.arr = <PyObject **> PyMem_Malloc(size * sizeof(PyObject *))
        if self.arr == NULL:
            raise MemoryError("Cannot allocate stack of size %i pointers." % size)

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def __dealloc__(_MemStack self):
        # Safely de-allocate the memory and decrement reference counts.
        cdef PyObject *p
        for p in self.arr[0:self.num_items]:
            Py_DECREF(<object> p)
        PyMem_Free(self.arr)
        self.num_items = 0
        self.size = 0
        self.arr = NULL

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef inline push(_MemStack self, object obj):
        """ Push an item onto the stack.
        Args:
            obj (object): The object to push onto the stack.
        Raises:
            IndexError: Failed to push because the stack is full.
        """
        if self.num_items < self.size:
            Py_INCREF(obj)
            self.arr[self.num_items] = <PyObject *> obj        self._insert(key, value)

            self.num_items += 1
        else:
            raise IndexError("The stack is full.")

    @cython.nonecheck(False)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef inline object pop(_MemStack self):
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
    cpdef inline peek(_MemStack self):
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
    cpdef _MemStack copy(_MemStack self):
        cdef _MemStack tmp = _MemStack(self.size)
        tmp.num_items = self.num_items
        # copy pointers and incref
        cdef size_t i
        cdef PyObject *p
        for i in range(0, self.num_items):
            p = self.arr[i]
            Py_INCREF(<object> p)
            tmp.arr[i] = p
        return tmp

    def __bool__(_MemStack self):
        return self.num_items > 0

    def __len__(_MemStack self):
        return self.num_items


cdef inline bool size_t_max(size_t a, size_t b) nogil:
    return a if a > b else b


#@cython.trashcan(True)
@cython.no_gc_clear
@cython.final
cdef class _Node():
    cdef:
        _Node left
        _Node right
        object key
        object value
        object parent_ref
        size_t left_tree_size
        size_t right_tree_size
        size_t depth
        cdef object __weakref__


@cython.no_gc_clear
@cython.final
cdef class OrderedTreeDict():
    """ A dict based on an ordered statistic tree. """
    cdef _Node root
    cdef object __weakref__

    @cython.nonecheck(False)
    def __cinit__(OrderedTreeDict self, object iterable=None, **kwargs):
        if iterable:
             self.update(iterable)
        if kwargs:
             self.update(kwargs)

    @cython.nonecheck(False)
    cdef inline _get(OrderedTreeDict self, object key):
        cdef _Node node = self.root
        while node is not None:
            if key < node.key:
                node = node.left
            elif key > node.key:
                node = node.right
            else:
                break
        if node is None:
            raise KeyError("Key not present.")
        return node.value

    @cython.nonecheck(False)
    def get(OrderedTreeDict self, object key, default=None):
        try:
            return self._get(key)
        except KeyError:
            return default

    @cython.nonecheck(False)
    cdef inline _rotate_left(OrderedTreeDict self, _Node pivot):
        #cdef _Node left_node = pivot.left
        pass
        
    @cython.nonecheck(False)
    cdef inline _rotate_right(OrderedTreeDict self, _Node pivot):
        #cdef _Node right_node = pivot.right
        pass

    @cython.nonecheck(False)
    cdef inline _insert(OrderedTreeDict self, object key, object value, replace=True):
        cdef _Node insertion_node, next_node, new_node, parent_node
        cdef _MemStack stack
        # Find insertion point
        next_node = self.root
        while next_node is not None:
            insertion_node = next_node
            if key < insertion_node.key:
                next_node = insertion_node.left
            elif key > insertion_node.key:
                next_node = insertion_node.right
            else: # key == insertion_node.key
                break
        # Handle existing node if present.
        if next_node is not None:
            if replace:
                # Replace value of existing node
                next_node.value = value
                return
            else:
                # No-op
                return

        # Create new node
        new_node = _Node()
        new_node.key = key
        new_node.value = value
        new_node.depth = 0
        new_node.left_tree_size = 0
        new_node.right_tree_size = 0
        
        # Insert at the correct place in the tree
        if insertion_node is None:
            # No other nodes in tree
            self.root = new_node
            new_node.parent_ref = None
            return
        else:
            new_node.parent_ref = PyWeakref_NewRef(insertion_node, None)
            if value < insertion_node.value:
                # insert left
                insertion_node.left = new_node
                insertion_node.left_tree_size += 1
            else:
                # insert right
                insertion_node.right = new_node
                insertion_node.right_tree_size += 1
        
        cdef parent_node = insertion_node
        # Propagate information through the tree
        if parent_node.left is not None ^ parent_node.right is not None:
            # New node doesn't have a sibling, depth has changed.
            parent_node.depth += 1
            while parent_node:
                parent_node = PyWeakref_GetObject(parent_node.parent_ref) if PyWeakref_CheckRef(parent_node.parent_ref) else None
                
                cdef next_left_depth = size_t_max(parent_node.)


    @cython.nonecheck(False)
    cpdef put(OrderedTreeDict self, object key, object value):
        self._insert(key, value)

    @cython.nonecheck(False)
    cdef inline _delete(OrderedTreeDict self, object key):
        pass

    @cython.nonecheck(False)
    def delete(OrderedTreeDict self, object key):
        self._delete(key)

    @cython.nonecheck(False)
    cpdef update(OrderedTreeDict self, object items):
        cdef object key, value
        for key, value in items:
            self._insert(key, value)

    @cython.nonecheck(False)
    def clear(OrderedTreeDict self):
        """ Removes all entries from the dictionary. """
        self.root = None

    @cython.nonecheck(False)
    def copy(OrderedTreeDict self):
        """ Shallow copy. """
        return OrderedTreeDict(self)

    @cython.nonecheck(False)
    @staticmethod
    def fromkeys(object keys, object value=None) -> OrderedTreeDict:
        """The fromkeys() method creates a new dictionary from the given sequence of elements with a value provided by the user. """
        cdef object key
        cdef OrderedTreeDict new_dict = OrderedTreeDict()
        for key in keys:
             new_dict.put(key, value)
        return new_dict

    @cython.nonecheck(False)
    def popitem(OrderedTreeDict self):
        """ The popitem() returns and removes an element (key, value) pair from the dictionary.
        """
        if self.root is None:
            raise KeyError()
        cdef _Node node = self.root
        self._delete(self.root.key)
        return node.key, node.value

    def items(OrderedTreeDict self):
        """ Returns an iterator over (key, value) pairs."""
        cdef _Node node = self.root
        cdef _MemStack stack
        if node is None:
            return
        try:
            stack = _MemStack(node.height)
        except MemoryError:
            raise MemoryError("Not enough memory to iterate a tree this deep.")
        while node is not None:
            stack.push(node)
            node = node.left
        while stack.num_items > 0:
            node = stack.pop()
            yield (node.key, node.value)
            node = node.right
            while node is not None:
                stack.push(node)
                node = node.left

    @cython.nonecheck(False)
    def keys(OrderedTreeDict self):
        """Returns an iterator over the dict keys."""
        cdef object key, value
        for key, value in self.items():
            yield key

    @cython.nonecheck(False)
    def values(OrderedTreeDict self):
        """ Returns an iterator over the dict values."""
        cdef object key, value
        for key, value in self.items():
            yield value

    @cython.nonecheck(False)
    def setdefault(OrderedTreeDict self, object key, object value):
        """Sets a key in the dictionary if it does not already exist."""
        self._insert(key, value, replace=False)

    @cython.nonecheck(False)
    def pop(OrderedTreeDict self, object key):
        """ Returns and removes the value for key."""
        cdef object retval = self._get(key)
        self._delete(key)
        return retval

    @cython.nonecheck(False)
    @staticmethod
    cdef inline _Node _maximum(_Node node):
        if node is None:
            raise KeyError("Dictionary is empty.")
        cdef _Node curr_node = None
        cdef _Node next_node = node
        while next_node is not None:
            curr_node = next_node
            next_node = next_node.right
        return curr_node

    @cython.nonecheck(False)
    def maximum(OrderedTreeDict self):
        cdef _Node max_node = OrderedTreeDict._maximum(self.root)
        return max_node.key, max_node.value

    @cython.nonecheck(False)
    @staticmethod
    cdef inline _Node _minimum(_Node node):
        if node is None:
            raise KeyError("Dictionary is empty.")
        cdef _Node curr_node = None
        cdef _Node next_node = node
        while next_node is not None:
            curr_node = next_node
            next_node = next_node.left
        return curr_node

    @cython.nonecheck(False)
    def minimum(OrderedTreeDict self):
        cdef _Node min_node = OrderedTreeDict._minimum(self.root)
        return min_node.key, min_node.value

    @cython.nonecheck(False)
    def __getitem__(OrderedTreeDict self, object key):
        return self._get(key)

    @cython.nonecheck(False)
    def __setitem__(OrderedTreeDict self, object key, object value):
        self._insert(key, value)

    @cython.nonecheck(False)
    def __delitem__(OrderedTreeDict self, object key):
       self._delete(key)

    @cython.nonecheck(False)
    def __contains__(OrderedTreeDict self, object key):
        try:
            self._get(key)
            return True
        except KeyError:
            return False

    __iter__ = items

    @cython.nonecheck(False)
    def __reversed__(OrderedTreeDict self):
       cdef _Node node = self.root
       cdef _MemStack stack
       if node is None:
           return
       try:
           stack = _MemStack(node.height)
       except MemoryError:
           raise MemoryError("Not enough memory to iterate a tree this deep.")
       while node is not None:
           stack.push(node)
           node = node.right
       while stack.num_items > 0:
           node = stack.pop()
           yield (node.key, node.value)
           node = node.left
           while node is not None:
               stack.push(node)
               node = node.right

    @cython.nonecheck(False)
    def __len__(OrderedTreeDict self):
        if self.root is None:
            return 0
        return self.root.left_tree_size + self.root.right_tree_size
