import builtins


__version__ = "0.0.1a0"


if not getattr(builtins, 'SETUP', False):
    from amp_trees.memstack import *
    from amp_trees.treemap import *
    from amp_trees.treeset import *
