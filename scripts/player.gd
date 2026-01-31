extends CharacterBody2D

# Movement parameters
@export var move_speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0
@export var air_acceleration: float = 500.0

# Bounce/Animation parameters
@export var walk_bob_speed: float = 24.0
@export var walk_bob_amount: float = 0.15
@export var walk_rotation_amount: float = 10.0  # Degrees of rotation while walking
@export var flip_duration: float = 0.15  # Duration of flip animation
@export var flip_scale_amount: float = 0.3  # How much to squash during flip
@export var jump_squash: Vector2 = Vector2(1.15, 0.75)
@export var jump_stretch: Vector2 = Vector2(0.75, 1.15)
@export var land_squash: Vector2 = Vector2(1.7, 0.3)
@export var bounce_back_speed: float = 10.0

# Particle parameters
@export var walk_particle_interval: float = 0.15  # Time between walk particles

# Shockwave parameters (Mask 4)
@export var shockwave_damage: float = 50.0
@export var shockwave_range: float = 150.0
@export var shockwave_speed: float = 400.0
@export var shockwave_cooldown_time: float = 1.0
@export var shockwave_knockback: float = 300.0

# Mask system
enum MaskType { NONE, MASK_1, MASK_2, MASK_3, MASK_4 }
var current_mask: MaskType = MaskType.NONE

# Internal state
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var walk_time: float = 0.0
var was_on_floor: bool = false
var target_scale: Vector2 = Vector2.ONE
var bob_offset: float = 0.0
var facing_direction: int = 1  # 1 for right, -1 for left
var is_flipping: bool = false
var flip_timer: float = 0.0
var target_rotation: float = 0.0
var walk_particle_timer: float = 0.0

# Mask ability state
var jumps_remaining: int = 1
var max_jumps: int = 1
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_duration: float = 0.2
var dash_speed: float = 600.0
var dash_cooldown: float = 0.0
var dash_cooldown_time: float = 0.5

# Shockwave state (Mask 4)
var shockwave_cooldown: float = 0.0

# Double tap detection for dash
var last_left_tap_time: float = -1.0
var last_right_tap_time: float = -1.0
var double_tap_window: float = 0.3  # Time window for double tap

# References (set in _ready)
@onready var sprite_container: Node2D = $SpriteContainer
@onready var player_sprite: Sprite2D = $SpriteContainer/PlayerSprite
@onready var mask_1_sprite: Sprite2D = $SpriteContainer/Mask1Sprite
@onready var mask_2_sprite: Sprite2D = $SpriteContainer/Mask2Sprite
@onready var mask_3_sprite: Sprite2D = $SpriteContainer/Mask3Sprite
@onready var mask_4_sprite: Sprite2D = $SpriteContainer/Mask4Sprite
@onready var jump_particles: GPUParticles2D = $JumpParticles
@onready var land_particles: GPUParticles2D = $LandParticles
@onready var walk_particles: GPUParticles2D = $WalkParticles
@onready var jump_trail: GPUParticles2D = $JumpTrail
@onready var double_jump_effect: GPUParticles2D = $DoubleJumpEffect
@onready var dash_particles: GPUParticles2D = $DashParticles
@onready var mask_3_light: PointLight2D = $Mask3Light if has_node("Mask3Light") else null
@onready var shockwave_particles: GPUParticles2D = $ShockwaveParticles if has_node("ShockwaveParticles") else null

