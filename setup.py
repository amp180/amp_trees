from setuptools import setup, find_packages
import builtins
import glob


builtins.SETUP = True
__version__ = "0.0.1a0"


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
    if glob.glob("amp_trees/*.pyx"):
        USING_CYTHON = True
    else:
        USING_CYTHON = False


# Build from .pyx files if cython is installed, otherwise assume installing from sdist and c files exist.
ext = '.pyx' if USING_CYTHON else '.c'
treeset = Extension("amp_trees.treeset", ["amp_trees/treeset"+ext])
treemap = Extension("amp_trees.treemap", ["amp_trees/treemap"+ext])
memstack = Extension("amp_trees.memstack", ["amp_trees/memstack"+ext])

modules = [treeset, treemap, memstack]

# generate .c files
if USING_CYTHON:
    modules = cythonize(modules, gdb_debug=True)

setup(
    name="amp_trees",
    license="MIT",
    ext_modules=modules,
    packages=find_packages(),
    package_data={'amp_trees': glob.glob("amp_trees/*.((pyx)|(.pxd)|(c))"),}, # Include pyx and c files in sdist
    include_package_data=True, # Don't install the pyx files with the bdist.
    version=__version__,
    cmdclass = {'build_ext': build_ext} if USING_CYTHON else {}

)
