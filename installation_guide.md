KivEnt Installation Guide
====

This is an installation guide for setting up KivEnt on Ubuntu 13.10.

Before we begin, you will need the following:

pip

Cython >= 0.20 

Kivy (master branch. To install kivy please go to http://kivy.org/docs/installation/installation-linux.html and follow the installation instuctions)

Cymunk (for physics and collision detection)

Installation:

```
To install Cymunk, do the following:
```
git clone https://github.com/tito/cymunk.git
cd cymunk
make
```
Before installing KivEnt, you will need to add some python paths.

To do this, you will fristly need to run file manager as root (sudo nautilus), 
then you will need to show hidden files (view options, show hidden files or ctrl+H) 
and look for a file named ```.bashhrc``` in the home directory.

Open ```.bashhrc``` with your favourite text editor and add these paths 
(replace ```<user>``` with your own Ubuntu username):
```
export PYTHONPATH="/home/<user>/kivy":$PYTHONPATH
export PYTHONPATH="/home/<user>/cymunk":$PYTHONPATH
export PYTHONPATH="/home/<user>/cymunk/cymunk/python":$PYTHONPATH
```
NOTE: Make sure that you restart the terminal after editing the file, 
otherwise the changes will not take effect.


To install KivEnt, do the following:
```
git clone https://github.com/Kovak/KivEnt.git
cd KivEnt/kivent
python setup.py build_ext --inplace -f
```

Created by Andrew Franks.

