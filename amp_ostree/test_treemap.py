from unittest import TestCase, main
from amp_ostree.treemap import OrderedTreeDict
from random import randint
import timeit
import math


class OrderedTreeDictTest(TestCase):
    
    @staticmethod
    def test_insertion_left_and_right():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.depth() <= 2, "Not balanced."
    
    @staticmethod
    def test_insertion_right_right():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(1, 1)
        d.put(2, 2)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.depth() == 2, "Not balanced."
        
    @staticmethod
    def test_insertion_right_left():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(2, 2)
        d.put(1, 1)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.depth() == 2, "Not balanced."

    @staticmethod
    def test_insertion_left_right():
        d = OrderedTreeDict()
        d.put(0,0)
        d.put(-2, -2)
        d.put(-1, -1)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.depth() == 2, "Not balanced."

    @staticmethod
    def test_insertion_left_left():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(-2, -2)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.depth() == 2, "Not balanced."
        
    @staticmethod
    def test_sorted():
        """A test to ensure the tree maintains sorted order."""
        keys = list(set([randint(0, 2^64) for i in range(0, 128)]))
        items = [(key, None) for key in keys]
        d = OrderedTreeDict(items)
        assert len(keys) == len(d)
        assert len(keys) == len(list(d))
        assert list(sorted(keys)) == list(d.keys())
        
    @staticmethod
    def test_select():
        """A test to check that select finds the nth item in sorted order."""
        keys = list(range(100))
        d = OrderedTreeDict((key, None) for key in keys)
        assert all(d.select(k)[0] == k for k in keys)

    @staticmethod
    def test_select_simple():
        d = OrderedTreeDict([(0, 0), (1, 1), (2, 2)])
        assert len(d) == 3
        assert (d.select(0) == (0, 0))
        assert(d.select(1) == (1, 1))
        assert (d.select(2) == (2, 2))

    @staticmethod
    def test_rank_simple():
        d = OrderedTreeDict([(0, 0), (1, 1), (2, 2)])
        assert len(d) == 3
        assert (d.rank(0) == 0)
        assert (d.rank(1) == 1)
        assert (d.rank(2) == 2)

    @staticmethod
    def test_rank():
        """A test to check that rank finds index of a key in sorted order."""
        keys = list(range(100))
        d = OrderedTreeDict((key, None) for key in keys)
        assert all(list(
            keys[d.rank(k)] == k for k in keys
        ))

    @staticmethod
    def test_rank_negative():
        """A test to check that rank finds index of a key in sorted order."""
        keys = list(range(-100, 100))
        d = OrderedTreeDict((key, None) for key in keys)
        assert all(list(
            keys[d.rank(k)] == k for k in keys
        ))
        
    @staticmethod
    def test_fuzz_insertions():
        """A test that inserts random keys into the tree and checks that they were all inserted."""
        key_range = 2**64
        value_range = 1024
        key_set = set()
        
        d = OrderedTreeDict()
        for value in range(0, value_range):
            key = randint(0, key_range)
            d.put(key, value)
            key_set.add(key)
        
        keys = list(d.keys())
        assert len(keys) == len(key_set), "Length should reflect number of items inserted."
        assert len(keys) == len(list(keys)), "Iteration should find all items in tree."
        assert d.depth() <= math.ceil(1.44*math.log2(len(d))), "Should stay as balanced as an avl tree as long as " \
                                                               "there are only insertions. "

    @staticmethod
    def test_deletion():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert 0 in d
        d.delete(0)
        assert len(d) == 2
        assert 0 not in d
        d.delete(1)
        assert len(d) == 1
        assert 1 not in d

    @staticmethod
    def test_successor():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        assert d.successor(-1) == (0, 0)
        assert d.successor(0) == (1, 1)

    @staticmethod
    def test_predecessor():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        assert d.predecessor(0) == (-1, -1)
        assert d.predecessor(1) == (0, 0)

    @staticmethod
    def test_perf_min():
        """Tests that finding the smallest key of a large treedict is faster than using dict."""
        dict_time = timeit.timeit(
            "min(keys_dict.keys())",
            setup="keys_dict = {key: key for key in range(-1000, 1000)}",
            number=1000
        )
        dict_sort_time = timeit.timeit(
            "sorted(keys_dict.keys())[1]",
            setup="keys_dict = {key: key for key in range(1000, -1000, -1)}",
            number=1000
        )
        tree_time = timeit.timeit(
            "keys_tree.min()",
            setup="from amp_ostree import OrderedTreeDict;"
                  "keys_tree = OrderedTreeDict((key, key) for key in range(-1000, 1000))",
            number=1000
        )
        assert dict_time > tree_time, "Min method is slow."
        assert dict_sort_time > tree_time, "Max method is slow."

    @staticmethod
    def test_perf_max():
        """Tests that finding the largest key of a large treedict is faster than using dict."""
        dict_time = timeit.timeit(
            "max(keys_dict.keys())",
            setup="keys_dict = {key: key for key in range(1000, -1000, -1)}",
            number=1000
        )
        dict_sort_time = timeit.timeit(
            "sorted(keys_dict.keys())[-1]",
            setup="keys_dict = {key: key for key in range(1000, -1000, -1)}",
            number=1000
        )
        tree_time = timeit.timeit(
            "keys_tree.max()",
            setup="from amp_ostree import OrderedTreeDict;"
                  "keys_tree = OrderedTreeDict((key, key) for key in range(1000, -1000, -1))",
            number=1000
        )
        assert dict_time > tree_time, "Max method is slow."
        assert dict_sort_time > tree_time, "Max method is slow."


if __name__ == "__main__":
    main()
