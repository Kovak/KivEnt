from os import environ, remove
from os.path import dirname, join, isfile
from distutils.core import setup
from distutils.extension import Extension

try:
    from Cython.Build import cythonize
    from Cython.Distutils import build_ext
    have_cython = True
except ImportError:
    have_cython = False
import sys

environ['KIVY_DOC_INCLUDE'] = '1'
import kivy

__VERSION__ = 'unknown'
exec(open('../core/kivent_core/version.py').read())

platform = sys.platform
if platform == 'win32':
    cstdarg = '-std=gnu99'
    libraries = ['opengl32', 'glu32','glew32']
else:
    cstdarg = '-std=c99'
    libraries = []


do_clear_existing = True



particles_modules = {
    'kivent_particles.particle': ['kivent_particles/particle.pyx'],
    'kivent_particles.emitter': ['kivent_particles/emitter.pyx',],
    'kivent_particles.particle_formats': ['kivent_particles/particle_formats.pyx',],
    'kivent_particles.particle_renderers': ['kivent_particles/particle_renderers.pyx',],
}

particles_modules_c = {
    'kivent_particles.particle': ['kivent_particles/particle.c',],
    'kivent_particles.emitter': ['kivent_particles/emitter.c',],
    'kivent_particles.particle_formats': ['kivent_particles/particle_formats.c',],
    'kivent_particles.particle_renderers': ['kivent_particles/particle_renderers.c',],
}

check_for_removal = [
    'kivent_particles/particle.c',
    'kivent_particles.emitter.c',
    'kivent_particles/particle_formats.c',
    'kivent_particles/particle_renderers.c',

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
    name='KivEnt particles',
    version=__VERSION__,
    description='''A game engine for the Kivy Framework. 
        https://github.com/Kovak/KivEnt for more info.''',
    author='Jacob Kovac',
    author_email='kovac1066@gmail.com',
    ext_modules=particles_extensions,
    cmdclass=cmdclass,
    packages=[
        'kivent_particles',
        ],
    package_dir={'kivent_particles': 'kivent_particles'})
