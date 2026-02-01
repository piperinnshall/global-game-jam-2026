extends Area2D

# Multi-line text export
@export_multiline var display_text: String

# Fade-out duration in seconds
@export var fade_duration: float = 1.0

# Node references
@onready var label: Label = $Label

# Keep track of the current fade tween so we can stop it
var fade_tween: Tween = null

func _ready() -> void:
	# Initially hide the label
	label.text = ""
	label.modulate.a = 1.0

	# Connect signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		# Stop any fading tween
		if fade_tween and fade_tween.is_valid():
			fade_tween.kill()
			fade_tween = null

		# Show text instantly
		label.text = display_text
		label.modulate.a = 1.0

func _on_body_exited(body: Node) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		# Fade out smoothly only if the player is gone
		fade_tween = create_tween()
		fade_tween.tween_property(label, "modulate:a", 0.0, fade_duration)
		fade_tween.chain().tween_callback(
			Callable(self, "_on_fade_complete")
		)

func _on_fade_complete() -> void:
	# Clear text after fade
	label.text = ""
	fade_tween = null
