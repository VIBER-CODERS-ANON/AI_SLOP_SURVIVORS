shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // If texture is empty/white, create our own red color
    if (tex_color.r > 0.99 && tex_color.g > 0.99 && tex_color.b > 0.99) {
        tex_color = vec4(0.9, 0.1, 0.1, 1.0); // Force red color
    }
    
    // Create pulsing effect
    float pulse = sin(TIME * pulse_speed) * 0.45 + 0.35;
    
    // Apply pulsing glow
    COLOR = tex_color;
    COLOR.rgb *= (1.0 + (pulse * glow_intensity));
}