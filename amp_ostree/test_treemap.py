from unittest import TestCase, main
from amp_ostree.treemap import OrderedTreeDict
from random import randint
import timeit


class OrderedTreeDictTest(TestCase):
    
    @staticmethod
    def test_insertion_left_and_right():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.root.depth == 1, "Not balanced."
    
    @staticmethod
    def test_insertion_right_right():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(1, 1)
        d.put(2, 2)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.root.depth == 1, "Not balanced."
        
    @staticmethod
    def test_insertion_right_left():
        d = OrderedTreeDict()
        d.put(0,0)
        d.put(2, 2)
        d.put(1, 1)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.root.depth == 1, "Not balanced."

    @staticmethod
    def test_insertion_left_right():
        d = OrderedTreeDict()
        d.put(0,0)
        d.put(-2, -2)
        d.put(-1, -1)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.root.depth == 1, "Not balanced."

    @staticmethod
    def test_insertion_left_left():
        d = OrderedTreeDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(-2, -2)
        assert len(d) == 3, "Length should reflect number of items inserted,"
        assert d.root.depth == 1, "Not balanced."
        
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
