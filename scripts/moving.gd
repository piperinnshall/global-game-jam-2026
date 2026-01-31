extends Node2D

@export var start_position: Vector2
@export var end_position: Vector2
@export var speed: float = 100.0  # Units per second
@export var wait_time: float = 0.5

var _target: Vector2
var _waiting := false
var velocity := Vector2.ZERO
var _progress := 0.0  # Tracks lerp progress from 0 to 1

func _ready():
	position = start_position
	_target = end_position
	_progress = 0.0

func _process(delta):
	if _waiting:
		velocity = Vector2.ZERO
		return

	var start_pos = start_position if _target == end_position else end_position
	var distance = start_pos.distance_to(_target)
	if distance == 0:
		return

	# Increase progress by delta proportional to speed
	_progress += speed * delta / distance
	if _progress > 1.0:
		_progress = 1.0

	# Apply ease-in-out: smooth start and stop
	var eased_progress = _ease_in_out(_progress)

	# Calculate new position
	var new_position = start_pos.lerp(_target, eased_progress)
	velocity = (new_position - position) / delta
	position = new_position

	# If reached target, reset progress and wait
	if _progress >= 1.0:
		_progress = 0.0
		_wait_and_switch()

func _wait_and_switch():
	_waiting = true
	await get_tree().create_timer(wait_time).timeout
	_target = start_position if _target == end_position else end_position
	_waiting = false

# Simple ease-in-out function using sine
func _ease_in_out(t):
	return -0.5 * (cos(PI * t) - 1)
