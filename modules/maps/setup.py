from os import environ, remove
from os.path import dirname, join, isfile
import kivy

if environ.get('KIVENT_USE_SETUPTOOLS'):
    from setuptools import setup, Extension
    print('Using setuptools')
else:
    from distutils.core import setup
    from distutils.extension import Extension
    print('Using distutils')

try:
    from Cython.Build import cythonize
    from Cython.Distutils import build_ext
    have_cython = True
except ImportError:
    have_cython = False
import sys

platform = sys.platform
if platform == 'win32':
    cstdarg = '-std=gnu99'
    libraries = ['opengl32', 'glu32','glew32']
else:
    cstdarg = '-std=c99'
    libraries = []


do_clear_existing = True



particles_modules = {
    'kivent_maps.map_data': ['kivent_maps/map_data.pyx',],
    'kivent_maps.map_system': ['kivent_maps/map_system.pyx',],
    'kivent_maps.map_manager': ['kivent_maps/map_manager.pyx',],
}

particles_modules_c = {
    'kivent_maps.map_data': ['kivent_maps/map_data.c',],
    'kivent_maps.map_system': ['kivent_maps/map_system.c',],
    'kivent_maps.map_manager': ['kivent_maps/map_manager.c',],
}

check_for_removal = [
    'kivent_maps/map_data.c',
    'kivent_maps/map_system.c',
    'kivent_maps/map_manager.c',
]

def build_ext(ext_name, files, include_dirs=[]):
    return Extension(ext_name, files, include_dirs,
        extra_compile_args=[cstdarg, '-ffast-math',],
        libraries=libraries,)

extensions = []
particles_extensions = []
cmdclass = {}

def build_extensions_for_modules_cython(ext_list, modules):
    ext_a = ext_list.append
    for module_name in modules:
        ext = build_ext(module_name, modules[module_name],
            include_dirs=kivy.get_includes())
        if environ.get('READTHEDOCS', None) == 'True':
            ext.pyrex_directives = {'embedsignature': True}
        ext_a(ext)
    return cythonize(ext_list)

def build_extensions_for_modules(ext_list, modules):
    ext_a = ext_list.append
    for module_name in modules:
        ext = build_ext(module_name, modules[module_name],
            include_dirs=kivy.get_includes())
        if environ.get('READTHEDOCS', None) == 'True':
            ext.pyrex_directives = {'embedsignature': True}
        ext_a(ext)
    return ext_list

if have_cython:
    if do_clear_existing:
        for file_name in check_for_removal:
            if isfile(file_name):
                remove(file_name)
    particles_extensions = build_extensions_for_modules_cython(
        particles_extensions, particles_modules)
else:
    particles_extensions = build_extensions_for_modules(particles_extensions,
        particles_modules_c)



setup(
    name='KivEnt maps',
    version='1.0.0',
    description='''Module to render maps in the KivEnt game engine
    along with Tiled maps support.''',
    author='Meet Udeshi',
    author_email='mudeshi1209@gmail.com',
    ext_modules=particles_extensions,
    cmdclass=cmdclass,
    packages=[
        'kivent_maps',
        ],
    package_dir={'kivent_maps': 'kivent_maps'})
