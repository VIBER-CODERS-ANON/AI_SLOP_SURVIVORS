shader_type canvas_item;

/* Simple shader to display first frame of spritesheet */
uniform int frames_h : hint_range(1, 64) = 6; // columns
uniform int frames_v : hint_range(1, 64) = 1; // rows

void fragment() {
    // Show only the first frame of the spritesheet
    vec2 cols_rows = vec2(float(frames_h), float(frames_v));
    vec2 uv_scale = 1.0 / cols_rows;
    
    // Map UV to first frame only
    vec2 uv = UV * uv_scale;
    vec4 tex = texture(TEXTURE, uv);
    COLOR = tex * COLOR;
}