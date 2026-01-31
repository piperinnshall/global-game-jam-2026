shader_type canvas_item;

// Add the screen texture uniform for Godot 4.x
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Effect parameters
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float chrom_aberration_strength : hint_range(0.0, 10.0) = 2.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.5;
uniform int pixelation_amount : hint_range(1, 10) = 3;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float contrast : hint_range(0.5, 2.0) = 1.3;
uniform float dithering_strength : hint_range(0.0, 1.0) = 0.4;
uniform vec2 screen_size = vec2(1920.0, 1080.0);

// Random function for noise
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Better random with time
float noise(vec2 uv, float time) {
    return random(uv + time);
}

// Dithering pattern (Bayer matrix 4x4)
float bayer4x4(vec2 position) {
    int x = int(mod(position.x, 4.0));
    int y = int(mod(position.y, 4.0));
    
    float bayer[16] = float[](
        0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0,
        12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
        3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
        15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
    );
    
    return bayer[y * 4 + x];
}

// Simple bloom approximation
vec3 apply_bloom(sampler2D screen_tex, vec2 uv, vec2 pixel_size) {
    vec3 bloom = vec3(0.0);
    float total = 0.0;
    
    // Simple blur kernel
    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * pixel_size * 2.0;
            vec3 sample_color = texture(screen_tex, uv + offset).rgb;
            
            // Only bloom bright pixels
            float brightness = dot(sample_color, vec3(0.299, 0.587, 0.114));
            if(brightness > bloom_threshold) {
                float weight = 1.0 / (1.0 + length(vec2(float(x), float(y))));
                bloom += sample_color * weight;
                total += weight;
            }
        }
    }
    
    return total > 0.0 ? bloom / total : vec3(0.0);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 pixel_pos = FRAGCOORD.xy;
    
    // 1. PIXELATION
    if(pixelation_amount > 1) {
        vec2 pixelated = floor(uv * screen_size / float(pixelation_amount)) * float(pixelation_amount) / screen_size;
        uv = pixelated;
    }
    
    // 2. CHROMATIC ABERRATION
    float aberration = chrom_aberration_strength / screen_size.x;
    vec2 direction = uv - vec2(0.5);
    float dist = length(direction);
    
    float r = texture(screen_texture, uv + direction * aberration * dist).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - direction * aberration * dist).b;
    
    vec3 color = vec3(r, g, b);
    
    // 3. CONVERT TO BLACK AND WHITE (with contrast)
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    gray = pow(gray, 1.0 / contrast);
    
    // 4. DITHERING (for sketchy look)
    float dither = bayer4x4(pixel_pos) - 0.5;
    gray += dither * dithering_strength * 0.1;
    
    // Threshold to pure black and white with some midtones
    if(dithering_strength > 0.01) {
        gray = gray > (dither * dithering_strength + 0.5) ? 1.0 : 0.0;
    }
    
    color = vec3(gray);
    
    // 5. BLOOM
    if(bloom_intensity > 0.0) {
        vec3 bloom = apply_bloom(screen_texture, SCREEN_UV, SCREEN_PIXEL_SIZE);
        color += bloom * bloom_intensity;
    }
    
    // 6. SCANLINES
    if(scanline_intensity > 0.0) {
        float scanline = sin(pixel_pos.y * 3.14159 * 2.0) * 0.5 + 0.5;
        color *= 1.0 - (scanline * scanline_intensity);
    }
    
    // 7. NOISE (film grain)
    if(noise_intensity > 0.0) {
        float n = noise(uv * 5.0, TIME * 10.0);
        color += (n - 0.5) * noise_intensity;
    }
    
    // 8. VIGNETTE
    if(vignette_intensity > 0.0) {
        vec2 vignette_uv = uv * 2.0 - 1.0;
        float vignette = 1.0 - dot(vignette_uv, vignette_uv) * vignette_intensity;
        vignette = smoothstep(0.0, vignette_smoothness, vignette);
        color *= vignette;
    }
    
    // Clamp final output
    color = clamp(color, 0.0, 1.0);
    
    COLOR = vec4(color, 1.0);
}
