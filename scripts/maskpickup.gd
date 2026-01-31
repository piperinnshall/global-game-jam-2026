extends Area2D

## Mask pickup item that can be collected by the player
## Automatically calls the player's pickup_mask function when collected

# Mask type selection (set in inspector)
enum MaskType { MASK_1, MASK_2, MASK_3, MASK_4 }
@export var mask_type: MaskType = MaskType.MASK_1

# Visual effect parameters
@export_group("Bob Animation")
@export var bob_height: float = 15.0  # How high/low the mask bobs
@export var bob_speed: float = 2.0  # Speed of bobbing (lower = slower)

@export_group("Collection")
@export var auto_collect: bool = true  # Automatically collect on touch
@export var collection_effect_duration: float = 0.3  # Shrink/fade animation duration

# Internal variables
var bob_time: float = 0.0
var initial_position: Vector2 = Vector2.ZERO
var is_collected: bool = false

# Node references
@onready var sprite_container: Node2D = $SpriteContainer
@onready var mask_1_sprite: Sprite2D = $SpriteContainer/Mask1Sprite
@onready var mask_2_sprite: Sprite2D = $SpriteContainer/Mask2Sprite
@onready var mask_3_sprite: Sprite2D = $SpriteContainer/Mask3Sprite
@onready var mask_4_sprite: Sprite2D = $SpriteContainer/Mask4Sprite

func _ready() -> void:
	# Store initial position for bobbing animation
	initial_position = sprite_container.position
	
	# Set up the correct mask sprite based on selection
	update_mask_visibility()
	
	# Randomize starting animation phase for variety
	bob_time = randf() * TAU  # TAU = 2 * PI
	
	# Connect to body_entered signal (only if not already connected in editor)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Update animation timers
	bob_time += delta * bob_speed
	
	# Apply bobbing motion (sine wave)
	var bob_offset = sin(bob_time) * bob_height
	sprite_container.position.y = initial_position.y + bob_offset

func update_mask_visibility() -> void:
	"""Show only the selected mask sprite"""
	if mask_1_sprite:
		mask_1_sprite.visible = (mask_type == MaskType.MASK_1)
	if mask_2_sprite:
		mask_2_sprite.visible = (mask_type == MaskType.MASK_2)
	if mask_3_sprite:
		mask_3_sprite.visible = (mask_type == MaskType.MASK_3)
	if mask_4_sprite:
		mask_4_sprite.visible = (mask_type == MaskType.MASK_4)

func get_current_mask_sprite() -> Sprite2D:
	"""Returns the currently visible mask sprite"""
	match mask_type:
		MaskType.MASK_1:
			return mask_1_sprite
		MaskType.MASK_2:
			return mask_2_sprite
		MaskType.MASK_3:
			return mask_3_sprite
		MaskType.MASK_4:
			return mask_4_sprite
	return null

func _on_body_entered(body: Node2D) -> void:
	"""Detect when player enters the pickup area"""
	if is_collected:
		return
	
	# Check if the body is the player
	if body.name == "Player" or body.is_in_group("player"):
		if auto_collect:
			# Call the player's pickup_mask function directly
			if body.has_method("pickup_mask"):
				# Convert this pickup's enum to player's enum
				# Pickup enum: MASK_1=0, MASK_2=1, MASK_3=2, MASK_4=3
				# Player enum: NONE=0, MASK_1=1, MASK_2=2, MASK_3=3, MASK_4=4
				var player_mask_type = (mask_type as int) + 1
				body.pickup_mask(player_mask_type)
			
			collect()

func collect() -> void:
	"""Collect the mask and play collection animation"""
	if is_collected:
		return
	
	is_collected = true
	
	# Play collection animation
	play_collection_effect()
	
	print("Mask collected: ", MaskType.keys()[mask_type])

func play_collection_effect() -> void:
	"""Animate the pickup being collected"""
	# Disable collision so player doesn't trigger it again
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Create collection animation using tween
	var tween = create_tween()
	tween.set_parallel(true)  # Run animations simultaneously
	
	# Shrink the sprite
	tween.tween_property(sprite_container, "scale", Vector2.ZERO, collection_effect_duration)
	
	# Move upward slightly
	tween.tween_property(sprite_container, "position:y", 
		sprite_container.position.y - 30, collection_effect_duration)
	
	# Fade out
	tween.tween_property(sprite_container, "modulate:a", 0.0, collection_effect_duration)
	
	# Remove the pickup after animation
	tween.chain().tween_callback(queue_free)

# Helper function to manually trigger collection (if auto_collect is false)
func trigger_collection() -> void:
	"""Call this to manually trigger collection (for interaction prompts, etc.)"""
	collect()

# Helper function to get the mask type as the player's enum value
func get_mask_type_for_player() -> int:
	"""Returns the mask type in a format matching the player's MaskType enum"""
	# Player's enum: NONE=0, MASK_1=1, MASK_2=2, MASK_3=3, MASK_4=4
	# This pickup enum: MASK_1=0, MASK_2=1, MASK_3=2, MASK_4=3
	return (mask_type as int) + 1  # Add 1 to match player's enum
