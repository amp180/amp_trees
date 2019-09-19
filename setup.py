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
cy_ext = '.pyx' if USING_CYTHON else '.c'
py_ext = '.py' if USING_CYTHON else '.c'
init = Extension("amp_trees.__init__", ["amp_trees/__init__"+py_ext])
treedict = Extension("amp_trees.treedict", ["amp_trees/treedict"+cy_ext])
splaydict = Extension("amp_trees.splaydict", ["amp_trees/splaydict"+cy_ext])

modules = [init, treedict, splaydict]

# generate .c files
if USING_CYTHON:
    modules = cythonize(modules, gdb_debug=True)

setup(
    name="amp_trees",
    license="MIT",
    ext_modules=modules,
    packages=find_packages(),
    package_data={'amp_trees': glob.glob("amp_trees/*.((pyx)|(.pxd)|(c))"),}, # Include pyx and c files in sdist
    include_package_data=True,  # Don't install the pyx files with the bdist.
    version=__version__,
    cmdclass={'build_ext': build_ext} if USING_CYTHON else {},
    install_requires=["typing_extensions",]
)
