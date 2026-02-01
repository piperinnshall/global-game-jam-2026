extends Area2D

func _ready():
	# Connect to the body_entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the body that entered is the player
	if body.is_in_group("player"):
		# Reset the current scene (deferred to avoid physics callback issues)
		get_tree().reload_current_scene.call_deferred()
