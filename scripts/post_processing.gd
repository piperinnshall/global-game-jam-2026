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
var noise_intensity: float = 0.02
var contrast: float = 1.01
var dithering_strength: float = 0.2

# Shader material
var shader_material: ShaderMaterial

func _ready() -> void:
	# Wait for the scene tree to be ready
	await get_tree().process_frame
	setup_post_processing()

func setup_post_processing() -> void:
	# Get the root viewport
	viewport = get_viewport()
	
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
	
	# Add to the scene tree at the root level (rendered on top)
	get_tree().root.add_child.call_deferred(color_rect)
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	if color_rect:
		color_rect.size = get_viewport().get_visible_rect().size
		color_rect.position = Vector2.ZERO
		update_shader_parameters()

func update_shader_parameters() -> void:
	if not shader_material:
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	
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

func set_dithering(strength: float) -> void:
	dithering_strength = strength
	update_shader_parameters()
