extends Node

var music_player: AudioStreamPlayer
@export var default_volume_db: float = -15.0  # Adjust this in the editor

func _ready():
	# Create an AudioStreamPlayer
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Load the music file
	var music = load("res://sounds/gamemusic.mp3")
	music_player.stream = music
	
	# Set volume
	music_player.volume_db = default_volume_db
	
	# Connect finished signal for looping
	music_player.finished.connect(_on_music_finished)
	
	# Play the music
	music_player.play()

func _on_music_finished():
	music_player.play()

# Easy volume control methods
func set_volume(volume_db: float):
	"""Set volume in decibels (-80 to 0, where 0 is max)"""
	music_player.volume_db = volume_db

func set_volume_percent(percent: float):
	"""Set volume as percentage (0.0 to 1.0)"""
	# Convert percentage to decibels
	music_player.volume_db = linear_to_db(percent)

func get_volume_percent() -> float:
	"""Get current volume as percentage"""
	return db_to_linear(music_player.volume_db)

func mute():
	music_player.volume_db = -80

func unmute():
	music_player.volume_db = default_volume_db

func stop_music():
	music_player.stop()

func play_music():
	if not music_player.playing:
		music_player.play()
