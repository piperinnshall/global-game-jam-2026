extends AnimatableBody2D

enum MoveDirection {
	HORIZONTAL,
	VERTICAL
}

@export var direction: MoveDirection = MoveDirection.HORIZONTAL
@export var start_offset: float = 0.0  # Distance from starting position
@export var end_offset: float = 200.0  # Distance to travel
@export var speed: float = 100.0  # Units per second
@export var wait_time: float = 0.5

var _start_position: Vector2
var _end_position: Vector2
var _target: Vector2
var _waiting := false
var _progress := 0.0  # Tracks lerp progress from 0 to 1

func _ready():
	# Calculate start and end positions based on direction
	_start_position = global_position
	
	if direction == MoveDirection.HORIZONTAL:
		_start_position.x += start_offset
		_end_position = _start_position + Vector2(end_offset, 0)
	else:  # VERTICAL
		_start_position.y += start_offset
		_end_position = _start_position + Vector2(0, end_offset)
	
	global_position = _start_position
	_target = _end_position
	_progress = 0.0
	
	# AnimatableBody2D automatically handles platform movement
	sync_to_physics = true

func _process(delta):
	if _waiting:
		return
	
	var start_pos = _start_position if _target == _end_position else _end_position
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
	
	# Use global_position for AnimatableBody2D
	global_position = new_position
	
	# If reached target, reset progress and wait
	if _progress >= 1.0:
		_progress = 0.0
		_wait_and_switch()

func _wait_and_switch():
	_waiting = true
	await get_tree().create_timer(wait_time).timeout
	_target = _start_position if _target == _end_position else _end_position
	_waiting = false

# Simple ease-in-out function using sine
func _ease_in_out(t):
	return -0.5 * (cos(PI * t) - 1)
