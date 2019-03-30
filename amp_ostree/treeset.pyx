from cpython.weakref cimport PyWeakref_CheckRef, PyWeakref_NewRef, PyWeakref_GetObject
cimport cython
from amp_ostree.memstack cimport MemStack
from libc.math cimport log2

cdef inline size_t size_t_max(size_t a, size_t b) nogil:
    return a if (a >= b) else b

#@cython.trashcan(True)
@cython.no_gc_clear
@cython.internal
@cython.final
cdef class _SBTSetNode:
    cdef:
        _SBTSetNode left
        _SBTSetNode right
        object value
        size_t size
        object parent_ref
    cdef object __weakref__
    
    def __repr__(self):
        return f"<_Node object at id(self): "\
            f"(key: {self.key}, value: {self.value}, size: {self.size})"

@cython.no_gc_clear
@cython.final
cdef class OrderedTreeSet:
    """ A dict based on an ordered statistic SBT tree."""
    cdef readonly _SBTSetNode root
    cdef object __weakref__

    def __cinit__(OrderedTreeSet self, object iterable=None, **kwargs):
        self.root = None
        if iterable:
             self.update(iterable)
        if kwargs:
             self.update(kwargs)

    @cython.nonecheck(False)
    cdef inline _get_node(OrderedTreeSet self, object key, bint raise_on_missing = True):
        cdef _SBTSetNode node = self.root
        while node is not None:
            if key < node.key:
                node = node.left
            elif key > node.key:
                node = node.right
            else:
                break
        if node is None and raise_on_missing:
            raise KeyError("Key not present.")
        return node
    
    def get(OrderedTreeSet self, object key, default=None):
        cdef _SBTSetNode node = self._get_node(key, raise_on_missing=False)
        if node is not None:
            return node.value
        return default
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline _SBTSetNode _get_parent(_SBTSetNode node):
        if PyWeakref_CheckRef(node.parent_ref):
            return <object> PyWeakref_GetObject(node.parent_ref)
        else:
            return None
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline object _make_ref(_SBTSetNode node):
        if node is None:
            return None
        else:
            return PyWeakref_NewRef(node, None)

    @cython.nonecheck(False)
    cpdef inline _rotate_right(OrderedTreeSet self, _SBTSetNode t):
        if t is None:
            return
        assert t.left is not None, "cannot rotate right"
        # k <- left[t]
        cdef _SBTSetNode k = t.left
        cdef _SBTSetNode parent = OrderedTreeSet._get_parent(t)
        cdef size_t left_size, right_size
        # left[t] <- right[k]
        t.left = k.right
        if t.left is not None:
            t.left.parent_ref = OrderedTreeSet._make_ref(t)
        # right[k] <- t
        k.right = t
        if k.right is not None:
            k.right.parent_ref = OrderedTreeSet._make_ref(k)
        # s[k] <= s[t]
        k.size = t.size
        # s[t] <- s[left[t]] + s[right[t]] + 1
        left_size = t.left.size if (t.left is not None) else 0
        right_size = t.right.size if (t.right is not None) else 0
        t.size = left_size  + right_size + 1
        # t = k
        if parent is None:
            self.root = k
            k.parent_ref = None
        else:
            k.parent_ref = OrderedTreeSet._make_ref(parent)
            if t is parent.left:
                parent.left = k
            elif t is parent.right:
                parent.right = k
            else:
                assert False, "Node is not child of parent"

    @cython.nonecheck(False)
    cpdef inline _rotate_left(OrderedTreeSet self, _SBTSetNode t):
        if t is None:
            return
        assert t.right is not None, "cannot rotate left"
        # k <- right[t]
        cdef _SBTSetNode k = t.right
        cdef _SBTSetNode parent = OrderedTreeSet._get_parent(t)
        cdef size_t left_size, right_size
        # right[t] <- left[k]
        t.right = k.left
        if t.right is not None:
            t.right.parent_ref = OrderedTreeSet._make_ref(t)
        # left[k] <- t
        k.left = t
        if k.left is not None:
            k.left.parent_ref = OrderedTreeSet._make_ref(k)
        # s[k] <- s[t]
        k.size = t.size
        # s[t] <- s[left[t]] + s[right[t]] + 1
        left_size = t.left.size if (t.left is not None) else 0
        right_size = t.right.size if (t.right is not None) else 0
        t.size = left_size  + right_size + 1
        # t <- k
        if parent is None:
            # nothing in tree
            self.root = k
            k.parent_ref = None
        else:
            k.parent_ref = OrderedTreeSet._make_ref(parent)
            if t is parent.left:
                parent.left = k
            elif t is parent.right:
                parent.right = k
            else:
                assert False, "Node is not child of parent"
    
    @cython.nonecheck(False)
    cdef inline _maintain(OrderedTreeSet self, _SBTSetNode t):
        cdef size_t depth_factor, pushes_per_row, min_depth
        cdef size_t t_left_size, t_left_left_size, t_left_right_size
        cdef size_t t_right_size, t_right_right_size, t_right_left_size
        cdef MemStack maintain_stack
        
        depth_factor = 2
        pushes_per_row = 3
        min_depth = <size_t>(log2(<double>t.size) + 1.0)
        maintain_stack = MemStack(size=(pushes_per_row*depth_factor*min_depth)+1)
        maintain_stack.c_push(t)
        
        while maintain_stack.num_items > 0:
            t = maintain_stack.c_pop()
            if t is None:
                continue
            
            # calculate subtree sizes
            t_left_size = 0
            t_left_left_size = 0
            t_left_right_size = 0
            t_right_size = 0
            t_right_right_size = 0
            t_right_left_size = 0
            if t.left is not None:
                t_left_size = t.left.size
                if t.left.left is not None:
                    t_left_left_size = t.left.left.size
                if t.left.right is not None:
                    t_left_right_size = t.left.right.size
            if t.right is not None:
                t_right_size = t.right.size
                if t.right.right is not None:
                    t_right_right_size = t.right.right.size
                if t.right.left is not None:
                    t_right_left_size = t.right.left.size
            
            # perform fixup rotations
            if t_left_left_size > t_right_size:
                self._rotate_right(t)
                maintain_stack.c_push(t)
                maintain_stack.c_push(t.right)
                continue
            elif t_left_right_size > t_right_size:
                if (t.left is not None) and (t.left.right is not None):
                    self._rotate_left(t.left)
                self._rotate_right(t)
                maintain_stack.c_push(t)
                maintain_stack.c_push(t.right)
                maintain_stack.c_push(t.left)
                continue
            elif t_right_right_size > t_left_size:
                self._rotate_left(t)
                maintain_stack.c_push(t)
                maintain_stack.c_push(t.left)
                continue
            elif t_right_left_size > t_left_size:
                if (t.right is not None) and (t.right.left is not None):
                    self._rotate_right(t.right)
                self._rotate_left(t)
                maintain_stack.c_push(t)
                maintain_stack.c_push(t.right)
                maintain_stack.c_push(t.left)
                continue
            else:
                break
        
    @cython.nonecheck(False)
    cdef inline _insert(OrderedTreeSet self, object value, bint replace=True):
        cdef _SBTSetNode insertion_node, next_node, new_node, parent_node, prev_parent_node
        cdef size_t left_size, right_size
        # Find insertion point
        insertion_node = None
        next_node = self.root
        while next_node is not None:
            insertion_node = next_node
            if value < insertion_node.value:
                next_node = insertion_node.left
            elif value > insertion_node.value:
                next_node = insertion_node.right
            else: # key == insertion_node.key
                break
        # Handle existing node if present.
        if next_node is not None:
            assert next_node.value == value
            if replace:
                # Replace value of existing node
                next_node.value = value
                return
            else:
                # No-op
                return

        # Create new node
        new_node = _SBTSetNode()
        new_node.value = value
        new_node.size = 1
        new_node.left = None
        new_node.right = None
        
        # Insert at the correct place in the tree
        if insertion_node is None:
            # No other nodes in tree
            self.root = new_node
            new_node.parent_ref = None
            return
        else:
            # Compare key to find whether it should be a left or right child
            new_node.parent_ref = OrderedTreeSet._make_ref(insertion_node)
            if value < insertion_node.value:
                # insert left
                insertion_node.left = new_node
            else:
                # insert right
                insertion_node.right = new_node
        
        parent_node = insertion_node
        parent_node.size += 1
        while parent_node is not None:
            left_size = parent_node.left.size if (parent_node.left is not None) else 0
            right_size = parent_node.right.size if (parent_node.right is not None) else 0
            parent_node.size = left_size  + right_size + 1
            self._maintain(parent_node)
            parent_node = OrderedTreeSet._get_parent(parent_node)
            
    @staticmethod
    cdef inline _decrement_ancestor_sizes(_SBTSetNode node):
        node = OrderedTreeSet._get_parent(node)
        while node is not None:
            node.size -= 1
            node = OrderedTreeSet._get_parent(node)

    @cython.nonecheck(False)
    cdef inline _delete(OrderedTreeSet self, _SBTSetNode node):
        if node is None:
            return None
        
        cdef _SBTSetNode successor
        cdef _SBTSetNode parent = OrderedTreeSet._get_parent(node)
        
        # If node is leaf, delete node.
        if (node.left is None) and (node.right is None):
            if parent is None:
                self.root = None
            elif node is parent.left:
                parent.left = None
            elif node is parent.right:
                parent.right = None
            OrderedTreeSet._decrement_ancestor_sizes(node)
            return node
        # if node has one child, replace the node with it's child
        elif (node.left is None) ^ (node.right is None):
            if parent is None:
                if node.left is not None:
                    self.root = node.left
                else:
                    self.root = node.right
            elif node is parent.left:
                if node.left is not None:
                    parent.left = node.left
                else:
                    parent.left = node.right
            else: # node is parent.right
                if node.left is node:
                    parent.right = node.left
                else:
                    parent.right = node.right
            OrderedTreeSet._decrement_ancestor_sizes(node)
            return node
        # if node has two children, find it's successor and delete it recursively, copying it's key/value to this node.
        # if the node has a right child, it's inorder successor is the minimum of the right children.
        else:
            # need to implement _successor
            successor = OrderedTreeSet._successor(node)
            node.value = successor.value
            self._delete(successor)
            return node
            
    def clear(OrderedTreeSet self):
        """ Removes all entries from the dictionary. """
        self.root = None
    
    def copy(OrderedTreeSet self):
        """ Shallow copy. """
        return OrderedTreeSet(self)

    def popitem(OrderedTreeSet self):
        """ The popitem() returns and removes an element (key, value) pair from the dictionary.
        """
        if self.root is None:
            raise KeyError()
        cdef _SBTSetNode node = self.root
        self._delete(node)
        return node.value

    def pop(OrderedTreeSet self, object key):
        """ Returns and removes the value for key."""
        cdef _SBTSetNode node = self._get(key)
        self._delete(node)
        return node.value

    @staticmethod
    @cython.nonecheck(False)
    cdef inline _SBTSetNode _maximum(_SBTSetNode node):
        if node is None:
            raise KeyError("Dictionary is empty.")
        cdef _SBTSetNode curr_node = None
        cdef _SBTSetNode next_node = node
        while next_node is not None:
            curr_node = next_node
            next_node = next_node.right
        return curr_node

    def max(OrderedTreeSet self):
        cdef _SBTSetNode max_node = OrderedTreeSet._maximum(self.root)
        return max_node.value
    
    @staticmethod
    cdef inline _SBTSetNode _minimum(_SBTSetNode node):
        if node is None:
            raise KeyError("Dictionary is empty.")
        cdef _SBTSetNode curr_node = None
        cdef _SBTSetNode next_node = node
        while next_node is not None:
            curr_node = next_node
            next_node = next_node.left
        return curr_node

    def min(OrderedTreeSet self):
        cdef _SBTSetNode min_node = OrderedTreeSet._minimum(self.root)
        return min_node.value
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline size_t _node_left_size(_SBTSetNode node):
        if node is None:
            return 0
        if node.left is None:
            return 0
        return node.left.size
    
    def select(OrderedTreeSet self, size_t i):
        cdef _SBTSetNode node = self.root
        if node is None:
            raise IndexError()
        cdef size_t r = OrderedTreeSet._node_left_size(node)
        while i != r and node is not None:
            if i < r:
                node = node.left
            else:
                node = node.right
                i = i - (r + 1)
            r = OrderedTreeSet._node_left_size(node)
        if node is None:
            raise IndexError("No such rank.")
        return node.key, node.value
    
    def rank(OrderedTreeSet self, object key):
        cdef _SBTSetNode node = self._get_node(key)
        cdef size_t rank = OrderedTreeSet._node_left_size(node) + 1
        cdef _SBTSetNode parent_node = OrderedTreeSet._get_parent(node)
        while parent_node is not None:
            if node is parent_node.right:
                rank = rank + OrderedTreeSet._node_left_size(parent_node) + 1
            node = parent_node
            parent_node = OrderedTreeSet._get_parent(parent_node)
        return rank - 1
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline _successor(_SBTSetNode node):
        cdef _SBTSetNode parent = OrderedTreeSet._get_parent(node)
        if node.right is not None:
            return OrderedTreeSet._minimum(node.right)
        while (parent is not None) and (node is parent.right):
            node = parent
            parent = OrderedTreeSet._get_parent(parent)
        return parent
    
    def successor(OrderedTreeSet self, object key):
        cdef _SBTSetNode node = self._get_node(key)
        node = OrderedTreeSet._successor(node)
        if node is not None:
            return node.value
        
    @staticmethod
    @cython.nonecheck(False)
    cdef inline _predecessor(_SBTSetNode node):
        cdef _SBTSetNode parent = OrderedTreeSet._get_parent(node)
        if node.left is not None:
            return OrderedTreeSet._maximum(node.left)
        while (parent is not None) and (node is parent.left):
            node = parent
            parent = OrderedTreeSet._get_parent(parent)
        return parent
    
    def predecessor(OrderedTreeSet self, object key):
        cdef _SBTSetNode node = self._get_node(key)
        node = OrderedTreeSet._predecessor(node)
        if node is not None:
            return node.value
    
    cpdef size_t depth(OrderedTreeSet self):
        """ Get the maximum depth of the tree.

        Returns:
            size_t: max_depth
        """
        if self.root is None:
            return 0
        node_stack = []
        depth_stack = []
        cdef _SBTSetNode current_node = self.root
        cdef size_t current_depth = 1
        cdef size_t max_depth = 0
        # Traverse down left branch nodes while pushing right nodes.
        while current_node.right or current_node.left or node_stack:
            # push right nodes onto stack
            if current_node.right is not None:
                node_stack.append(current_node.right)
                depth_stack.append(current_depth + 1)
            # Traverse left branches
            if current_node.left:
                current_depth += 1
                current_node = current_node.left
            else:
                # Pop a right branch off the stack if no left branch
                current_node = node_stack.pop()
                current_depth = depth_stack.pop()
            if max_depth < current_depth:
                max_depth = current_depth
            assert len(node_stack) == len(
                depth_stack
            ), "Node stack desynced from depth stack."
        return max_depth
    
    def __getitem__(OrderedTreeSet self, object key):
        cdef _SBTSetNode node = self._get_node(key)
        return node.value
    
    def __setitem__(OrderedTreeSet self, object key, object value):
        self._insert(key, value)
        
    def __delitem__(OrderedTreeSet self, object key):
       self._delete(key)

    def __contains__(OrderedTreeSet self, object value):
        return self._get_node(value, raise_on_missing=False) is not None
    
    def __iter__(OrderedTreeSet self):
        """ Returns an iterator over (key, value) pairs."""
        cdef _SBTSetNode node = self.root
        cdef MemStack stack
        if node is None:
            return
        try:
            # max tree depth for an sbt is 2*log(n)
            stack = MemStack(2*<size_t>(log2(node.size))+1)
        except MemoryError:
            raise MemoryError("Not enough memory to iterate a tree this deep.")
        while node is not None:
            stack.c_push(node)
            node = node.left
        while stack.num_items > 0:
            node = stack.c_pop()
            yield node.value
            node = node.right
            while node is not None:
                stack.c_push(node)
                node = node.left

    def __reversed__(OrderedTreeSet self):
       cdef _SBTSetNode node = self.root
       cdef MemStack stack
       if node is None:
           return
       try:
           # depth bound is 2*log2(n)
           stack = MemStack(2*<size_t>(log2(node.size))+1)
       except MemoryError:
           raise MemoryError("Not enough memory to iterate a tree this deep.")
       while node is not None:
           stack.c_push(node)
           node = node.right
       while stack.num_items > 0:
           node = stack.c_pop()
           yield node.value
           node = node.left
           while node is not None:
               stack.c_push(node)
               node = node.right
 
    def __len__(OrderedTreeSet self):
        if self.root is None:
            return 0
        return self.root.size



