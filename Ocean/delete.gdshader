shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture;
uniform float boost : hint_range(0.0, 1.0) = 0.4; // 0.4 represents a +40% saturation boost

void fragment() {
    vec3 col = texture(screen_tex, SCREEN_UV).rgb;
    // Find the maximum channel (preserving the max, as in Aseprite)
    float m = max(col.r, max(col.g, col.b));
    
    vec3 res;
    // Use a small threshold for float equality
    res.r = (abs(col.r - m) < 0.001) ? col.r : col.r - (m - col.r) * boost;
    res.g = (abs(col.g - m) < 0.001) ? col.g : col.g - (m - col.g) * boost;
    res.b = (abs(col.b - m) < 0.001) ? col.b : col.b - (m - col.b) * boost;
    
    COLOR = vec4(res, 1.0);
}