func _ready():
	# Set initial scale and facing
	sprite_container.scale = Vector2.ONE
	facing_direction = 1  # Start facing right
	
	# Hide all mask sprites initially
	if player_sprite:
		player_sprite.visible = true
	if mask_1_sprite:
		mask_1_sprite.visible = false
	if mask_2_sprite:
		mask_2_sprite.visible = false
	if mask_3_sprite:
		mask_3_sprite.visible = false
	if mask_4_sprite:
		mask_4_sprite.visible = false
	
	# Hide Mask 3 light initially
	if mask_3_light:
		mask_3_light.enabled = false
	
	# Add player to "player" group so mask pickups can identify it
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# Update dash cooldown
	if dash_cooldown > 0:
		dash_cooldown -= delta
	
	# Update shockwave cooldown
	if shockwave_cooldown > 0:
		shockwave_cooldown -= delta
	
	# Handle shockwave ability (Mask 4 - Space bar)
	if current_mask == MaskType.MASK_4 and Input.is_action_just_pressed("ui_accept") and shockwave_cooldown <= 0:
		trigger_shockwave()
		shockwave_cooldown = shockwave_cooldown_time
	
	# Handle dashing
	if is_dashing:
		handle_dash(delta)
		return  # Skip normal movement while dashing
	
	# Handle gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Reset jumps when on floor
		jumps_remaining = max_jumps
	
	# Get input direction - using built-in Godot actions
	var input_dir = 0.0
	if Input.is_action_pressed("left"):
		input_dir -= 1.0
	if Input.is_action_pressed("right"):
		input_dir += 1.0
	
	# Detect double tap for dash (only if wearing dash mask)
	if current_mask == MaskType.MASK_2 and not is_dashing and dash_cooldown <= 0:
		detect_double_tap(delta)
	
	# Check for direction change and trigger flip
	if input_dir > 0 and facing_direction < 0:
		start_flip()
		facing_direction = 1
	elif input_dir < 0 and facing_direction > 0:
		start_flip()
		facing_direction = -1
	
	# Handle jump (with double jump support) - only if NOT wearing Mask 4
	if current_mask != MaskType.MASK_4 and Input.is_action_just_pressed("ui_accept") and jumps_remaining > 0:
		velocity.y = jump_velocity
		jumps_remaining -= 1
		target_scale = jump_stretch  # Stretch when jumping
		
		# Different effects based on jump type
		if jumps_remaining == max_jumps - 1:  # First jump
			emit_jump_particles()
			if jump_trail:
				jump_trail.emitting = true
		else:  # Double jump
			emit_double_jump_effect()
	
	# Apply horizontal movement with acceleration
	if is_on_floor():
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
	else:
		# Air control
		if input_dir != 0:
			velocity.x = move_toward(velocity.x, input_dir * move_speed, air_acceleration * delta)
	
	# Move the character
	var was_on_floor_before = is_on_floor()
	move_and_slide()
	
	# Apply platform movement if standing on a moving platform
	if is_on_floor():
		var platform = get_platform_below()
		if platform and platform.has_method("get_platform_velocity"):
			var platform_velocity = platform.get_platform_velocity()
			# Move the player with the platform
			position += platform_velocity * delta
	
	# Handle landing squash and particles
	if is_on_floor() and not was_on_floor_before:
		target_scale = land_squash
		emit_land_particles()  # Trigger landing particles
		if jump_trail:
			jump_trail.emitting = false  # Stop jump trail
	
	# Handle walking particles
	if is_on_floor() and abs(velocity.x) > 10:
		walk_particle_timer -= delta
		if walk_particle_timer <= 0:
			emit_walk_particles()
			walk_particle_timer = walk_particle_interval
	else:
		walk_particle_timer = 0
	
	# Stop jump trail if on ground
	if is_on_floor() and jump_trail:
		jump_trail.emitting = false
	
	# Update animations
	update_visual_effects(delta, input_dir)
	update_flip_animation(delta)
	
	# Update sprite facing (only if not flipping)
	if not is_flipping:
		sprite_container.scale.x = facing_direction * abs(sprite_container.scale.x)

func get_platform_below() -> Node2D:
	"""Get the platform the player is standing on, if any"""
	# Check what we're colliding with
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Check if it's a platform (you can also check for a group)
		if collider and (collider.is_in_group("platforms") or collider.has_method("get_platform_velocity")):
			# Make sure we're on top of it (normal pointing up)
			if collision.get_normal().y < -0.5:  # Normal pointing mostly upward
				return collider
	
	return null

