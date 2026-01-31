extends StaticBody2D

# Visual parameters
@export var wall_color: Color = Color(0.3, 0.6, 0.8, 0.7)  # Semi-transparent blue
@export var wall_width: float = 32.0
@export var wall_height: float = 128.0
@export var particle_color: Color = Color(0.4, 0.7, 1.0, 0.8)

# Dash detection
var player_in_area: bool = false
var current_player: Node2D = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_rect: ColorRect = $VisualRect
@onready var dash_detector: Area2D = $DashDetector
@onready var shimmer_particles: GPUParticles2D = $ShimmerParticles

func _ready():
	# Set up visual appearance
	if visual_rect:
		visual_rect.color = wall_color
		visual_rect.size = Vector2(wall_width, wall_height)
		visual_rect.position = Vector2(-wall_width / 2, -wall_height / 2)
	
	# Set up collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(wall_width, wall_height)
	
	# Connect dash detector signals
	if dash_detector:
		dash_detector.body_entered.connect(_on_dash_detector_body_entered)
		dash_detector.body_exited.connect(_on_dash_detector_body_exited)
	
	# Set up shimmer particles
	setup_shimmer_particles()

func _physics_process(_delta: float) -> void:
	# Check if player is dashing
	if player_in_area and current_player:
		if current_player.has_method("get") and current_player.get("is_dashing"):
			# Disable collision when player is dashing
			set_collision_layer_value(1, false)
			set_collision_mask_value(1, false)
			
			# Visual feedback - make wall more transparent
			if visual_rect:
				visual_rect.modulate.a = 0.3
		else:
			# Re-enable collision when not dashing
			set_collision_layer_value(1, true)
			set_collision_mask_value(1, true)
			
			# Restore normal transparency
			if visual_rect:
				visual_rect.modulate.a = 1.0
	else:
		# Ensure collision is enabled when player is not near
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		if visual_rect:
			visual_rect.modulate.a = 1.0

func _on_dash_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		current_player = body
		
		# Pulse effect when player enters
		if visual_rect:
			var tween = create_tween()
			tween.tween_property(visual_rect, "modulate:a", 0.9, 0.2)
			tween.tween_property(visual_rect, "modulate:a", 0.7, 0.2)

func _on_dash_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		current_player = null
		
		# Restore collision just in case
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)

func setup_shimmer_particles() -> void:
	"""Set up the shimmer particle effect"""
	if not shimmer_particles:
		return
	
	shimmer_particles.amount = 20
	shimmer_particles.lifetime = 2.0
	shimmer_particles.preprocess = 1.0
	shimmer_particles.local_coords = true
	shimmer_particles.emitting = true
	
	var material = ParticleProcessMaterial.new()
	
	# Emit along the wall surface
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(wall_width / 2, wall_height / 2, 0)
	
	# Slow floating motion
	material.direction = Vector3(0, -1, 0)
	material.spread = 20.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -10, 0)
	
	# Small particle size
	material.scale_min = 1.5
	material.scale_max = 3.0
	
	# Color gradient
	var gradient = Gradient.new()
	gradient.set_color(0, particle_color)
	gradient.set_color(1, Color(particle_color.r, particle_color.g, particle_color.b, 0))
	material.color_ramp = gradient
	
	shimmer_particles.process_material = material
