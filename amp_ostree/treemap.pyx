#!python
#cython: language_level=3
from cpython.weakref cimport PyWeakref_CheckRef, PyWeakref_NewRef, PyWeakref_GetObject
cimport cython
from amp_ostree.memstack cimport MemStack

cdef inline size_t size_t_max(size_t a, size_t b) nogil:
    return a if a > b else b

#@cython.trashcan(True)
@cython.no_gc_clear
@cython.internal
@cython.final
cdef class _Node():
    cdef readonly:
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
    cdef readonly _Node root
    cdef object __weakref__

    def __cinit__(OrderedTreeDict self, object iterable=None, **kwargs):
        if iterable:
             self.update(iterable)
        if kwargs:
             self.update(kwargs)

    @cython.nonecheck(False)
    cdef inline _get_node(OrderedTreeDict self, object key, bint raise_on_missing = True):
        cdef _Node node = self.root
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
    
    @cython.nonecheck(False)
    def get(OrderedTreeDict self, object key, default=None):
        cdef _Node node = self._get_node(key, raise_on_missing=False)
        if node is not None:
            return node.value
        return default
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline _Node _get_parent(_Node node):
        if PyWeakref_CheckRef(node.parent_ref):
            return <object> PyWeakref_GetObject(node.parent_ref)
        else:
            return None
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline object _make_ref(_Node node):
        if node is None:
            return None
        else:
            return PyWeakref_NewRef(node, None)
        
    @staticmethod
    @cython.nonecheck(False)
    cdef inline size_t _balance_factor(_Node node):
        cdef size_t left_depth = node.left.depth + 1 if node.left is not None else 0
        cdef size_t right_depth = node.right.depth + 1 if node.right is not None else 0
        return right_depth - left_depth
    
    @staticmethod
    @cython.nonecheck(False)
    cdef inline size_t _recalculate_depth(_Node node):
        node.depth = size_t_max(
            node.left.depth + 1 if node.left is not None else 0,
            node.right.depth + 1 if node.right is not None else 0
        )

    @cython.nonecheck(False)
    cdef inline _rotate_left(OrderedTreeDict self, _Node pivot):
        cdef _Node right_node = pivot.right
        cdef _Node pivot_parent = OrderedTreeDict._get_parent(pivot)
        
        # update the parent node
        if pivot_parent is not None:
            if pivot_parent.left is pivot:
                pivot_parent.left = OrderedTreeDict._make_ref(right_node)
            else:
                pivot_parent.right = OrderedTreeDict._make_ref(right_node)
        else:
            self.root = right_node
            
        right_node.parent_ref = pivot.parent_ref
        
        pivot.right = right_node.left
        pivot.right_tree_size = right_node.right_tree_size
        
        if pivot.right is not None:
            pivot.right.parent_ref = OrderedTreeDict._make_ref(pivot)
        OrderedTreeDict._recalculate_depth(pivot)
        pivot.parent_ref = OrderedTreeDict._make_ref(right_node)
        
        right_node.left = pivot
        
        right_node.left_tree_size = pivot.left_tree_size + pivot.right_tree_size + 1
        OrderedTreeDict._recalculate_depth(right_node)
        
    @cython.nonecheck(False)
    cdef inline _rotate_right(OrderedTreeDict self, _Node pivot):
        cdef _Node left_node = pivot.left
        cdef _Node pivot_parent = OrderedTreeDict._get_parent(pivot)

        # update the parent node
        if pivot_parent is not None:
            if pivot_parent.left is pivot:
                pivot_parent.left = OrderedTreeDict._make_ref(left_node)
            else:
                pivot_parent.right = OrderedTreeDict._make_ref(left_node)
        else:
            self.root = left_node
            
        left_node.parent_ref = pivot.parent_ref
        
        pivot.left = left_node.right
        pivot.left_tree_size = left_node.right_tree_size
        
        if pivot.left is not None:
            pivot.left.parent_ref = OrderedTreeDict._make_ref(pivot)
        OrderedTreeDict._recalculate_depth(pivot)
        pivot.parent_ref = OrderedTreeDict._make_ref(left_node)
        
        left_node.right = pivot
        left_node.right_tree_size = pivot.left_tree_size + pivot.right_tree_size + 1
        OrderedTreeDict._recalculate_depth(left_node)
    
    @cython.nonecheck(False)
    cdef inline _insert(OrderedTreeDict self, object key, object value, bint replace=True):
        cdef _Node insertion_node, next_node, new_node, parent_node, prev_parent_node
        cdef size_t new_left_depth, new_right_depth, max_depth
        # Find insertion point
        insertion_node = None
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
            assert next_node.key == key
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
        new_node.left = None
        new_node.left_tree_size = 0
        new_node.right = None
        new_node.right_tree_size = 0
        
        # Insert at the correct place in the tree
        if insertion_node is None:
            # No other nodes in tree
            self.root = new_node
            new_node.parent_ref = None
            return
        else:
            # Compare key to find whether it should be a left or right child
            new_node.parent_ref = OrderedTreeDict._make_ref(insertion_node)
            if key < insertion_node.key:
                # insert left
                insertion_node.left = new_node
            else:
                # insert right
                insertion_node.right = new_node
        
        #Propagate subtree size information through the tree
        prev_parent_node = new_node
        parent_node = insertion_node
        while parent_node is not None:
            if prev_parent_node is parent_node.left:
                parent_node.left_tree_size += 1
            else:
                parent_node.right_tree_size += 1
            prev_parent_node = parent_node
            parent_node = OrderedTreeDict._get_parent(parent_node)
            
        # Propagate depth information through the tree
        prev_parent_node = new_node
        parent_node = insertion_node
        if (parent_node.left is not None) ^ (parent_node.right is not None):
            # New node doesn't have a sibling, depth has changed.
            parent_node.depth += 1
            while parent_node is not None:
        
                new_left_depth = prev_parent_node.left.depth + 1 if prev_parent_node.left is not None else 0
                new_right_depth = prev_parent_node.right.depth + 1 if prev_parent_node.right is not None else 0
                max_depth = size_t_max(new_left_depth, new_right_depth)
        
                if prev_parent_node.depth != max_depth:
                    prev_parent_node.depth = max_depth
                else:
                    break
                
                # Perform avl tree fixup rotations
                if new_left_depth - 2 == new_right_depth:
                    # left-right
                    if OrderedTreeDict._balance_factor(prev_parent_node.left) > 0:
                        self._rotate_left(prev_parent_node.left)
                    self._rotate_right(prev_parent_node)
                elif new_left_depth + 2 == new_right_depth:
                    # left-right
                    if OrderedTreeDict._balance_factor(prev_parent_node.right) > 0:
                        self._rotate_right(prev_parent_node.right)
                    self._rotate_left(prev_parent_node)
    
            prev_parent_node = parent_node
            parent_node = OrderedTreeDict._get_parent(prev_parent_node)
    
    @cython.nonecheck(False)
    cpdef put(OrderedTreeDict self, object key, object value):
        self._insert(key, value)

    @cython.nonecheck(False)
    cdef inline _delete(OrderedTreeDict self, object key):
        """
        
	BOSNode *bubble_up = NULL;

	// If this node has children on both sides, bubble one of it upwards
	// and rotate within the subtrees.
	if(node->left_child_node && node->right_child_node) {
		BOSNode *candidate = NULL;
		BOSNode *lost_child = NULL;
		if(node->left_child_node->depth >= node->right_child_node->depth) {
			// Left branch is deeper than right branch, might be a good idea to
			// bubble from this side to maintain the AVL property with increased
			// likelihood.
			node->left_child_count--;
			candidate = node->left_child_node;
			while(candidate->right_child_node) {
				candidate->right_child_count--;
				candidate = candidate->right_child_node;
			}
			lost_child = candidate->left_child_node;
		}
		else {
			node->right_child_count--;
			candidate = node->right_child_node;
			while(candidate->left_child_node) {
				candidate->left_child_count--;
				candidate = candidate->left_child_node;
			}
			lost_child = candidate->right_child_node;
		}

		BOSNode *bubble_start = candidate->parent_node;
		if(bubble_start->left_child_node == candidate) {
			bubble_start->left_child_node = lost_child;
		}
		else {
			bubble_start->right_child_node = lost_child;
		}
		if(lost_child) {
			lost_child->parent_node = bubble_start;
		}

		// We will later rebalance upwards from bubble_start up to candidate.
		// But first, anchor candidate into the place where "node" used to be.

		if(node->parent_node) {
			if(node->parent_node->left_child_node == node) {
				node->parent_node->left_child_node = candidate;
			}
			else {
				node->parent_node->right_child_node = candidate;
			}
		}
		else {
			tree->root_node = candidate;
		}
		candidate->parent_node = node->parent_node;

		candidate->left_child_node = node->left_child_node;
		candidate->left_child_count = node->left_child_count;
		candidate->right_child_node = node->right_child_node;
		candidate->right_child_count = node->right_child_count;

		if(candidate->left_child_node) {
			candidate->left_child_node->parent_node = candidate;
		}

		if(candidate->right_child_node) {
			candidate->right_child_node->parent_node = candidate;
		}

		// From here on, node is out of the game.
		// Rebalance up to candidate.

		if(bubble_start != node) {
			while(bubble_start != candidate) {
				bubble_start->depth = _imax((bubble_start->left_child_node ? bubble_start->left_child_node->depth + 1 : 0),
					(bubble_start->right_child_node ? bubble_start->right_child_node->depth + 1 : 0));
				int balance = _bostree_balance(bubble_start);
				if(balance > 1) {
					// Rotate left. Check for right-left case before.
					if(_bostree_balance(bubble_start->right_child_node) < 0) {
						_bostree_rotate_right(tree, bubble_start->right_child_node);
					}
					bubble_start = _bostree_rotate_left(tree, bubble_start);
				}
				else if(balance < -1) {
					// Rotate right. Check for left-right case before.
					if(_bostree_balance(bubble_start->left_child_node) > 0) {
						_bostree_rotate_left(tree, bubble_start->left_child_node);
					}
					bubble_start = _bostree_rotate_right(tree, bubble_start);
				}
				bubble_start = bubble_start->parent_node;
			}
		}

		// Fixup candidate's depth
		candidate->depth = _imax((candidate->left_child_node ? candidate->left_child_node->depth + 1 : 0),
			(candidate->right_child_node ? candidate->right_child_node->depth + 1 : 0));

		// We'll have to fixup child counts and depths up to the root, do that
		// later.
		bubble_up = candidate->parent_node;

		// Fix immediate parent node child count here.
		if(bubble_up) {
			if(bubble_up->left_child_node == candidate) {
				bubble_up->left_child_count--;
			}
			else {
				bubble_up->right_child_count--;
			}
		}
	}
	else {
		// If this node has children on one side only, removing it is much simpler.
		if(!node->parent_node) {
			// Simple case: Node _was_ the old root.
			if(node->left_child_node) {
				tree->root_node = node->left_child_node;
				if(node->left_child_node) {
					node->left_child_node->parent_node = NULL;
				}
			}
			else {
				tree->root_node = node->right_child_node;
				if(node->right_child_node) {
					node->right_child_node->parent_node = NULL;
				}
			}

			// No rebalancing to do
			bubble_up = NULL;
		}
		else {
			BOSNode *candidate = node->left_child_node;
			int candidate_count = node->left_child_count;
			if(node->right_child_node) {
				candidate = node->right_child_node;
				candidate_count = node->right_child_count;
			}

			if(node->parent_node->left_child_node == node) {
				node->parent_node->left_child_node = candidate;
				node->parent_node->left_child_count = candidate_count;
			}
			else {
				node->parent_node->right_child_node = candidate;
				node->parent_node->right_child_count = candidate_count;
			}

			if(candidate) {
				candidate->parent_node = node->parent_node;
			}

			// Again, from here on, the original node is out of the game.
			// Rebalance up to the root.
			bubble_up = node->parent_node;
		}
	}

	// At this point, everything below and including bubble_start is
	// balanced, and we have to look further up.

	char bubbling_finished = 0;
	while(bubble_up) {
		if(!bubbling_finished) {
			// Calculate updated depth for bubble_up
			unsigned int left_depth = bubble_up->left_child_node ? bubble_up->left_child_node->depth + 1 : 0;
			unsigned int right_depth = bubble_up->right_child_node ? bubble_up->right_child_node->depth + 1 : 0;
			unsigned int new_depth = _imax(left_depth, right_depth);
			char depth_changed = (new_depth != bubble_up->depth);
			bubble_up->depth = new_depth;

			// Rebalance bubble_up
			// Not necessary for the first node, but calling _bostree_balance once
			// isn't that much overhead.
			int balance = _bostree_balance(bubble_up);
			if(balance < -1) {
				if(_bostree_balance(bubble_up->left_child_node) > 0) {
					_bostree_rotate_left(tree, bubble_up->left_child_node);
				}
				bubble_up = _bostree_rotate_right(tree, bubble_up);
			}
			else if(balance > 1) {
				if(_bostree_balance(bubble_up->right_child_node) < 0) {
					_bostree_rotate_right(tree, bubble_up->right_child_node);
				}
				bubble_up = _bostree_rotate_left(tree, bubble_up);
			}
			else {
				if(!depth_changed) {
					// If we neither had to rotate nor to change the depth,
					// then we are obviously finished.  Only update child
					// counts from here on.
					bubbling_finished = 1;
				}
			}
		}

		if(bubble_up->parent_node) {
			if(bubble_up->parent_node->left_child_node == bubble_up) {
				bubble_up->parent_node->left_child_count--;
			}
			else {
				bubble_up->parent_node->right_child_count--;
			}
		}
		bubble_up = bubble_up->parent_node;
	}

	node->weak_ref_node_valid = 0;
	bostree_node_weak_unref(tree, node);
        """

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

    @staticmethod
    @cython.nonecheck(False)
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

    @cython.nonecheck(False)
    def items(OrderedTreeDict self):
        """ Returns an iterator over (key, value) pairs."""
        cdef _Node node = self.root
        cdef MemStack stack
        if node is None:
            return
        try:
            stack = MemStack(node.left_tree_size+node.right_tree_size+1)
        except MemoryError:
            raise MemoryError("Not enough memory to iterate a tree this deep.")
        while node is not None:
            stack.c_push(node)
            node = node.left
        while stack.num_items > 0:
            node = stack.c_pop()
            yield (node.key, node.value)
            node = node.right
            while node is not None:
                stack.c_push(node)
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
        cdef object retval = self._get_node(key)
        self._delete(key)
        return retval

    @staticmethod
    @cython.nonecheck(False)
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
    def max(OrderedTreeDict self):
        cdef _Node max_node = OrderedTreeDict._maximum(self.root)
        return max_node.key, max_node.value
    
    @staticmethod
    @cython.nonecheck(False)
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
    def min(OrderedTreeDict self):
        cdef _Node min_node = OrderedTreeDict._minimum(self.root)
        return min_node.key, min_node.value
    
    @cython.nonecheck(False)
    def select(OrderedTreeDict self, size_t i):
        cdef _Node node = self.root
        if node is None:
            raise IndexError()
        cdef size_t l = node.left_tree_size
        while i != l and node is not None:
            l = node.left_tree_size
            if i < l:
                node = node.left
            else:
                node = node.right
                i = i - (l + 1)
        if node is None:
            raise IndexError()
        return node.key, node.value
    
    @cython.nonecheck(False)
    def rank(OrderedTreeDict self, object key):
        cdef _Node node = self._get_node(key)
        cdef size_t rank = node.left_tree_size + 1
        cdef _Node parent_node = OrderedTreeDict._get_parent(node)
        while parent_node is not None:
            if node is parent_node.right:
                rank = rank + parent_node.left_tree_size + 1
            node = parent_node
            parent_node = OrderedTreeDict._get_parent(parent_node)
        return rank - 1
    
    @cython.nonecheck(False)
    def __getitem__(OrderedTreeDict self, object key):
        cdef _Node node = self._get_node(key)
        return node.value
    
    @cython.nonecheck(False)
    def __setitem__(OrderedTreeDict self, object key, object value):
        self._insert(key, value)
        
    @cython.nonecheck(False)
    def __delitem__(OrderedTreeDict self, object key):
       self._delete(key)

    @cython.nonecheck(False)
    def __contains__(OrderedTreeDict self, object key):
        return self._get_node(key, raise_on_missing=False) is not None
    
    @cython.nonecheck(False)
    def __iter__(OrderedTreeDict self):
        """ Returns an iterator over (key, value) pairs."""
        return self.items()

    @cython.nonecheck(False)
    def __reversed__(OrderedTreeDict self):
       cdef _Node node = self.root
       cdef MemStack stack
       if node is None:
           return
       try:
           stack = MemStack(node.depth)
       except MemoryError:
           raise MemoryError("Not enough memory to iterate a tree this deep.")
       while node is not None:
           stack.c_push(node)
           node = node.right
       while stack.num_items > 0:
           node = stack.c_pop()
           yield (node.key, node.value)
           node = node.left
           while node is not None:
               stack.c_push(node)
               node = node.right
 
    @cython.nonecheck(False)
    def __len__(OrderedTreeDict self):
        if self.root is None:
            return 0
        return self.root.left_tree_size + self.root.right_tree_size + 1
