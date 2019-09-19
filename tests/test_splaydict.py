from unittest import TestCase, main
from amp_trees import SplayDict
from random import randint
import timeit
import math


class SplayDictTest(TestCase):
    
    def test_insertion_left_and_right(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        self.assertEqual(len(d), 3, "Length should reflect number of items inserted,")
    
    def test_insertion_right_right(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(1, 1)
        d.put(2, 2)
        self.assertEqual(len(d), 3, "Length should reflect number of items inserted,")
    
    def test_insertion_right_left(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(2, 2)
        d.put(1, 1)
        self.assertEqual(len(d), 3, "Length should reflect number of items inserted,")

    def test_insertion_left_right(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(-2, -2)
        d.put(-1, -1)
        self.assertEqual( len(d) , 3, "Length should reflect number of items inserted,")
    
    def test_insertion_left_left(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(-2, -2)
        self.assertEqual( len(d) , 3, "Length should reflect number of items inserted,")
    
    def test_sorted(self):
        """A test to ensure the tree maintains sorted order."""
        keys = list(set([randint(0, 2^64) for i in range(0, 128)]))
        items = [(key, None) for key in keys]
        d = SplayDict(items)
        self.assertEquals(len(keys), len(d))
        self.assertEqual(len(keys) , len(list(d)))
        self.assertEqual(list(sorted(keys)) , list(d.keys()))
    
    def test_deletion(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        self.assertEqual( len(d) , 3, "Length should reflect number of items inserted,")
        self.assertIn(0, d)
        d.delete(0)
        self.assertEqual(len(d) , 2)
        self.assertNotIn(0, d)
        d.delete(1)
        self.assertEqual(len(d) , 1)
        self.assertNotIn(1 , d)
    
    def test_successor(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        self.assertEqual( d.successor(-1) , (0, 0))
        self.assertEqual( d.successor(0) , (1, 1))

    def test_predecessor(self):
        d = SplayDict()
        d.put(0, 0)
        d.put(-1, -1)
        d.put(1, 1)
        self.assertEqual( d.predecessor(0) , (-1, -1))
        self.assertEqual( d.predecessor(1) , (0, 0))

    def test_fuzz_insertions(self):
        """A test that inserts random keys into the tree and checks that they were all inserted."""
        key_range = 2 ** 64
        value_range = 1024
        key_set = set()
    
        d = SplayDict()
        for value in range(0, value_range):
            key = randint(0, key_range)
            d.put(key, value)
            key_set.add(key)
    
        keys = list(d.keys())
        self.assertEqual(len(keys), len(key_set), "Length should reflect number of items inserted.")
        self.assertEqual( len(keys), len(list(keys)), "Iteration should find all items in tree.")

    
    def test_fromkeys(self):
        """A splaydict created using fromkeys must contain the keys it was created from."""
        d = SplayDict.fromkeys(['a', 'b', 'c'], 1)
        self.assertIn('a' , d)
        self.assertIn('b' , d)
        self.assertIn('c' , d)
        self.assertEqual(d['a'] , 1)
        self.assertEqual(d['b'] , 1)
        self.assertEqual(d['c'] , 1)

    def test_pop(self):
        d = SplayDict({'a': 'a'}.items())
        self.assertEqual(d.pop('a'), ('a', 'a'))
        self.assertNotIn('a', d)
    
    def test_pop_item(self):
        d = SplayDict({'a': 'a'}.items())
        self.assertEquals(d.popitem(), ('a', 'a'))
        self.assertNotIn('a', d)

    def test_copy(self):
        d = SplayDict.fromkeys(['a', 'b'], 1)
        e = d.copy()
        self.assertIsNot(d, e)
        self.assertIn('a', e)
        self.assertIn('b', e)
        self.assertEqual(e['a'], 1)
        self.assertEqual(e['b'], 1)
    
    def test_clear(self):
        s = "String1235"
        d = SplayDict.fromkeys(['a', 'b'], 1)
        d.clear()
        self.assertEqual(len(d), 0, "Length of a cleared dict should be 0")
        self.assertIs(d.get('b'), None, "Default return value should be none for .get()")
        self.assertIs(d.get('b', s), s, "Default kwarg for .get() should be respected")
    
    def test_magic_methods(self):
        d = SplayDict()
        d['a'] = 'a'
        self.assertIn('a', d)
        self.assertEqual(d['a'], 'a')
        del d['a']
        self.assertNotIn('a', d)
        self.assertRaises(KeyError, lambda _: d['a'],  "d['nonexistant_element'] should raise KeyError")

    def test_perf_min(self):
        """Tests that finding the smallest key of a 2000-item shuffled splaydict is faster than using dict."""
        dict_time = timeit.timeit(
            "min(keys_dict.keys())",
            setup="from random import sample;"
                "keys_dict = {key: key for key in sample(range(-1000, 1000), 2000)}",
            number=1000
        )
        dict_sort_time = timeit.timeit(
            "sorted(keys_dict.keys())[1]",
            setup="from random import sample;"
                " keys_dict = {key: key for key in sample(range(-1000, 1000), 2000)}",
            number=1000
        )
        tree_time = timeit.timeit(
            "keys_tree.min()",
            setup="from amp_trees import SplayDict;"
                "from random import sample;"
                "keys_tree = SplayDict((key, key) for key in sample(range(-1000, 1000), 2000))",
            number=1000
        )
        self.assertGreater(dict_time, tree_time, "Min method is slow.")
        self.assertGreater(dict_sort_time, tree_time, "Max method is slow.")
   
    def test_perf_max(self):
        """Tests that finding the largest key of a 2000-item shuffled splaydict is faster than using dict."""
        dict_time = timeit.timeit(
            "max(keys_dict.keys())",
            setup="from random import sample;"
                "keys_dict = {key: key for key in sample(range(-1000, 1000), 2000)}",
            number=1000
        )
        dict_sort_time = timeit.timeit(
            "sorted(keys_dict.keys())[-1]",
            setup="from random import sample;"
                "keys_dict = {key: key for key in sample(range(-1000, 1000), 2000)}",
            number=1000
        )
        tree_time = timeit.timeit(
            "keys_tree.max()",
            setup="from amp_trees import SplayDict;"
                "from random import sample;"
                "keys_tree = SplayDict((key, key) for key in sample(range(-1000, 1000), 2000))",
            number=1000
        )
        self.assertGreater(dict_time, tree_time, "Max method is slow.")
        self.assertGreater(dict_sort_time, tree_time, "Max method is slow.")


if __name__ == "__main__":
    main()
