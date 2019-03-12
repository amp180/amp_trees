from setuptools import setup, Extension, find_packages
from amp_ost import __version__


extension = Extension("amp_ost._ext",
                           sources=["ext_source/ost.c"],
                           )
setup(
    name="amp_ost",
    license="MIT",
    ext_modules=[extension, ],
    packages=find_packages(),
    version=__version__
)
