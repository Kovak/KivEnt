KivEnt Installation Guide
====

This is an installation guide for setting up KivEnt on Ubuntu 13.10.

Before we begin, you will need the following:


Cython >= 0.20 

Kivy (Master branch.)

Cymunk (for physics and collision detection)


Installation:
===

To install Kivy you must first install the dependences:
```
sudo apt-get install pkg-config python-setuptools python-pygame python-opengl \
  python-gst0.10 python-enchant gstreamer0.10-plugins-good python-dev \
  build-essential libgl1-mesa-dev libgles2-mesa-dev cython
```
Then update Cython ether:

with Pip:
```
sudo apt-get install python-pip
sudo pip install --upgrade cython
```

or without pip:
```
sudo add-apt-repository ppa:cython-dev/master-ppa
sudo apt-get update
sudo apt-get install cython
```

And then install kivy itself:
```
sudo add-apt-repository ppa:kivy-team/kivy
sudo apt-get update
sudo apt-get install python-kivy
```


To install Cymunk, do the following:
```
git clone https://github.com/tito/cymunk.git
cd cymunk
make
```
Before installing KivEnt, you will need to add some python paths.

To do this, you will fristly need to run file manager as root (```sudo nautilus```), 
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

