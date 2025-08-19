shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Create pulsing effect
    float pulse = sin(TIME * pulse_speed) * 0.45 + 0.7;
    
    // Add glow
    vec4 final_color = tex_color * glow_color;
    final_color.rgb *= glow_intensity * pulse;
    
    COLOR = final_color;
}