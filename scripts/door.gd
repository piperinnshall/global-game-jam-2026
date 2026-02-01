extends Area2D

# Reference to the key this door depends on
@export var key: NodePath 

# Optional scene to change to when door opens
@export var next_scene: String = ""  # Path to scene, e.g., "res://scenes/Level2.tscn"

# Node references
@onready var sprite_open: Sprite2D = $Open
@onready var sprite_closed: Sprite2D = $Closed
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var black_rect: ColorRect = $BlackRect  # Optional black rectangle covering door

# Animation settings
@export var open_duration: float = 1.0  # Shrink duration in seconds

# State
var is_opening: bool = false

func _ready() -> void:
	# Start with closed door visible
	sprite_open.visible = false
	sprite_closed.visible = true
	collision_shape.disabled = false

	# Set up black rectangle (if any)
	if black_rect:
		black_rect.visible = true
		black_rect.anchor_top = 0
		black_rect.anchor_bottom = 1
		# Keep its current position and size (already placed in editor)

	# Connect collision signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Only respond to the player
	if body.name != "Player" and not body.is_in_group("player"):
		return

	if is_opening:
		return  # Already opening

	# Check if the player has collected the key
	var key_node = get_node_or_null(key)
	if key_node and key_node.has_method("is_collected") and key_node.is_collected():
		_start_opening()

func _start_opening() -> void:
	is_opening = true

	# Show open sprite and hide closed
	sprite_closed.visible = false
	sprite_open.visible = true

	# Disable collision safely (deferred) to avoid flushing queries error
	collision_shape.set_deferred("disabled", true)

	# Animate black rectangle shrinking from top (if any)
	if black_rect:
		var tween = create_tween()
		tween.tween_property(
			black_rect, "size:y", 0.0, open_duration
		).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.chain().tween_callback(Callable(self, "_on_door_opened"))
	else:
		_on_door_opened()  # trigger immediately if no black rectangle

func _on_door_opened() -> void:
	# Hide black rectangle
	if black_rect:
		black_rect.visible = false
	exit()

func exit() -> void:
	print("exited door")

	# Change scene if a path is set
	if next_scene != "":
		var err = get_tree().change_scene_to_file(next_scene)
		if err != OK:
			push_error("Failed to change scene to: %s" % next_scene)
