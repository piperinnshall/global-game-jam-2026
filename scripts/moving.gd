extends Node2D

@export var start_position: Vector2
@export var end_position: Vector2
@export var speed: float = 100.0
@export var wait_time: float = 0.5

var _target: Vector2
var _waiting := false

func _ready():
	position = start_position
	_target = end_position

func _process(delta):
	if _waiting:
		return

	position = position.move_toward(_target, speed * delta)

	if position == _target:
		_wait_and_switch()

func _wait_and_switch():
	_waiting = true
	await get_tree().create_timer(wait_time).timeout
	_target = start_position if _target == end_position else end_position
	_waiting = false
