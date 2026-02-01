extends StaticBody2D

# Visual parameters
@export var block_color: Color = Color(0.6, 0.4, 0.2)  # Color for debris particles

# Particle parameters
@export var debris_count: int = 20
@export var debris_spread: float = 360.0
@export var debris_velocity_min: float = 100.0
@export var debris_velocity_max: float = 250.0

# Internal state
var is_destroyed: bool = false

# References
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var break_particles: GPUParticles2D = $BreakParticles

func _ready():
	# Setup particles
	setup_particles()
	
	# Add to group so player can identify destructible objects
	add_to_group("destructible")

func setup_particles() -> void:
	"""Setup the break particles"""
	if not break_particles:
		return
	
	break_particles.emitting = false
	break_particles.one_shot = true
	break_particles.amount = debris_count
	break_particles.lifetime = 0.8
	break_particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 8.0
	material.direction = Vector3(0, -1, 0)  # Upward
	material.spread = debris_spread / 2.0  # Convert to degrees from center
	material.initial_velocity_min = debris_velocity_min
	material.initial_velocity_max = debris_velocity_max
	material.gravity = Vector3(0, 400, 0)  # Fall down after initial burst
	material.scale_min = 2.0
	material.scale_max = 5.0
	material.color = block_color
	
	# Fade out gradient
	var gradient = Gradient.new()
	gradient.set_color(0, block_color)
	gradient.set_color(1, Color(block_color.r, block_color.g, block_color.b, 0))
	material.color_ramp = gradient
	
	break_particles.process_material = material

func receive_signal(signal_name: String) -> void:
	"""Receive signals from other objects (like the player's shockwave)"""
	if signal_name == "destroy" and not is_destroyed:
		break_block()

func break_block() -> void:
	"""Break the block with particles and effects"""
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# Hide sprite
	if sprite:
		sprite.visible = false
	
	# Disable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Emit break particles
	if break_particles:
		break_particles.emitting = true
	
	# Create debris chunks (deferred to avoid physics query conflicts)
	create_debris_chunks.call_deferred()
	
	# Flash effect
	create_flash_effect()
	
	# Wait for particles to finish then remove
	await get_tree().create_timer(1.0).timeout
	queue_free()

func create_debris_chunks() -> void:
	"""Create physical debris chunks that fly outward"""
	if not sprite or not sprite.texture:
		return
	
	var chunk_count = 4
	var sprite_size = sprite.texture.get_size()
	
	for i in range(chunk_count):
		var chunk = RigidBody2D.new()
		chunk.gravity_scale = 1.5
		
		# Create chunk sprite using the original sprite's texture
		var chunk_sprite = Sprite2D.new()
		chunk_sprite.texture = sprite.texture
		# Make chunks smaller pieces
		chunk_sprite.scale = Vector2.ONE * 0.5
		chunk_sprite.modulate = Color(1, 1, 1, 1)
		chunk.add_child(chunk_sprite)
		
		# Add collision
		var chunk_collision = CollisionShape2D.new()
		var chunk_shape = RectangleShape2D.new()
		chunk_shape.size = sprite_size * 0.5
		chunk_collision.shape = chunk_shape
		chunk.add_child(chunk_collision)
		
		# Position chunk
		get_parent().add_child(chunk)
		chunk.global_position = global_position
		
		# Apply random impulse
		var angle = (float(i) / chunk_count) * TAU + randf_range(-0.3, 0.3)
		var impulse = Vector2(cos(angle), sin(angle)) * randf_range(150, 300)
		chunk.apply_central_impulse(impulse)
		chunk.angular_velocity = randf_range(-10, 10)
		
		# Fade out and remove
		var tween = create_tween()
		tween.tween_property(chunk_sprite, "modulate:a", 0.0, 0.6)
		tween.tween_callback(chunk.queue_free)

func create_flash_effect() -> void:
	"""Create a white flash effect when breaking"""
	if not sprite or not sprite.texture:
		return
	
	var flash = Sprite2D.new()
	var sprite_size = sprite.texture.get_size()
	
	var flash_img = Image.create(int(sprite_size.x * 1.5), int(sprite_size.y * 1.5), false, Image.FORMAT_RGBA8)
	var center = Vector2(sprite_size.x * 0.75, sprite_size.y * 0.75)
	
	# Create radial flash
	for x in range(int(sprite_size.x * 1.5)):
		for y in range(int(sprite_size.y * 1.5)):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			var max_dist = sprite_size.x * 0.75
			if dist < max_dist:
				var alpha = (1.0 - dist / max_dist) * 0.8
				flash_img.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	var flash_texture = ImageTexture.create_from_image(flash_img)
	flash.texture = flash_texture
	flash.position = Vector2.ZERO
	add_child(flash)
	
	# Animate flash
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 1.5, 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)
