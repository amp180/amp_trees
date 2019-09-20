# amp_trees
Some tree structures written in cython.

## SplayDict
A dictionary-like container that is based on a splay tree.
It splays the last element accessed, moving it up to the root of the tree.
This means accessing a small subset of the data is faster than with a balanced tree.

## OrderedTreeDict
A dictionary-like container that is based on a size-balanced order statistic tree.
Balanced using the size of the subtrees as a metric.
Supports a select(n) operation that gets the nth element in sorted order in log(n) time.
Supports a rank(key) operation that gets the index of a key in sorted order.

# Developing
To build in-place use `python setup.py build_ext --inplace`
To build an installable package use `python setup.py bdist_wheel`
Use the tox utility or `python -m unittest` to run tests.