#!python
#cython: language_level=3
from cpython.mem cimport PyMem_Malloc, PyMem_Free, PyMem_Realloc
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from cpython.exc cimport PyErr_CheckSignals
from libc.errno cimport ENOMEM, errno
cimport cython


cdef inline size_t size_t_max(size_t a, size_t b) nogil:
    return a if (a >= b) else b


cdef struct splaynode_t:
        splaynode_t *left
        splaynode_t *right
        splaynode_t *parent
        PyObject *key
        PyObject *value


@cython.internal
@cython.final
cdef class SplayNodeManager:
    cdef:
        size_t nodes_occupied
        size_t storage_length
        splaynode_t *storage
        size_t min_size

    def __cinit__(SplayNodeManager self, size_t size=64):
        self.storage_length = 0
        self.nodes_occupied = 0
        self.min_size = size
        self.storage = NULL
        self._realloc_storage(size)

    def __dealloc__(SplayNodeManager self):
        cdef splaynode_t *max_ptr
        if self.nodes_occupied>0:
            max_ptr = &self.storage[self.nodes_occupied-1]
            while max_ptr >= self.storage:
                Py_DECREF(<object> max_ptr[0].key)
                Py_DECREF(<object> max_ptr[0].value)
                max_ptr -= 1
        PyMem_Free(self.storage)
        
    def __iter__(SplayNodeManager self):
        cdef splaynode_t *max_ptr
        if self.nodes_occupied>0:
            max_ptr = &self.storage[self.nodes_occupied-1]
            while max_ptr >= self.storage:
                yield (<object> max_ptr[0].key, <object> max_ptr[0].value)
                max_ptr -= 1

    cdef inline _realloc_storage(SplayNodeManager self, size_t length):
        cdef splaynode_t *new_storage
        if length < self.nodes_occupied:
            raise ValueError("New size cannot contain all nodes.")
        errno = 0
        new_storage = <splaynode_t *>PyMem_Realloc(self.storage, length * sizeof(splaynode_t))
        if errno != ENOMEM:
            self.storage = new_storage
            self.storage_length = length
        else:
            raise MemoryError("Could not allocate memory for tree.")

    cdef splaynode_t *alloc_node(SplayNodeManager self):
        cdef splaynode_t *node
        if not self.nodes_occupied < self.storage_length:
            self._realloc_storage(self.storage_length * 2)
        node = &self.storage[self.nodes_occupied]
        self.nodes_occupied += 1
        node[0].left = NULL
        node[0].right = NULL
        node[0].parent = NULL
        node[0].key = NULL
        node[0].value = NULL
        return node

    cdef dealloc_node(SplayNodeManager self, splaynode_t *node):
        cdef splaynode_t *last_node
        if node is not &self.storage[self.nodes_occupied - 1]:
            # mode the last node to this node so the last node can be freed.
            last_node = &self.storage[self.nodes_occupied - 1]
            node[0].left = last_node[0].left
            node[0].right = last_node[0].right
            node[0].parent = last_node[0].parent
            node[0].key = last_node[0].key
            node[0].value = last_node[0].value
            # Fix parent and child pointers
            if node is node[0].parent[0].left:
                node[0].parent[0].left = node
            else:
                node[0].parent[0].right = node
            if node[0].left is not NULL:
                node[0].left[0].parent = node
            if node[0].right is not NULL:
                node[0].right[0].parent = node
        # Decrement the number of used nodes
        self.nodes_occupied -= 1
        # Reduce mem size if only half full
        if (self.nodes_occupied < self.storage_length // 2) and (self.storage_length // 2 > self.min_size):
            self._realloc_storage(self.storage_length // 2)

@cython.final
cdef class SplayDict:
    """ A dict based on an ordered statistic SBT tree."""
    cdef SplayNodeManager storage
    cdef splaynode_t *root
    cdef object __weakref__

    def __cinit__(SplayDict self, object iterable=None):
        cdef size_t size
        if iterable is not None:
            # Preallocate if possible
            try:
                len(iterable)
            except:
                self.storage = SplayNodeManager()
            else:
                size = len(iterable)
                self.storage = SplayNodeManager(size=size)

            # insert items
            self.update(iterable)
        else:
            self.storage = SplayNodeManager()

    @cython.nonecheck(False)
    cdef inline _rotate_right(SplayDict self, splaynode_t *t):
        if t is NULL:
            return
        assert t[0].left is not NULL, "cannot rotate right"
        # k <- left[t]
        cdef splaynode_t *k = t[0].left
        cdef splaynode_t *parent = t[0].parent
        cdef size_t left_size, right_size
        # left[t] <- right[k]
        t[0].left = k[0].right
        if t[0].left is not NULL:
            t[0].left[0].parent = t
        # right[k] <- t
        k[0].right = t
        if k[0].right is not NULL:
            k[0].right[0].parent = k
        # t = k
        if parent is NULL:
            self.root = k
            k[0].parent = NULL
        else:
            k[0].parent = parent
            if t is parent[0].left:
                parent[0].left = k
            elif t is parent[0].right:
                parent[0].right = k
            else:
                assert False, "Node is not child of parent"

    cdef inline _splay(SplayDict self, splaynode_t *node):
        if node is NULL or self.root:
            return
        while node is not self.root:
            self._splay_step(node)

    cdef inline _splay_step(SplayDict self, splaynode_t *node):
        cdef splaynode_t *parent
        cdef splaynode_t *grandparent
        if node[0].parent is not NULL:
            parent = node[0].parent
            if node[0].parent[0].parent is not NULL:
                grandparent = node[0].parent[0].parent
                # zig zig step
                if parent is grandparent[0].left and node is parent[0].left:
                    self._rotate_right(parent)
                    self._rotate_right(grandparent)
                # zag zag
                elif parent is grandparent[0].right and node is parent[0].right:
                    self._rotate_left(parent)
                    self._rotate_left(grandparent)
                # zig zag step
                elif parent is grandparent[0].left and node is parent[0].right:
                    self._rotate_left(parent)
                    self._rotate_right(grandparent)
                # zag zig
                elif parent is grandparent[0].right and node is parent[0].left:
                    self._rotate_right(parent)
                    self._rotate_left(grandparent)
            else:
                if node is parent[0].left:
                    self._rotate_right(parent)
                else: # node is parent[0].right
                    self._rotate_left(parent)
        return

    @cython.nonecheck(False)
    cdef inline _rotate_left(SplayDict self, splaynode_t *t):
        if t is NULL:
            return
        assert t[0].right is not NULL, "cannot rotate left"
        # k <- right[t]
        cdef splaynode_t *k = t.right
        cdef splaynode_t *parent = t[0].parent
        cdef size_t left_size, right_size
        # right[t] <- left[k]
        t[0].right = k[0].left
        if t[0].right is not NULL:
            t[0].right[0].parent = t
        # left[k] <- t
        k[0].left = t
        if k[0].left is not NULL:
            k[0].left[0].parent = k
        # t <- k
        if parent is NULL:
            # nothing in tree
            self.root = k
            k[0].parent = NULL
        else:
            k[0].parent = parent
            if t is parent[0].left:
                parent[0].left = k
            elif t is parent[0].right:
                parent[0].right = k
            else:
                assert False, "Node is not child of parent"

    @staticmethod
    cdef inline splaynode_t* _minimum(splaynode_t *node):
        if node is NULL:
            raise KeyError("Dictionary is empty.")
        cdef splaynode_t *curr_node = NULL
        cdef splaynode_t *next_node = node
        while next_node is not NULL:
            curr_node = next_node
            next_node = next_node[0].left
        return curr_node
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline splaynode_t* _maximum(splaynode_t *node):
        if node is NULL:
            raise KeyError("Dictionary is empty.")
        cdef splaynode_t *curr_node = NULL
        cdef splaynode_t *next_node = node
        while next_node is not NULL:
            curr_node = next_node
            next_node = next_node.right
        return curr_node

    cdef inline splaynode_t* _get_node(SplayDict self, object key):
        cdef splaynode_t *current_node = NULL;
        cdef splaynode_t *next_node = self.root;

        while next_node is not NULL:
            current_node = next_node
            if <object> current_node[0].key < key:
                next_node = current_node[0].left
            elif <object> current_node[0].key > key:
                next_node = current_node[0].right
            else:
                self._splay(current_node)
                break

        return next_node

    cpdef inline _insert(SplayDict self, object key, object value):
        cdef splaynode_t *new_node = NULL
        cdef splaynode_t *insertion_node = NULL
        cdef splaynode_t *next_node = self.root

        if self.root is NULL:
            self.root = self.storage.alloc_node()
            Py_INCREF(key)
            Py_INCREF(value)
            self.root[0].key = <PyObject *> key
            self.root[0].value = <PyObject *> value
            return

        while next_node is not NULL:
            insertion_node = next_node
            self._splay_step(insertion_node)
            if key < (<object> insertion_node[0].key):
                next_node = insertion_node[0].left
            elif key > (<object> insertion_node[0].key):
                next_node = insertion_node[0].right
            else: # key == insertion node key, insertion_node == next_node
                break

        if next_node is not NULL:
            # key == insertion node key
            # insert into existing node
            Py_DECREF(<object> next_node[0].value)
            Py_INCREF(value)
            next_node[0].value = <PyObject *>value
            self._splay(next_node)
            return

        new_node = self.storage.alloc_node()
        Py_INCREF(key)
        Py_INCREF(value)
        new_node[0].key = <PyObject *> key
        new_node[0].value = <PyObject *> value
        new_node[0].parent = insertion_node

        if <object> insertion_node[0].key > key:
            insertion_node[0].left = new_node
        else:
            insertion_node[0].right = new_node
        self._splay(new_node)
        return

    def clear(SplayDict self):
        self.storage = SplayNodeManager()
        self.root = NULL

    cpdef put(SplayDict self, object key, object value):
        self._insert(key, value)

    @staticmethod
    cdef inline splaynode_t* _successor(splaynode_t *node):
        cdef splaynode_t *parent = node[0].parent
        if node[0].right is not NULL:
            return SplayDict._minimum(node[0].right)
        while (parent is not NULL) and (node is parent[0].right):
            node = parent
            parent = node[0].parent
        return parent
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline splaynode_t* _predecessor(splaynode_t* node):
        cdef splaynode_t* parent = node[0].parent
        if node.left is not NULL:
            return SplayDict._maximum(node.left)
        while (parent is not NULL) and (node is parent.left):
            node = parent
            parent = parent[0].parent
        return parent
    
    @cython.nonecheck(False)
    cdef inline _delete(SplayDict self, splaynode_t *node):
        if node is NULL:
            return None

        cdef splaynode_t *successor
        cdef splaynode_t *parent = node[0].parent

        # If node is leaf, delete node.
        if (node[0].left is NULL) and (node[0].right is NULL):
            if parent is NULL:
                self.root = NULL
            elif node is parent[0].left:
                parent[0].left = NULL
            elif node is parent[0].right:
                parent[0].right = NULL
            self.storage.dealloc_node(node)
            self._splay(parent)
        # if node has one child, replace the node with it's child
        elif (node[0].left is NULL) ^ (node[0].right is NULL):
            if parent is NULL:
                if node[0].left is not NULL:
                    self.root = node[0].left
                else:
                    self.root = node[0].right
                self.root[0].parent = NULL
            elif node is parent[0].left:
                if node[0].left is not NULL:
                    parent[0].left = node[0].left
                    node[0].left[0].parent = parent
                else: # node.right isn't null
                    parent[0].left = node[0].right
                    node[0].right[0].parent = parent
            else: # node is parent.right
                if node[0].left is not NULL:
                    parent[0].right = node[0].left
                    node[0].left[0].parent = parent
                else: # node.right isn't null
                    parent[0].right = node.right
                    node[0].right[0].parent = parent
            self.storage.dealloc_node(node)
            self._splay(parent)
        # if node has two children, find it's successor and delete it recursively, copying it's key/value to this node.
        # if the node has a right child, it's inorder successor is the minimum of the right children.
        successor = SplayDict._successor(node)
        node.key, node.value = successor.key, successor.value
        self._delete(successor)
        if parent is not NULL:
            self._splay(parent)

    def items(SplayDict self):
       cdef splaynode_t *node = SplayDict._minimum(self.root)
       while node is not NULL:
           yield (<object>(node[0].key), <object>(node[0].value))
           node = SplayDict._successor(node)
           
    def keys(SplayDict self):
       cdef splaynode_t *node = SplayDict._minimum(self.root)
       while node is not NULL:
           yield <object>(node[0].key)
           node = SplayDict._successor(node)

    def values(SplayDict self):
       cdef splaynode_t *node = SplayDict._minimum(self.root)
       while node is not NULL:
           yield <object>(node[0].value)
           node = SplayDict._successor(node)

    def iter_fast(SplayDict self):
       return self.storage
       
    def __iter__(SplayDict self):
       cdef splaynode_t *node = SplayDict._minimum(self.root)
       while node is not NULL:
           yield (<object>(node[0].key), <object>(node[0].value))
           node = SplayDict._successor(node)
           
    def delete(SplayDict self, object key):
        cdef splaynode_t *node = self._get_node(key)
        self._delete(node)

    cpdef update(SplayDict self, object items):
        cdef object key, value
        cdef size_t ctr = 0
        for key, value in items:
            self._insert(key, value)
            if ctr % 100000 == 0:
                # catch KeyboardInterrupt
                PyErr_CheckSignals()
            ctr += 1

    def copy(SplayDict self):
        """ Shallow copy. """
        return SplayDict(iter(self))

    @staticmethod
    def fromkeys(object keys, object value=None) -> SplayDict:
        """The fromkeys() method creates a new dictionary from the given sequence of elements with a value provided by the user. """
        cdef object key
        cdef size_t ctr = 0
        cdef SplayDict new_dict = SplayDict()
        for key in keys:
             new_dict.put(key, value)
             if ctr % 100000 == 0:
                # catch KeyboardInterrupt
                PyErr_CheckSignals()
             ctr += 1
        return new_dict
    
    def __len__(SplayDict self):
        if self.root is NULL:
            return 0
        return self.storage.nodes_occupied

    def __getitem__(SplayDict self, object key):
        cdef splaynode_t* node = self._get_node(key)
        return <object> node[0].value
    
    def __setitem__(SplayDict self, object key, object value):
        self._insert(key, value)
        
    def __delitem__(SplayDict self, object key):
        cdef splaynode_t* node = self._get_node(key)
        self._delete(node)

    def __contains__(SplayDict self, object key):
        return self._get_node(key) is not NULL
#
#    def popitem(SplayDict self):
#        """ The popitem() returns and removes an element (key, value) pair from the dictionary.
#        """
#        if self.root is None:
#            raise KeyError()
#        cdef splaynode_t* node = self.root
#        self._delete(node)
#        return node.key, node.value
#
#    def setdefault(SplayDict self, object key, object value):
#        """Sets a key in the dictionary if it does not already exist."""
#        self._insert(key, value, replace=False)
#
#    def pop(SplayDict self, object key):
#        """ Returns and removes the value for key."""
#        cdef splaynode_t* node = self._get_node(key)
#        self._delete(node)
#        return node.key, node.value
#
#    def max(SplayDict self):
#        cdef splaynode_t* max_node = SplayDict._maximum(self.root)
#        return max_node.key, max_node.value
#
#    def min(SplayDict self):
#        cdef splaynode_t* min_node = SplayDict._minimum(self.root)
#        return min_node.key, min_node.value
#
#    def successor(SplayDict self, object key):
#        cdef splaynode_t* node = self._get_node(key)
#        node = SplayDict._successor(node)
#        if node is not None:
#            return node.key, node.value
#
#    def predecessor(SplayDict self, object key):
#        cdef splaynode_t* node = self._get_node(key)
#        node = SplayDict._predecessor(node)
#        if node is not None:
#            return node.key, node.value
#    
#    cpdef size_t depth(SplayDict self):
#        """ Get the maximum depth of the tree.
#
#        Returns:
#            size_t: max_depth
#        """
#        if self.root is None:
#            return 0
#        node_stack = []
#        depth_stack = []
#        cdef splaynode_t* current_node = self.root
#        cdef size_t current_depth = 1
#        cdef size_t max_depth = 0
#        # Traverse down left branch nodes while pushing right nodes.
#        while current_node.right or current_node.left or node_stack:
#            # push right nodes onto stack
#            if current_node.right is not None:
#                node_stack.append(current_node.right)
#                depth_stack.append(current_depth + 1)
#            # Traverse left branches
#            if current_node.left:
#                current_depth += 1
#                current_node = current_node.left
#            else:
#                # Pop a right branch off the stack if no left branch
#                current_node = node_stack.pop()
#                current_depth = depth_stack.pop()
#            if max_depth < current_depth:
#                max_depth = current_depth
#            assert len(node_stack) == len(
#                depth_stack
#            ), "Node stack desynced from depth stack."
#        return max_depth
#    

#    def __reversed__(SplayDict self):
#        if self.root is None:
#            return
#        cdef splaynode_t* node = SplayDict._maximum(self.root)
#        while node is not None:
#            yield node.key, node.value
#            node = SplayDict._predecessor(node)
# 

