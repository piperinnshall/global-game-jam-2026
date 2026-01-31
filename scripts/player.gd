extends CharacterBody2D

# Movement parameters
@export var move_speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0
@export var air_acceleration: float = 500.0

# Bounce/Animation parameters
@export var walk_bob_speed: float = 18.0
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

# Mask system
enum MaskType { NONE, MASK_1, MASK_2, MASK_3, MASK_4 }
var current_mask: MaskType = MaskType.NONE
var mask_switch_cooldown: float = 0.0
var mask_switch_cooldown_time: float = 0.3  # Cooldown between mask switches

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

func _physics_process(delta: float) -> void:
	# Update mask switch cooldown
	if mask_switch_cooldown > 0:
		mask_switch_cooldown -= delta
	
	# Handle mask switching with F key (with cooldown)
	if Input.is_key_pressed(KEY_F) and mask_switch_cooldown <= 0:
		cycle_mask()
		mask_switch_cooldown = mask_switch_cooldown_time
	
	# Update dash cooldown
	if dash_cooldown > 0:
		dash_cooldown -= delta
	
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
	
	# Handle jump (with double jump support)
	if Input.is_action_just_pressed("ui_accept") and jumps_remaining > 0:
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

func cycle_mask() -> void:
	"""Cycle through available masks"""
	var next_mask = (current_mask + 1) % 5  # Cycle through 0-4
	equip_mask(next_mask as MaskType)
	print("Switched to mask: ", current_mask)

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
	"""Emit special particles for double jump"""
	if double_jump_effect:
		double_jump_effect.restart()
	if jump_trail:
		jump_trail.emitting = true

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

func remove_mask() -> void:
	"""Remove current mask and return to base character"""
	equip_mask(MaskType.NONE)

func apply_mask_powers(mask_type: MaskType) -> void:
	"""Apply the special powers of the equipped mask"""
	# Reset all powers to base
	max_jumps = 1
	jumps_remaining = 1
	is_dashing = false
	dash_cooldown = 0
	
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
			# TODO: Implement Mask 3 powers (e.g., wall climb)
			pass
		MaskType.MASK_4:
			# TODO: Implement Mask 4 powers (e.g., glide)
			pass

func get_current_mask() -> MaskType:
	"""Returns the currently equipped mask"""
	return current_mask

# Example function for picking up a mask item
func pickup_mask(mask_type: MaskType) -> void:
	"""Called when player picks up a mask in the world"""
	equip_mask(mask_type)
	# Add visual/sound effects here

# Particle emission functions
func emit_jump_particles() -> void:
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
			material.direction = Vector3(-facing_direction, -0.3, 0)
		walk_particles.restart()
