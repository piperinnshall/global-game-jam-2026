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
@export var jump_squash: Vector2 = Vector2(1.3, 0.7)
@export var jump_stretch: Vector2 = Vector2(0.7, 1.3)
@export var land_squash: Vector2 = Vector2(1.4, 0.6)
@export var bounce_back_speed: float = 10.0

# Particle parameters
@export var walk_particle_interval: float = 0.15  # Time between walk particles

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

# References (set in _ready)
@onready var sprite: Sprite2D = $Sprite2D
@onready var mask_sprite: Sprite2D = $Sprite2D/MaskSprite
@onready var jump_particles: GPUParticles2D = $JumpParticles
@onready var land_particles: GPUParticles2D = $LandParticles
@onready var walk_particles: GPUParticles2D = $WalkParticles
@onready var jump_trail: GPUParticles2D = $JumpTrail

func _ready():
	# Set initial scale and facing
	sprite.scale = Vector2.ONE
	mask_sprite.visible = false
	facing_direction = 1  # Start facing right

func _physics_process(delta: float) -> void:
	# Handle gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Get input direction
	var input_dir = Input.get_axis("left", "right")
	
	# Check for direction change and trigger flip
	if input_dir > 0 and facing_direction < 0:
		start_flip()
		facing_direction = 1
	elif input_dir < 0 and facing_direction > 0:
		start_flip()
		facing_direction = -1
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		target_scale = jump_stretch  # Stretch when jumping
		emit_jump_particles()  # Trigger jump particles
		jump_trail.emitting = true  # Start jump trail
	
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
	if is_on_floor():
		jump_trail.emitting = false
	
	# Update animations
	update_visual_effects(delta, input_dir)
	update_flip_animation(delta)
	
	# Update sprite facing (only if not flipping)
	if not is_flipping:
		sprite.flip_h = facing_direction < 0

func update_visual_effects(delta: float, input_dir: float) -> void:
	# Walking bob animation with rotation
	if is_on_floor() and abs(velocity.x) > 10:
		walk_time += delta * walk_bob_speed
		bob_offset = sin(walk_time) * walk_bob_amount
		sprite.position.y = bob_offset * 10
		
		# Add rotation that syncs with the bob
		target_rotation = sin(walk_time) * walk_rotation_amount * facing_direction
		
		# Add subtle scale bob when walking
		var walk_scale_x = 1.0 + abs(sin(walk_time)) * 0.1
		var walk_scale_y = 1.0 - abs(sin(walk_time)) * 0.1
		target_scale = Vector2(walk_scale_x, walk_scale_y)
	else:
		walk_time = 0.0
		sprite.position.y = move_toward(sprite.position.y, 0, delta * 100)
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
		sprite.scale = sprite.scale.lerp(target_scale, delta * bounce_back_speed)
		sprite.rotation_degrees = lerp(sprite.rotation_degrees, target_rotation, delta * bounce_back_speed)

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
		sprite.scale.x = abs(sprite.scale.x)  # Ensure proper scale
		return
	
	# Create a squash effect during flip using a sine wave
	var flip_squash = 1.0 - (sin(progress * PI) * flip_scale_amount)
	
	# Apply the squash to x scale while maintaining y scale from other animations
	var current_y_scale = sprite.scale.y
	sprite.scale = Vector2(flip_squash, current_y_scale)
	
	# Halfway through, actually flip the sprite
	if progress >= 0.5 and progress < 0.5 + delta / flip_duration:
		sprite.flip_h = facing_direction < 0

func equip_mask(mask_type: MaskType) -> void:
	"""Equip a specific mask and show it on the character"""
	current_mask = mask_type
	
	if mask_type == MaskType.NONE:
		mask_sprite.visible = false
	else:
		mask_sprite.visible = true
		# Set the frame based on mask type (frames 1-4 in sprite sheet)
		mask_sprite.frame = int(mask_type)
		
	# Here  can add mask-specific power initialization
	apply_mask_powers(mask_type)

func remove_mask() -> void:
	"""Remove current mask and return to base character"""
	equip_mask(MaskType.NONE)

func apply_mask_powers(mask_type: MaskType) -> void:
	"""Apply the special powers of the equipped mask"""
	# Reset any previous mask powers here
	
	match mask_type:
		MaskType.NONE:
			# Base character - no special powers
			pass
		MaskType.MASK_1:
			# TODO: Implement Mask 1 powers (e.g., double jump)
			pass
		MaskType.MASK_2:
			# TODO: Implement Mask 2 powers (e.g., dash)
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
