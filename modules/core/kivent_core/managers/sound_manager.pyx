from kivy.core.audio import SoundLoader
from kivy._event cimport EventDispatcher
from kivy.clock import Clock
from kivy.properties import NumericProperty, StringProperty, BooleanProperty
from random import choice, uniform

cdef class SoundManager(EventDispatcher):
    '''
    The SoundManager provides additional features on top of Kivy's Sound and
    SoundLoader classes, making it easier for you to integrate sounds into
    your game, and controlling the ability to play the same sound multiple
    times simultaneously.
    '''
    music_volume = NumericProperty(.6)
    sound_volume = NumericProperty(.6)
    cutoff = NumericProperty(.015)
    current_track = StringProperty(None, allownone=True)
    max_wait_for_music = NumericProperty(30.)
    loop_music = BooleanProperty(False)

    def __init__(self, **kwargs):
        super(SoundManager, self).__init__(**kwargs)
        self.sound_dict = {}
        self.music_dict = {}
        self.sound_keys = {}
        self.sound_count = 0

    property music_dict:
        def __get__(self):
            return self.music_dict

    def load_music(self, track_name, file_address):
        track = SoundLoader.load(file_address)
        track.bind(on_stop=self.on_track_stop)
        self.music_dict[track_name] = {
            'file_address': file_address,
            'track': track
        }
        return track_name

    def on_track_stop(self, sound):
        print('track stopped', sound)
        if self.loop_music:
            Clock.schedule_once(
                lambda dt: self.play_track(choice(self.music_dict.keys())),
                uniform(0., self.max_wait_for_music)
                )
            
    def on_music_volume(self, instance, value):
        if self.current_track is not None:
            self.music_dict[self.current_track]['track'].volume = value

    def play_track(self, track_name):
        track = self.music_dict[track_name]['track']
        if self.current_track is not None:
            self.stop_current_track()
        track.volume = self.music_volume
        track.play()
        self.current_track = track_name

    def stop_current_track(self):
        self.music_dict[self.current_track]['track'].stop()
        self.current_track = None

        
    def load_sound(self, sound_name, file_address, track_count=4):
        '''
        Loads a sound, will load track_count copies of the sound so that 
        up to that many sounds can be played at the same time. Actual number
        of sounds played will be limited by the number of sound channels
        available. Returns the integer identifier for the sound to be used
        with the higher performance **play_direct**, **play_direct_loop**, 
        and **stop_direct** functions as well as making it easier to 
        store sounds in high performance C components for your entities.

        Args:
            sound_name (str): The name to load the sound file under.

            file_address (Str): The actual location of the file in memory.

        Kwargs:
            track_count (int): The number of times to load the sound,
            equivalent to the maximum number of instances of this sound
            can be played simultaneously. Defaults to 4.

        Return:
            int: the integer identifier for the loaded sound.
        '''
        count = self.sound_count
        sound_list = []
        self.sound_dict[count] = {
            'file_address': file_address,
            'sounds': sound_list,
        } 
        for x in range(track_count):
            sound = SoundLoader.load(file_address)
            sound_list.append(sound)
        self.sound_keys[sound_name] = count
        self.sound_count += 1

        return count

    cpdef play_direct(self, int sound_index, float volume):
        if volume <= self.cutoff:
            return None
        cdef list sounds = self.sound_dict[sound_index]['sounds']
        for each in sounds:
            if each.state == 'play':
                continue
            else:
                each.volume = volume * self.sound_volume
                each.play()
                return each
        else:
            return None

    cpdef play_direct_loop(self, int sound_index, float volume):
        cdef list sounds = self.sound_dict[sound_index]['sounds']
        if volume <= self.cutoff:
            return None
        for each in sounds:
            if each.state == 'play':
                continue
            else:
                each.volume = volume * self.sound_volume
                each.loop = True
                each.play()
                return each
        else:
            return None

    cpdef stop_direct(self, int sound_index):
        cdef list sounds = self.sound_dict[sound_index]['sounds']
        for each in sounds:
            each.stop()
            each.loop = False

    def schedule_play(self, sound_name, volume, dt):
        self.play(sound_name, volume=volume)

    def play(self, sound_name, volume=1.):
        self.play_direct(self.sound_keys[sound_name], volume)

    def play_loop(self, sound_name, volume=1.):
        self.play_direct_loop(self.soud_keys[sound_name], volume)

    def stop(self, sound_name):
        self.stop_direct(self.sound_keys[sound_name])