from os import environ, remove
from os.path import dirname, join, isfile
from distutils.core import setup
from distutils.extension import Extension
import kivy
try:
    from Cython.Build import cythonize
    from Cython.Distutils import build_ext
    have_cython = True
except ImportError:
    have_cython = False
import sys

__VERSION__ = 'unknown'
# importing kivent_core has side effects
exec(open('kivent_core/version.py').read())

platform = sys.platform
if platform == 'win32':
    cstdarg = '-std=gnu99'
    libraries=['opengl32', 'glu32','glew32']
else:
    cstdarg = '-std=c99'
    libraries=[]

do_clear_existing = False

prefixes = {
    'core': 'kivent_core.',
    'memory_handlers': 'kivent_core.memory_handlers.',
    'rendering': 'kivent_core.rendering.',
    'managers': 'kivent_core.managers.',
    'uix': 'kivent_core.uix.',
    'systems': 'kivent_core.systems.'
}

file_prefixes = {
    'core': 'kivent_core/',
    'memory_handlers': 'kivent_core/memory_handlers/',
    'rendering': 'kivent_core/rendering/',
    'managers': 'kivent_core/managers/',
    'uix': 'kivent_core/uix/',
    'systems': 'kivent_core/systems/'
}

modules = {
    'core': ['entity', 'gameworld'],
    'memory_handlers': ['block', 'membuffer', 'indexing', 'pool', 'utils', 
        'zone', 'tests', 'zonedblock'],
    'rendering': ['gl_debug', 'vertex_format', 'fixedvbo', 'cmesh', 'batching', 
        'vertex_format', 'frame_objects','vertex_formats', 'model'],
    'managers': ['resource_managers', 'system_manager', 'entity_manager'],
    'uix': ['cwidget', 'gamescreens'],
    'systems': ['gamesystem', 'staticmemgamesystem', 'position_systems',
        'gameview', 'scale_systems', 'rotate_systems', 'color_systems',
        'gamemap', 'renderers'],

}
core_modules = {}
core_modules_c = {}
check_for_removal = []

for name in modules:
    file_prefix = file_prefixes[name]
    prefix = prefixes[name]
    module_files = modules[name]
    for module_name in module_files:
        core_modules[prefix+module_name] = [file_prefix + module_name + '.pyx']
        core_modules_c[prefix+module_name] = [file_prefix + module_name + '.c']
        check_for_removal.append(file_prefix + module_name + '.c')


def build_ext(ext_name, files, include_dirs=[]):
    return Extension(ext_name, files, include_dirs,
        extra_compile_args=[cstdarg, '-ffast-math',],
        libraries=libraries)

extensions = []
cymunk_extensions = []
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
    core_extensions = build_extensions_for_modules_cython(
        extensions, core_modules)
else:
    core_extensions = build_extensions_for_modules(extensions, core_modules_c)


setup(
    name='KivEnt Core',
    version=__VERSION__,
    description='''A game engine for the Kivy Framework. 
        https://github.com/Kovak/KivEnt for more info.''',
    author='Jacob Kovac',
    author_email='kovac1066@gmail.com',
    ext_modules=core_extensions,
    cmdclass=cmdclass,
    packages=[
        'kivent_core',
        'kivent_core.memory_handlers',
        'kivent_core.rendering',
        'kivent_core.managers',
        'kivent_core.systems',
        'kivent_core.uix'
        ],
    package_dir={'kivent_core': 'kivent_core'},
    package_data={'kivent_core': [
        '*.pxd', 
        'memory_handlers/*.pxd',
        'rendering/*.pxd',
        'managers/*.pxd',
        'systems/*.pxd',
        'uix/*.pxd'
        ]
        },)
