KivEnt 3.0
==========

KivEnt is a framework for building performant, dynamic real-time scenes in
[Kivy](http://kivy.org/#home) for Python 2 and Python 3. At the moment it is 2d
oriented. The only dependency for the `kivent_core` module is Kivy itself.
Additional modules may have other requirements, such as `kivent_cymunk` module
being based on [Chipmunk2d](https://chipmunk-physics.net/) and its
[cymunk wrapper](https://github.com/tito/cymunk).

An entity-component architecture is used to control game object state and the
logic of processing the game objects. This means that your game objects will be
made up of collections of independent components that stricly hold data; each
component corresponds to a `GameSystem` that will perform all data processing
on the components, in the update loop each frame, and as a result of user
interaction or other programmaticaly generated events. All memory for the
built-in components is allocated statically: if you would like learn more about
memory management, [read here](http://kivent.org/docs/memory_handlers.html).

KivEnt is built with a modular architecture and designed to have both a Python
API and a C-level Cython API that allows more performant access to your game
data. This makes it suitable for quickly prototyping a mechanic completely in
Python, and relatively trivial to then deeply cythonize that `GameSystem` if
you find it to be performance sensitive. This process has already been done for
the built-in components meaning they are ready for you to build new, performant
game systems on top of them.

[![Build Status](https://travis-ci.org/kivy/kivent.svg?branch=master)](https://travis-ci.org/kivy/kivent)
[![Build status](https://ci.appveyor.com/api/projects/status/au1k7hnq1ie58fx3/branch/master?svg=true)](https://ci.appveyor.com/project/KivyOrg/kivent/branch/master)

## Project Website: 
http://www.kivent.org

## Mailing List: 
https://groups.google.com/forum/#!forum/kivent

## Documentation: 
http://www.kivent.org/docs  

## Getting Started
Read the [introduction](https://github.com/kivy/KivEnt/wiki/An-Introduction-to-KivEnt) on the github wiki.

## Dependencies
KivEnt is split into modules, the core module, 'kivent_core', is dependent only on Kivy.

Other modules may have other dependecies, listed here:

### kivent_core:
* [kivy](https://github.com/kivy/kivy)

### kivent_cymunk:
* [kivy](https://github.com/kivy/kivy)
* [cymunk](https://github.com/tito/cymunk)
* [kivent_core](https://github.com/kivy/KivEnt/tree/master/modules/core)

### kivent_particles
* [kivy](https://github.com/kivy/kivy)
* [kivent_core](https://github.com/kivy/KivEnt/tree/master/modules/core)

### kivent_maps
* [kivy](https://github.com/kivy/kivy)
* [kivent_core](https://github.com/kivy/KivEnt/tree/master/modules/core)
* [python-tmx](https://savannah.nongnu.org/projects/python-tmx/)

### kivent_projectiles
* [kivy](https://github.com/kivy/kivy)
* [kivent_core](https://github.com/kivy/KivEnt/tree/master/modules/core)
* [cymunk](https://github.com/tito/cymunk)
* [kivent_cymunk](https://github.com/kivy/KivEnt/tree/master/modules/cymunk)
* [kivent_particles](https://github.com/kivy/KivEnt/tree/master/modules/particles)

## Installation
First, install all dependencies then:

### Windows
On Windows you can use the Python wheels generated for all KivEnt modules and
for Cymunk:

+ [Cymunk, Python 2.7, 32bit](https://kivy.org/downloads/appveyor/kivent/cymunk-0.0.0-cp27-cp27m-win32.whl)
+ [Cymunk, Python 2.7, 64bit](https://kivy.org/downloads/appveyor/kivent/cymunk-0.0.0-cp27-cp27m-win_amd64.whl)
+ [Cymunk, Python 3.4, 32bit](https://kivy.org/downloads/appveyor/kivent/cymunk-0.0.0-cp34-cp34m-win32.whl)
+ [Cymunk, Python 3.4, 64bit](https://kivy.org/downloads/appveyor/kivent/cymunk-0.0.0-cp34-cp34m-win_amd64.whl)
- [KivEnt Core, Python 2.7, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Core-2.2.0.dev0-cp27-cp27m-win32.whl)
- [KivEnt Core, Python 2.7, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Core-2.2.0.dev0-cp27-cp27m-win_amd64.whl)
- [KivEnt Core, Python 3.4, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Core-2.2.0.dev0-cp34-cp34m-win32.whl)
- [KivEnt Core, Python 3.4, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Core-2.2.0.dev0-cp34-cp34m-win_amd64.whl)
+ [KivEnt Cymunk, Python 2.7, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Cymunk-1.0.0-cp27-cp27m-win32.whl)
+ [KivEnt Cymunk, Python 2.7, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Cymunk-1.0.0-cp27-cp27m-win_amd64.whl)
+ [KivEnt Cymunk, Python 3.4, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Cymunk-1.0.0-cp34-cp34m-win32.whl)
+ [KivEnt Cymunk, Python 3.4, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_Cymunk-1.0.0-cp34-cp34m-win_amd64.whl)
- [KivEnt Maps, Python 2.7, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_maps-1.0.0-cp27-cp27m-win32.whl)
- [KivEnt Maps, Python 2.7, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_maps-1.0.0-cp27-cp27m-win_amd64.whl)
- [KivEnt Maps, Python 3.4, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_maps-1.0.0-cp34-cp34m-win32.whl)
- [KivEnt Maps, Python 3.4, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_maps-1.0.0-cp34-cp34m-win_amd64.whl)
+ [KivEnt Particles, Python 2.7, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_particles-1.0.0-cp27-cp27m-win32.whl)
+ [KivEnt Particles, Python 2.7, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_particles-1.0.0-cp27-cp27m-win_amd64.whl)
+ [KivEnt Particles, Python 3.4, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_particles-1.0.0-cp34-cp34m-win32.whl)
+ [KivEnt Particles, Python 3.4, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_particles-1.0.0-cp34-cp34m-win_amd64.whl)
- [KivEnt Projectiles, Python 2.7, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_projectiles-1.0.0-cp27-cp27m-win32.whl)
- [KivEnt Projectiles, Python 2.7, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_projectiles-1.0.0-cp27-cp27m-win_amd64.whl)
- [KivEnt Projectiles, Python 3.4, 32bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_projectiles-1.0.0-cp34-cp34m-win32.whl)
- [KivEnt Projectiles, Python 3.4, 64bit](https://kivy.org/downloads/appveyor/kivent/KivEnt_projectiles-1.0.0-cp34-cp34m-win_amd64.whl)

### OSX / Linux

    cd .../KivEnt/modules/core
    python setup.py build_ext install

or:

    cd .../KivEnt/modules/cymunk
    python setup.py build_ext install

If you want to install into a system python on something
like Ubuntu you may need to:

    sudo python setup.py build_ext install
    
If you would like to instead build the modules in place
and use PYTHONPATH to find them:

    cd .../KivEnt/modules/core
    python setup.py build_ext --inplace
    export PYTHONPATH=/path/to/KivEnt/modules/core:$PYTHONPATH

or:

    cd .../KivEnt/modules/cymunk
    python setup.py build_ext --inplace
    export PYTHONPATH=/path/to/KivEnt/modules/cymunk:$PYTHONPATH 

## Windows Kivy Portable Package Installation:

Open the kivy-2.7.bat (kivy-3.4.bat if using the py3 portable package)
command console and type:

    pip install https://github.com/tito/cymunk/archive/master.zip
    
Now either download and extract or git clone the KivEnt source:

    git clone https://github.com/Kovak/KivEnt.git

Assuming you have KivEnt in the root folder for the portable package,
in the kivy-2.7.bat console:

    cd KivEnt/modules/core
    python setup.py build_ext install
    #check core install
    cd ../../examples/2_basic_app
    python main.py
    cd ../../modules/cymunk
    python setup.py build_ext install
    #check that cymunk install
    cd ../../examples/6_controlling_the_viewing_area
    python main.py

## Tested On:
Tested with [master branch](https://github.com/kivy/kivy).
Python 2.7 and Python 3.4.

Tested on Android, Ubuntu, Windows, OSX; iOS coming soon!

Support
-------

If you need assistance, you can ask for help on our mailing list:

* User Group : https://groups.google.com/group/kivent
* Email      : kivent@googlegroups.com

We also have an IRC channel:

* Server  : irc.freenode.net
* Port    : 6667, 6697 (SSL only)
* Channel : #kivy

Contributing
------------

We love pull requests and discussing novel ideas. Check out our
[contribution guide](http://kivy.org/docs/contribute.html) and
feel free to improve KivEnt.

The following mailing list and IRC channel are used exclusively for
discussions about developing the Kivy framework and its sister projects:

* Dev Group : https://groups.google.com/group/kivy-dev
* Email     : kivy-dev@googlegroups.com

IRC channel:

* Server  : irc.freenode.net
* Port    : 6667, 6697 (SSL only)
* Channel : #kivy-dev

License
-------

KivEnt aims to be a full MIT licensed project. At the moment every module is
MIT, however this could change in the future. To be sure of the licensing for
a module refer to the LICENSE file inside that module.
