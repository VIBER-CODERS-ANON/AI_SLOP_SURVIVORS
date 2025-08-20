shader_type canvas_item;

// Trail and motion blur
uniform float swing_speed : hint_range(0.0, 20.0) = 0.0;
uniform float trail_length : hint_range(0.0, 1.0) = 0.3;
uniform vec4 trail_color : source_color = vec4(0.7, 0.9, 1.0, 0.5);

// Energy blade effect
uniform float energy_intensity : hint_range(0.0, 3.0) = 1.5;
uniform vec4 energy_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float energy_pulse_speed : hint_range(0.0, 10.0) = 3.0;

// Edge glow
uniform float edge_glow : hint_range(0.0, 1.0) = 0.8;
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Slash effect
uniform float slash_intensity : hint_range(0.0, 2.0) = 0.0;
uniform vec4 slash_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Process only visible pixels
    if (tex_color.a > 0.01) {
        // Energy pulse effect
        float pulse = sin(TIME * energy_pulse_speed) * 0.3 + 0.7;
        
        // Create energy blade effect (runs along the blade)
        float energy_wave = sin(UV.y * 10.0 - TIME * 5.0) * 0.5 + 0.5;
        vec3 energy_effect = energy_color.rgb * energy_intensity * pulse * energy_wave;
        
        // Edge detection for glow (simple gradient based on UV)
        float edge_factor = 1.0 - abs(UV.x - 0.5) * 2.0;
        edge_factor = pow(edge_factor, 2.0);
        vec3 edge_glow_effect = edge_color.rgb * edge_glow * edge_factor;
        
        // Motion blur / trail effect based on swing speed
        float motion_blur = clamp(swing_speed * trail_length, 0.0, 1.0);
        vec4 trail_effect = trail_color * motion_blur;
        
        // Slash effect (activated during fast swings)
        vec3 slash_effect = slash_color.rgb * slash_intensity * (1.0 - UV.y);
        
        // Combine all effects
        vec3 final_color = tex_color.rgb;
        final_color += energy_effect * tex_color.a;
        final_color += edge_glow_effect * tex_color.a;
        final_color += slash_effect * tex_color.a;
        
        // Add trail overlay
        final_color = mix(final_color, trail_effect.rgb, trail_effect.a * motion_blur);
        
        // Output with original alpha
        COLOR = vec4(final_color, tex_color.a);
        
        // Add extra glow to alpha for bloom effect
        COLOR.a = min(tex_color.a + (energy_intensity * pulse * 0.2), 1.0);
    } else {
        // For transparent pixels, just pass through
        COLOR = tex_color;
    }
}