func update_visual_effects(delta: float, input_dir: float) -> void:
	# Walking bob animation with rotation
	if is_on_floor() and abs(velocity.x) > 10:
		walk_time += delta * walk_bob_speed
		bob_offset = sin(walk_time) * walk_bob_amount
		sprite_container.position.y = bob_offset * 10
		
		# Add rotation that syncs with the bob
		target_rotation = sin(walk_time) * walk_rotation_amount * facing_direction
		
		# Add subtle scale bob when walking
		var walk_scale_x = 1.0 + abs(sin(walk_time)) * 0.1
		var walk_scale_y = 1.0 - abs(sin(walk_time)) * 0.1
		target_scale = Vector2(walk_scale_x, walk_scale_y)
	else:
		walk_time = 0.0
		sprite_container.position.y = move_toward(sprite_container.position.y, 0, delta * 100)
		target_rotation = 0.0  # Return to neutral rotation when not walking
	
	# In-air squash and stretch
	if not is_on_floor():
		target_rotation = 0.0  # No rotation in air
		if velocity.y < -100:  # Going up fast
			target_scale = jump_stretch
		elif velocity.y > 100:  # Falling fast
			target_scale = jump_squash
		else:  # Apex of jump
			target_scale = Vector2.ONE
	
	# Return to normal scale when grounded and idle
	if is_on_floor() and abs(velocity.x) < 10:
		target_scale = Vector2.ONE
		target_rotation = 0.0
	
	# Smoothly interpolate scale and rotation (unless flipping)
	if not is_flipping:
		var current_scale = sprite_container.scale
		var new_scale = current_scale.lerp(target_scale * Vector2(sign(current_scale.x), 1), delta * bounce_back_speed)
		sprite_container.scale = new_scale
		sprite_container.rotation_degrees = lerp(sprite_container.rotation_degrees, target_rotation, delta * bounce_back_speed)

func start_flip() -> void:
	"""Initiate the flip animation when changing direction"""
	is_flipping = true
	flip_timer = 0.0

func update_flip_animation(delta: float) -> void:
	"""Handle the flip animation effect"""
	if not is_flipping:
		return
	
	flip_timer += delta
	var progress = flip_timer / flip_duration
	
	if progress >= 1.0:
		# Flip complete
		is_flipping = false
		sprite_container.scale.x = facing_direction * abs(sprite_container.scale.x)
		return
	
	# Create a squash effect during flip using a sine wave
	var flip_squash = 1.0 - (sin(progress * PI) * flip_scale_amount)
	
	# Apply the squash to x scale while maintaining y scale from other animations
	var current_y_scale = abs(sprite_container.scale.y)
	sprite_container.scale = Vector2(facing_direction * flip_squash, current_y_scale)

func equip_mask(mask_type: MaskType) -> void:
	"""Equip a specific mask and show it on the character"""
	current_mask = mask_type
	
	# Hide all mask sprites first
	if player_sprite:
		player_sprite.visible = false
	if mask_1_sprite:
		mask_1_sprite.visible = false
	if mask_2_sprite:
		mask_2_sprite.visible = false
	if mask_3_sprite:
		mask_3_sprite.visible = false
	if mask_4_sprite:
		mask_4_sprite.visible = false
	
	# Show the appropriate sprite
	match mask_type:
		MaskType.NONE:
			if player_sprite:
				player_sprite.visible = true
		MaskType.MASK_1:
			if mask_1_sprite:
				mask_1_sprite.visible = true
		MaskType.MASK_2:
			if mask_2_sprite:
				mask_2_sprite.visible = true
		MaskType.MASK_3:
			if mask_3_sprite:
				mask_3_sprite.visible = true
		MaskType.MASK_4:
			if mask_4_sprite:
				mask_4_sprite.visible = true
	
	# Apply mask-specific powers
	apply_mask_powers(mask_type)
	
	print("Equipped mask: ", mask_type)

func remove_mask() -> void:
	"""Remove current mask and return to base character"""
	equip_mask(MaskType.NONE)

func get_current_mask() -> MaskType:
	"""Returns the currently equipped mask"""
	return current_mask

# Function called when player picks up a mask item from the world
func pickup_mask(mask_type: MaskType) -> void:
	"""Called when player picks up a mask in the world - this is now the ONLY way to change masks"""
	equip_mask(mask_type)
	
	# Visual feedback - squash effect
	target_scale = Vector2(1.2, 0.8)
	
	# You can add sound effects, particles, or other feedback here
	print("Picked up mask: ", mask_type)

