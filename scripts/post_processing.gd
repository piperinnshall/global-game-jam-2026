extends Node
## PostProcessing Autoload
## Manages all post-processing effects for the game

# Effect references
var color_rect: ColorRect
var viewport: Viewport

# Effect parameters
var bloom_intensity: float = 0.1
var bloom_threshold: float = 0.1
var chrom_aberration_strength: float = 1.0
var vignette_intensity: float = 0.4
var vignette_smoothness: float = 0.5
var pixelation_amount: int = 2
var scanline_intensity: float = 0.3
var noise_intensity: float = 0.01
var contrast: float = 0.8
var dithering_strength: float = 0.4
var color_depth: int = 8  # Number of color levels per channel (lower = more visible dithering)

# Shader material
var shader_material: ShaderMaterial

func _ready() -> void:
	# Wait for the scene tree to be ready
	await get_tree().process_frame
	setup_post_processing()

func setup_post_processing() -> void:
	# Get the root viewport
	viewport = get_tree().root
	
	# Create a CanvasLayer to ensure it stays on top across scene changes
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "PostProcessingCanvasLayer"
	canvas_layer.layer = 100  # High layer to render on top
	
	# Create a ColorRect that covers the entire screen
	color_rect = ColorRect.new()
	color_rect.name = "PostProcessingLayer"
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load the shader
	var shader = load("res://shaders/post_processing.gdshader")
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Set initial shader parameters
	update_shader_parameters()
	
	color_rect.material = shader_material
	
	# Add ColorRect to CanvasLayer
	canvas_layer.add_child(color_rect)
	
	# Add CanvasLayer directly to root (NOT to current scene)
	# This ensures it persists across scene changes
	get_tree().root.call_deferred("add_child", canvas_layer)
	
	# Connect to viewport size changes
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	if color_rect:
		color_rect.size = get_tree().root.get_visible_rect().size
		color_rect.position = Vector2.ZERO
		update_shader_parameters()

func update_shader_parameters() -> void:
	if not shader_material:
		return
	
	var screen_size = get_tree().root.get_visible_rect().size
	
	shader_material.set_shader_parameter("bloom_intensity", bloom_intensity)
	shader_material.set_shader_parameter("bloom_threshold", bloom_threshold)
	shader_material.set_shader_parameter("chrom_aberration_strength", chrom_aberration_strength)
	shader_material.set_shader_parameter("vignette_intensity", vignette_intensity)
	shader_material.set_shader_parameter("vignette_smoothness", vignette_smoothness)
	shader_material.set_shader_parameter("pixelation_amount", pixelation_amount)
	shader_material.set_shader_parameter("scanline_intensity", scanline_intensity)
	shader_material.set_shader_parameter("noise_intensity", noise_intensity)
	shader_material.set_shader_parameter("contrast", contrast)
	shader_material.set_shader_parameter("dithering_strength", dithering_strength)
	shader_material.set_shader_parameter("color_depth", color_depth)
	shader_material.set_shader_parameter("screen_size", screen_size)

# Setters for runtime adjustment
func set_bloom(intensity: float, threshold: float = 0.6) -> void:
	bloom_intensity = intensity
	bloom_threshold = threshold
	update_shader_parameters()

func set_chromatic_aberration(strength: float) -> void:
	chrom_aberration_strength = strength
	update_shader_parameters()

func set_vignette(intensity: float, smoothness: float = 0.5) -> void:
	vignette_intensity = intensity
	vignette_smoothness = smoothness
	update_shader_parameters()

func set_pixelation(amount: int) -> void:
	pixelation_amount = amount
	update_shader_parameters()

func set_scanlines(intensity: float) -> void:
	scanline_intensity = intensity
	update_shader_parameters()

func set_noise(intensity: float) -> void:
	noise_intensity = intensity
	update_shader_parameters()

func set_contrast(value: float) -> void:
	contrast = value
	update_shader_parameters()

func set_dithering(strength: float, depth: int = 8) -> void:
	"""
	Set dithering parameters.
	strength: 0.0 to 1.0 (how strong the dithering effect is)
	depth: 2 to 256 (number of color levels per channel - lower = more retro look)
	       Try 4-8 for strong retro effect, 16-32 for subtle effect
	"""
	dithering_strength = clamp(strength, 0.0, 1.0)
	color_depth = clamp(depth, 2, 256)
	update_shader_parameters()

func set_color_depth(depth: int) -> void:
	"""
	Set the color depth (number of levels per channel).
	Lower values = more visible dithering and retro look
	2 = extreme posterization
	4-8 = strong retro dithering
	16-32 = subtle dithering
	256 = full color range
	"""
	color_depth = clamp(depth, 2, 256)
	update_shader_parameters()
