import builtins


__version__ = "0.0.1a0"


if not getattr(builtins, 'SETUP', False):
    from amp_ostree.memstack import *
    from amp_ostree.treemap import *
    from amp_ostree.treeset import *