func detect_double_tap(delta: float) -> void:
	"""Detect double tap for dash"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check for left double tap
	if Input.is_action_just_pressed("left"):
		if current_time - last_left_tap_time < double_tap_window:
			start_dash(Vector2.LEFT)
		last_left_tap_time = current_time
	
	# Check for right double tap
	if Input.is_action_just_pressed("right"):
		if current_time - last_right_tap_time < double_tap_window:
			start_dash(Vector2.RIGHT)
		last_right_tap_time = current_time

func start_dash(direction: Vector2) -> void:
	$Dashsound.play()
	"""Initiate a dash"""
	is_dashing = true
	dash_direction = direction
	dash_timer = dash_duration
	velocity = dash_direction * dash_speed
	dash_cooldown = dash_cooldown_time
	
	# Visual effects
	if dash_particles:
		dash_particles.emitting = true
	
	# Start creating afterimages
	create_afterimage()

func handle_dash(delta: float) -> void:
	"""Handle dash movement and effects"""
	dash_timer -= delta
	
	# Maintain dash velocity
	velocity = dash_direction * dash_speed
	
	# Create afterimages during dash
	if int(dash_timer * 60) % 3 == 0:  # Every 3 frames
		create_afterimage()
	
	move_and_slide()
	
	# End dash
	if dash_timer <= 0:
		is_dashing = false
		if dash_particles:
			dash_particles.emitting = false
		velocity.x *= 0.5  # Slow down after dash

func create_afterimage() -> void:
	"""Create an afterimage sprite"""
	# Determine which sprite is currently visible
	var source_sprite: Sprite2D = null
	if player_sprite and player_sprite.visible:
		source_sprite = player_sprite
	elif mask_1_sprite and mask_1_sprite.visible:
		source_sprite = mask_1_sprite
	elif mask_2_sprite and mask_2_sprite.visible:
		source_sprite = mask_2_sprite
	elif mask_3_sprite and mask_3_sprite.visible:
		source_sprite = mask_3_sprite
	elif mask_4_sprite and mask_4_sprite.visible:
		source_sprite = mask_4_sprite
	
	if not source_sprite:
		return
	
	var afterimage = Sprite2D.new()
	afterimage.texture = source_sprite.texture
	afterimage.region_enabled = source_sprite.region_enabled
	afterimage.region_rect = source_sprite.region_rect
	# Combine player's base scale with sprite_container's animation scale
	afterimage.scale = sprite_container.scale * scale
	afterimage.rotation = sprite_container.rotation + rotation
	afterimage.modulate = Color(1, 1, 1, 0.5)
	
	# Position relative to world
	get_parent().add_child(afterimage)
	afterimage.global_position = source_sprite.global_position
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.3)
	tween.tween_callback(afterimage.queue_free)

func emit_double_jump_effect() -> void:
	$JumpSound.play()
	"""Emit special particles for double jump"""
	if double_jump_effect:
		double_jump_effect.restart()
	if jump_trail:
		jump_trail.emitting = true

func apply_mask_powers(mask_type: MaskType) -> void:
	"""Apply the special powers of the equipped mask"""
	# Reset all powers to base
	max_jumps = 1
	jumps_remaining = 1
	is_dashing = false
	dash_cooldown = 0
	
	# Disable Mask 3 light by default
	if mask_3_light:
		mask_3_light.enabled = false
	
	match mask_type:
		MaskType.NONE:
			# Base character - no special powers
			pass
		MaskType.MASK_1:
			# Double jump mask
			max_jumps = 2
			jumps_remaining = 2 if is_on_floor() else 1
		MaskType.MASK_2:
			# Dash mask (handled via double tap detection)
			pass
		MaskType.MASK_3:
			# Light source mask - enable the light
			if mask_3_light:
				mask_3_light.enabled = true
		MaskType.MASK_4:
			# Shockwave mask (handled via space bar input)
			pass

# OPTIMIZED MASK 4 ABILITY: SHOCKWAVE
func trigger_shockwave() -> void:
	"""Trigger a simplified shockwave attack"""
	print("Shockwave triggered!")
	
	# Create shockwave projectile
	var shockwave = create_shockwave_projectile()
	if shockwave:
		get_parent().add_child(shockwave)
		shockwave.global_position = global_position + Vector2(facing_direction * 30, 0)
	
	# Play shockwave particles at player position
	if shockwave_particles:
		shockwave_particles.emitting = true
	
	# Apply screen shake effect (if you have a camera)
	apply_screen_shake()
	
	# Visual feedback - squash player sprite
	target_scale = Vector2(1.3, 0.7)

func create_shockwave_projectile() -> Node2D:
	"""Create an optimized shockwave projectile with minimal performance impact"""
	var shockwave = Node2D.new()
	shockwave.name = "Shockwave"
	
	# Single animated ring instead of multiple layers
	var ring = create_simple_shockwave_ring()
	shockwave.add_child(ring)
	
	# Add white inner ring for contrast
	var white_ring = create_white_inner_ring()
	shockwave.add_child(white_ring)
	
	# Add distortion wave
	var distortion = create_distortion_wave()
	shockwave.add_child(distortion)
	
	# Single particle system instead of multiple
	var particles = create_simple_shockwave_particles()
	shockwave.add_child(particles)
	
	# Add white spark particles
	var white_particles = create_white_spark_particles()
	shockwave.add_child(white_particles)
	
	# Add collision detection area
	var area = Area2D.new()
	area.name = "HitArea"
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50.0
	collision.shape = shape
	area.add_child(collision)
	shockwave.add_child(area)
	
	# Connect area signals
	area.body_entered.connect(_on_shockwave_hit.bind(shockwave))
	area.area_entered.connect(_on_shockwave_hit_area.bind(shockwave))
	
	# Add script to move and animate shockwave
	var script_text = """
