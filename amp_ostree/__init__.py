import builtins

__version__ = "0.0.1a0"


if not getattr(builtins, 'SETUP', False):
    from amp_ostree.treemap import OrderedTreeDict
    from amp_ostree.treeset import *

if __name__=="__main__":
    d = OrderedTreeDict()
    d.put(0,0)
    d.put(1,0)