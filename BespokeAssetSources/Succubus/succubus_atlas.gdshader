shader_type canvas_item;
uniform sampler2D tex : source_color;
uniform int frames_h = 6;
uniform int frames_v = 1;
uniform int frame = 0;
void fragment() {
    int fh = max(frames_h, 1);
    int fv = max(frames_v, 1);
    int idx = clamp(frame, 0, fh*fv - 1);
    int fx = idx % fh;
    int fy = idx / fh;
    vec2 cell = vec2(1.0/float(fh), 1.0/float(fv));
    vec2 uv = UV * cell + vec2(float(fx), float(fy)) * cell;
    COLOR = texture(tex, uv);
}