extends Node2D

var speed: float = %f
var direction: int = %d
var lifetime: float = 0.0
var max_lifetime: float = 0.6
var distance_traveled: float = 0.0
var max_range: float = %f

func _ready():
	# Animate the black ring
	var ring = get_node_or_null('Ring')
	if ring:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, 'scale', Vector2.ONE * 2.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, 'modulate:a', 0.0, 0.4)
	
	# Animate the white ring
	var white_ring = get_node_or_null('WhiteRing')
	if white_ring:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(white_ring, 'scale', Vector2.ONE * 1.8, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(white_ring, 'modulate:a', 0.0, 0.35)
	
	# Animate the distortion wave
	var distortion = get_node_or_null('DistortionWave')
	if distortion:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(distortion, 'scale', Vector2.ONE * 2.2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(distortion, 'modulate:a', 0.0, 0.5)

func _process(delta: float) -> void:
	lifetime += delta
	
	# Move forward
	var movement = speed * delta
	position.x += direction * movement
	distance_traveled += movement
	
	# Simple pulsating opacity
	modulate.a = 0.8 * (1.0 - (lifetime / max_lifetime))
	
	# Pulse the distortion wave
	var distortion = get_node_or_null('DistortionWave')
	if distortion:
		distortion.scale = Vector2.ONE * (1.0 + sin(lifetime * 15.0) * 0.15)
	
	# Destroy after max range or lifetime
	if distance_traveled >= max_range or lifetime >= max_lifetime:
		queue_free()
""" % [shockwave_speed, facing_direction, shockwave_range]
	
	var script = GDScript.new()
	script.source_code = script_text
	script.reload()
	shockwave.set_script(script)
	
	return shockwave

func create_simple_shockwave_ring() -> Sprite2D:
	$ShockwaveSound.play()
	"""Create a single optimized black ring"""
	var ring = Sprite2D.new()
	ring.name = "Ring"
	
	# Create a simple black circle texture (smaller resolution for performance)
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(32, 32)
	var outer_radius = 30.0
	var inner_radius = 22.0
	
	# Draw ring with minimal pixel operations
	for x in range(64):
		for y in range(64):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist < outer_radius and dist > inner_radius:
				var alpha = 0.7
				# Simple feathering
				if dist > outer_radius - 2:
					alpha *= (outer_radius - dist) / 2.0
				elif dist < inner_radius + 2:
					alpha *= (dist - inner_radius) / 2.0
				img.set_pixel(x, y, Color(0.05, 0.05, 0.1, alpha))
	
	var texture = ImageTexture.create_from_image(img)
	ring.texture = texture
	ring.scale = Vector2.ONE * 0.8
	
	return ring

func create_white_inner_ring() -> Sprite2D:
	"""Create a white inner ring for contrast"""
	var ring = Sprite2D.new()
	ring.name = "WhiteRing"
	
	# Create white ring texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(32, 32)
	var outer_radius = 20.0
	var inner_radius = 16.0
	
	# Draw white ring
	for x in range(64):
		for y in range(64):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist < outer_radius and dist > inner_radius:
				var alpha = 0.85
				# Feathering
				if dist > outer_radius - 2:
					alpha *= (outer_radius - dist) / 2.0
				elif dist < inner_radius + 2:
					alpha *= (dist - inner_radius) / 2.0
				img.set_pixel(x, y, Color(0.95, 0.95, 1.0, alpha))
	
	var texture = ImageTexture.create_from_image(img)
	ring.texture = texture
	ring.scale = Vector2.ONE * 0.9
	
	return ring

func create_distortion_wave() -> Sprite2D:
	"""Create a distortion wave effect sprite"""
	var sprite = Sprite2D.new()
	sprite.name = "DistortionWave"
	
	# Create a gradient circle for distortion effect
	var img = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(40, 40)
	for x in range(80):
		for y in range(80):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist < 38:
				var alpha = (1.0 - dist / 38.0) * 0.35
				# Mix of dark and light for energy effect
				var brightness = 0.3 + (dist / 38.0) * 0.4
				img.set_pixel(x, y, Color(brightness, brightness, brightness + 0.1, alpha))
	
	var texture = ImageTexture.create_from_image(img)
	sprite.texture = texture
	sprite.modulate = Color(0.9, 0.9, 1.0, 0.6)
	sprite.scale = Vector2.ONE * 0.7
	
	return sprite

func create_simple_shockwave_particles() -> GPUParticles2D:
	"""Create a single optimized particle system for the shockwave"""
	var particles = GPUParticles2D.new()
	particles.name = "Particles"
	particles.amount = 15  # Reduced from 30+
	particles.lifetime = 0.4  # Shorter lifetime
	particles.explosiveness = 0.5
	particles.local_coords = true
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 15.0
	material.direction = Vector3(1, 0, 0)
	material.spread = 40.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 120.0
	material.gravity = Vector3.ZERO
	material.scale_min = 3.0
	material.scale_max = 6.0
	material.color = Color(0.15, 0.15, 0.2, 0.8)
	
	# Gradient with some white mixed in
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.8, 0.8, 0.9, 1))  # Start brighter
	gradient.set_color(1, Color(0.05, 0.05, 0.1, 0))  # End dark
	material.color_ramp = gradient
	
	particles.process_material = material
	particles.emitting = true
	
	return particles

func create_white_spark_particles() -> GPUParticles2D:
	"""Create bright white spark particles for the shockwave core"""
	var particles = GPUParticles2D.new()
	particles.name = "WhiteSparks"
	particles.amount = 12
	particles.lifetime = 0.3
	particles.explosiveness = 0.7
	particles.local_coords = true
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 8.0
	material.direction = Vector3(1, 0, 0)
	material.spread = 50.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 180.0
	material.gravity = Vector3.ZERO
	material.damping_min = 30.0
	material.damping_max = 50.0
	material.scale_min = 2.0
	material.scale_max = 4.0
	material.color = Color(1.0, 1.0, 1.0, 0.9)
	
	# White to transparent gradient
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(0.9, 0.9, 1.0, 0.0))
	material.color_ramp = gradient
	
	particles.process_material = material
	particles.emitting = true
	
	return particles

func _on_shockwave_hit(body: Node2D, shockwave: Node2D) -> void:
	"""Called when shockwave hits a body"""
	if body == self:
		return  # Don't hit yourself
	
	# Send destroy signal
	if body.has_method("receive_signal"):
		body.receive_signal("destroy")
	
	# Apply knockback if body has velocity
	if body is CharacterBody2D or body is RigidBody2D:
		var knockback_direction = Vector2(facing_direction, -0.3).normalized()
		if body is CharacterBody2D:
			body.velocity += knockback_direction * shockwave_knockback
		elif body is RigidBody2D:
			body.apply_central_impulse(knockback_direction * shockwave_knockback)
	
	# Create simple impact effect
	create_simple_impact_effect(shockwave.global_position)

func _on_shockwave_hit_area(area: Area2D, shockwave: Node2D) -> void:
	"""Called when shockwave hits an area"""
	var parent = area.get_parent()
	if parent == self:
		return
	
	# Send destroy signal
	if parent.has_method("receive_signal"):
		parent.receive_signal("destroy")
	
	# Create simple impact effect
	create_simple_impact_effect(shockwave.global_position)

func create_simple_impact_effect(pos: Vector2) -> void:
	"""Create a simplified visual effect at impact point"""
	var container = Node2D.new()
	container.global_position = pos
	get_parent().add_child(container)
	
	# Black expanding ring
	var black_ring = Sprite2D.new()
	
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(24, 24)
	var outer_radius = 22.0
	var inner_radius = 18.0
	
	for x in range(48):
		for y in range(48):
			var pixel_pos = Vector2(x, y)
			var dist = pixel_pos.distance_to(center)
			if dist < outer_radius and dist > inner_radius:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.1, 0.7))
	
	var texture = ImageTexture.create_from_image(img)
	black_ring.texture = texture
	black_ring.scale = Vector2.ONE * 0.3
	container.add_child(black_ring)
	
	# White flash ring
	var white_ring = Sprite2D.new()
	
	var white_img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	white_img.fill(Color(0, 0, 0, 0))
	
	var white_outer = 16.0
	var white_inner = 12.0
	
	for x in range(48):
		for y in range(48):
			var pixel_pos = Vector2(x, y)
			var dist = pixel_pos.distance_to(center)
			if dist < white_outer and dist > white_inner:
				white_img.set_pixel(x, y, Color(0.95, 0.95, 1.0, 0.9))
	
	var white_texture = ImageTexture.create_from_image(white_img)
	white_ring.texture = white_texture
	white_ring.scale = Vector2.ONE * 0.4
	container.add_child(white_ring)
	
	# Animate both rings
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(black_ring, "scale", Vector2.ONE * 1.5, 0.3)
	tween.tween_property(black_ring, "modulate:a", 0.0, 0.3)
	tween.tween_property(white_ring, "scale", Vector2.ONE * 1.3, 0.25)
	tween.tween_property(white_ring, "modulate:a", 0.0, 0.25)
	tween.tween_callback(container.queue_free)

func apply_screen_shake() -> void:
	"""Apply screen shake effect if camera exists"""
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(5.0, 0.2)

# Particle emission functions
func emit_jump_particles() -> void:
	$JumpSound.play()
	"""Emit particles when jumping"""
	if jump_particles:
		var material = jump_particles.process_material as ParticleProcessMaterial
		if material:
			# Make particles go sideways and up, not down
			material.direction = Vector3(0, -1, 0)  # Up direction
			material.spread = 80.0  # Wide spread
			material.gravity = Vector3(0, 200, 0)  # Lower gravity so they spread out
		jump_particles.restart()

func emit_land_particles() -> void:
	$LandSound.play()
	"""Emit particles when landing"""
	if land_particles:
		var material = land_particles.process_material as ParticleProcessMaterial
		if material:
			# Force particles to burst upward and outward
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = 10.0
			material.direction = Vector3(0, -1, 0)  # Base direction UP
			material.spread = 85.0  # Wide spread but not full 90 to keep upward bias
			material.initial_velocity_min = 120.0  # Strong upward velocity
			material.initial_velocity_max = 200.0
			material.gravity = Vector3(0, 300, 0)  # Gravity eventually pulls down
			material.angle_min = -180.0  # Random rotation
			material.angle_max = 180.0
		land_particles.restart()

func emit_walk_particles() -> void:
	"""Emit particles while walking"""
	if walk_particles:
		# Position particles behind the player based on facing direction
		walk_particles.position.x = -facing_direction * 20
		# Set particle direction to go opposite of movement
		var material = walk_particles.process_material as ParticleProcessMaterial
		if material:
			$LandSound.play()

			material.direction = Vector3(-facing_direction, -0.3, 0)
		walk_particles.restart()
