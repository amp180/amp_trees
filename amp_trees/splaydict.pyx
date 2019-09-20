#!python
#cython: language_level=3
from cpython.exc cimport PyErr_CheckSignals
cimport cython
cdef size_t SIGNAL_CHECK_INTERVAL = 10000


@cython.final
@cython.internal
cdef class SplayNode:
    cdef SplayNode left, right, parent
    cdef object key, value
    cdef object __weakref__
    __slots__=None

    def __init__(SplayNode self):
        self.left = None
        self.right = None
        self.parent = None
        self.key = None
        self.value = None

    def __repr__(SplayNode self):
        return "id:"+ str(id(self)) + " key: " + repr(self.key) + " value: " + repr(self.value)


@cython.final
cdef class SplayDict:
    """A dict structured as a splay tree.
       Not balanced but repeated accesses to a small group of keys will cause them to rotate to the top of the tree.
       This means that O(height) operations depend on the height of the group of elements you're working on, not necassarily the full height of the tree.
       Requires comparable keys.
       Supports key lookup, update, delete, pop, min key and max key in O(h) time.
       Getting the successor or predecessor of an item for iteration takes O(h) time and O(1) memory.
    """
    cdef public SplayNode root
    cdef public size_t size
    cdef size_t signals_ctr
    cdef object __weakref__

    def __cinit__(SplayDict self, iterable=None):
        self.size = 0
        self.root = None
        if iterable is not None:
            # insert items
            self.update(iterable)

    def get(SplayDict self, key, default=None):
        """Get a value for a key in the splaydict. 
            Returns a default value if the key isn't found.
        """
        node = self._get_node(key)
        if node is None:
            return default
        return (node.key, node.value)

    def put(SplayDict self, key, value):
        """ Insert a key value pair into the splaydict."""
        self._insert(key, value)

    def items(SplayDict self):
        """Returns a generator that can be used to iterate over the key value pairs in the splaydict."""
        cdef SplayNode node
        node = SplayDict._minimum(self.root)
        while node is not None:
            yield (node.key, node.value)
            node = SplayDict._successor(node)
           
    def keys(SplayDict self):
        """Returns a generator that can be used to iterate over the keys in the splaydict."""
        cdef SplayNode node
        node = SplayDict._minimum(self.root)
        while node is not None:
            yield (node.key)
            node = SplayDict._successor(node)

    def values(SplayDict self):
        """Returns a generator that can be used to iterate over the values in the splaydict."""
        cdef SplayNode node
        node = SplayDict._minimum(self.root)
        while node is not None:
            yield (node.value)
            node = SplayDict._successor(node)

    def delete(SplayDict self, key):
        """Deletes a key from the splaydict."""
        cdef SplayNode node
        node = self._get_node(key)
        if node is None:
            raise KeyError()
        self._delete(node)

    cpdef update(SplayDict self, items):
        """Inserts an iterable of (key, value) pairs into the splaydict."""
        cdef object key, value

        for key, value in items:
            self._insert(key, value)
            self.check_signals()
            
    def copy(SplayDict self) -> "SplayDict":
        """ Creates a shallow copy of the splaydict. """
        return SplayDict(self)
    
    def clear(SplayDict self):
        """Clears all items from the splaydict, leaving it empty."""
        self.root = None
        self.size = 0

    @staticmethod
    def fromkeys(keys, value=None) -> "SplayDict":
        """The fromkeys() method creates a new splaydict from the given sequence of elements with a value provided by the user. """
        cdef SplayDict new_dict
        cdef object key

        new_dict = SplayDict()
        for key in keys:
             new_dict.put(key, value)
        return new_dict
    
    def popitem(SplayDict self):
        """ Returns and removes an element (key, value) pair from the splaydict."""
        cdef SplayNode node
        if self.root is None:
            raise KeyError()
        node = self.root
        retval = (node.key, node.value)
        self._delete(node)
        return retval

    def setdefault(SplayDict self, key, value):
        """Sets a key in the splaydict if it does not already exist."""
        self._insert(key, value, replace=False)

    def pop(SplayDict self, key):
        """ Returns and removes the value for key.
            Raises KeyError if key not found.
        """
        cdef SplayNode node
        node = self._get_node(key)
        if node is None:
            raise KeyError("No such key in splaydict.")
        retval = (node.key, node.value)
        self._delete(node)
        return retval

    def max(SplayDict self):
        """Returns a key, value pair for the node in the splaydict with the greatest key.
           Raises KeyError if tree is empty.
        """
        cdef SplayNode max_node
        if self.root is None:
            raise KeyError("The splaydict is empty.")
        max_node = SplayDict._maximum(self.root)
        return (max_node.key, max_node.value)

    def min(SplayDict self):
        """Returns a key, value pair for the node in the splaydict with the lowest key.
           Raises KeyError if the splaydict is empty. 
        """
        cdef SplayNode min_node
        if self.root is None:
            raise KeyError("The splaydict is empty.")
        min_node = SplayDict._minimum(self.root)
        return (min_node.key, min_node.value)

    def successor(SplayDict self, key):
        """Returns a key, value pair for the node in the splaydict after the node with the given key in sorted order.
        Raises KeyError if it can't find a node with the key or the node has no predecessor."""
        #todo: make this work if a key not in the splaydict is given.
        cdef SplayNode node
        node = self._get_node(key)
        node = SplayDict._successor(node)
        if node is None:
            raise KeyError("""Node has no successor.""")
        return (node.key, node.value)

    def predecessor(SplayDict self,  key):
        """Returns a key, value pair for the node in the splaydict before the node with the given key in sorted order.
            Raises KeyError if it can't find a node with the key or the node has no predecessor."""
        cdef SplayNode node
        node = self._get_node(key)
        node = SplayDict._predecessor(node)
        if node is None:
            raise KeyError("""Node has no successor.""")
        return (node.key, node.value)

    def __len__(SplayDict self):
        """ Implements len(tree) """
        if self.root is None:
            return 0
        return self.size

    def __iter__(SplayDict self):
       """Implements the iteration protocol."""
       cdef SplayNode node
       node = SplayDict._minimum(self.root)
       while node is not None:
           yield ((node.key), (node.value))
           node = SplayDict._successor(node)
    
    def __getitem__(SplayDict self,  key):
        """Implements getting a value by the square brackets operator. eg. tree[key]"""
        cdef SplayNode node
        node  = self._get_node(key)
        if node is None:
            raise KeyError("No such item in dict.")
        return node.value
    
    def __setitem__(SplayDict self, key, value):
        """Implements assignment to tree[]."""
        self._insert(key, value)
        
    def __delitem__(SplayDict self,  key):
        """Implements the del operator on tree[]."""
        cdef SplayNode node 
        node = self._get_node(key)
        self._delete(node)

    def __contains__(SplayDict self,  key):
        """Implements the 'in' operator for keys."""
        return self._get_node(key) is not None

    def __reversed__(SplayDict self):
        """Returns a generator that iterates through the tree in reverse sorted order by key."""
        cdef SplayNode node
        if self.root is None:
            return
        node = SplayDict._maximum(self.root)
        while node is not None:
            yield node.key, node.value
            node = SplayDict._predecessor(node)

    cdef inline SplayNode _get_node(SplayDict self, key):
        """Locates a node in the tree by it's key."""
        cdef SplayNode current_node, next_node
        current_node = None;
        next_node = self.root;

        while next_node is not None:
            self.check_signals()
            current_node = next_node
            if key < current_node.key:
                next_node = current_node.left
            elif key > current_node.key:
                next_node = current_node.right
            else: # Found the node
                self._splay(current_node)
                break

        return next_node

    cdef inline _splay(SplayDict self, SplayNode node):
        """Rotates a node upwards until it's the root of the tree."""
        if node is None or node is self.root:
            return
        while node is not self.root:
            self._splay_step(node)
            self.check_signals()

    cdef inline _splay_step(SplayDict self, SplayNode node):
        """Rotates a node in the tree into the position of it's parent or grandparent, bubbling it up the tree."""
        cdef SplayNode parent, grandparent
        if node.parent is not None:
            parent = node.parent
            if node.parent.parent is not None:
                grandparent = node.parent.parent
                # zig zig step
                if parent is grandparent.left and node is parent.left:
                    self._rotate_right(parent)
                    self._rotate_right(grandparent)
                # zag zag
                elif parent is grandparent.right and node is parent.right:
                    self._rotate_left(parent)
                    self._rotate_left(grandparent)
                # zig zag step
                elif parent is grandparent.left and node is parent.right:
                    self._rotate_left(parent)
                    self._rotate_right(grandparent)
                # zag zig
                elif parent is grandparent.right and node is parent.left:
                    self._rotate_right(parent)
                    self._rotate_left(grandparent)
            else:
                if node is parent.left:
                    self._rotate_right(parent)
                else: # node is parent.right
                    self._rotate_left(parent)
        return

    cdef inline _rotate_left(SplayDict self, SplayNode t):
        """Rotates a node in the tree to the left."""
        cdef SplayNode k, parent
        cdef size_t left_size, right_size
        if t is None:
            return
        assert t.right is not None, "cannot rotate left"
        # k <- right[t]
        k = t.right
        parent = t.parent
        # right[t] <- left[k]
        t.right = k.left
        if t.right is not None:
            t.right.parent = t
        # left[k] <- t
        k.left = t
        if k.left is not None:
            k.left.parent = k
        # t <- k
        if parent is None:
            # nothing in tree
            self.root = k
            k.parent = None
        else:
            k.parent = parent
            if t is parent.left:
                parent.left = k
            elif t is parent.right:
                parent.right = k
            else:
                assert False, "Node is not child of parent"

    cdef inline _rotate_right(SplayDict self, SplayNode t):
        """Rotates a node in the tree to the right."""
        cdef size_t left_size, right_size
        if t is None:
            return
        assert t.left is not None, "cannot rotate right"
        # k <- left[t]
        k = t.left
        parent = t.parent
        # left[t] <- right[k]
        t.left = k.right
        if t.left is not None:
            t.left.parent = t
        # right[k] <- t
        k.right = t
        if k.right is not None:
            k.right.parent = k
        # t = k
        if parent is None:
            self.root = k
            k.parent = None
        else:
            k.parent = parent
            if t is parent.left:
                parent.left = k
            elif t is parent.right:
                parent.right = k
            else:
                assert False, "Node is not child of parent"

    @staticmethod
    cdef inline SplayNode _minimum(SplayNode node):
        """Gets the node in the tree with the lowest key."""
        cdef SplayNode curr_node, next_node
        if node is None:
            raise KeyError("Dictionary is empty.")
        curr_node  = None
        next_node = node
        while next_node is not None:
            curr_node = next_node
            next_node = next_node.left
        return curr_node
    
    @staticmethod
    cdef inline SplayNode _maximum(SplayNode node):
        """Gets the node in the tree with the greatest key."""
        cdef SplayNode curr_node, next_node
        if node is None:
            raise KeyError("Dictionary is empty.")
        curr_node = None
        next_node = node
        while next_node is not None:
            curr_node = next_node
            next_node = next_node.right
        return curr_node

    cdef inline _insert(SplayDict self, object key, object value, bint replace = True):
        """Inserts a key value pair into the tree."""
        cdef SplayNode new_node, insertion_node, next_node
        new_node = None
        insertion_node = None
        next_node = self.root

        if self.root is None:
            self.root = SplayNode()
            self.root.key = key
            self.root.value = value
            self.size += 1
            return

        while next_node is not None:
            self.check_signals()
            insertion_node = next_node
            if key < ( insertion_node.key):
                next_node = insertion_node.left
            elif key > ( insertion_node.key):
                next_node = insertion_node.right
            else: # key == insertion node key, insertion_node == next_node
                break

        if next_node is not None:
            if not replace:
                # Don't replace existing value
                return
            # key == insertion node key
            # insert into existing node
            next_node.value = value
            self._splay(next_node)
            return

        new_node = SplayNode()
        new_node.key = key
        new_node.value = value
        new_node.parent = insertion_node
        self.size += 1

        if key < insertion_node.key:
            insertion_node.left = new_node
        else:
            insertion_node.right = new_node
        self._splay(new_node)
        return

    @staticmethod
    cdef inline SplayNode _successor(SplayNode node):
        """Gets the node in the tree after the given node in sorted order by key."""
        cdef SplayNode parent
        if node is None:
            return None
        parent = node.parent
        if node.right is not None:
            return SplayDict._minimum(node.right)
        while (parent is not None) and (node is parent.right):
            node = parent
            parent = node.parent
        return parent
    
    @staticmethod
    cdef inline SplayNode _predecessor(SplayNode node):
        """Gets the node in the tree before the given node in sorted order by value."""
        cdef SplayNode parent
        parent = node.parent
        if node.left is not None:
            return SplayDict._maximum(node.left)
        while (parent is not None) and (node is parent.left):
            node = parent
            parent = node.parent
        return parent
    
    cdef inline _delete(SplayDict self, SplayNode node):
        """Deletes a node from the tree."""
        cdef SplayNode successor, parent

        if node is None:
            return

        parent = node.parent

        # If node is leaf, delete node.
        if (node.left is None) and (node.right is None):
            if parent is None or node is self.root:
                self.root = None
            elif node is parent.left:
                parent.left = None
            elif node is parent.right:
                parent.right = None
            self.size -= 1
            node = None
            self._splay(parent)
            return
        # if node has one child, replace the node with it's child
        elif (node.left is None) ^ (node.right is None):
            if parent is None:
                if node.left is not None:
                    self.root = node.left
                else:
                    self.root = node.right
                self.root.parent = None
            elif node is parent.left:
                if node.left is not None:
                    parent.left = node.left
                    node.left.parent = parent
                else: # node.right isn't None
                    parent.left = node.right
                    node.right.parent = parent
            else: # node is parent.right
                if node.left is not None:
                    parent.right = node.left
                    node.left.parent = parent
                else: # node.right isn't None
                    parent.right = node.right
                    node.right.parent = parent
            node = None
            self.size -= 1
            self._splay(parent)
            return

        # if node has two children, find it's successor and delete it recursively, copying it's key/value to this node.
        # if the node has a right child, it's inorder successor is the minimum of the right children.
        successor = SplayDict._successor(node)
        node.key, node.value = successor.key, successor.value
        self._delete(successor)
        self._splay(parent)

    cdef inline check_signals(SplayDict self):
        f"""Runs the python signal handler every ${SIGNAL_CHECK_INTERVAL} times it's called."""
        if self.signals_ctr % SIGNAL_CHECK_INTERVAL == 0:
            # Allow python to process signals
            PyErr_CheckSignals()
        self.signals_ctr += 1
