from setuptools import setup, find_packages
import builtins
import glob

builtins.SETUP = True
from amp_ostree import __version__


# Check if cython is installed.
try:
    from Cython.Build import cythonize
    from Cython.Distutils.extension import Extension
    from Cython.Distutils import build_ext
    from Cython.Compiler import Options
    Options.annotate = True
except ImportError:
    from setuptools import Extension
    USING_CYTHON = False
else:
    USING_CYTHON = True


# Build from .pyx files if cython is installed, otherwise assume installing from sdist and c files exist.
ext = '.pyx' if USING_CYTHON else '.c'
treeset = Extension("amp_ostree.treeset", ["amp_ostree/treeset"+ext])
treemap = Extension("amp_ostree.treemap", ["amp_ostree/treemap"+ext])

modules = [treeset, treemap]

# generate .c files
if USING_CYTHON:
    modules = cythonize(modules, gdb_debug=True)

setup(
    name="amp_ostree",
    license="MIT",
    ext_modules=modules,
    packages=find_packages(),
    package_data={'amp_ostree': glob.glob("amp_ostree/*.((pyx)|(c))"),}, # Include pyx and c files in sdist
    include_package_data=False, # Don't install the pyx files with the bdist.
    version=__version__,
    cmdclass = {'build_ext': build_ext} if USING_CYTHON else {}

)
