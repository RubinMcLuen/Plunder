shader_type canvas_item;

uniform sampler2D map_texture;

void fragment() {
    // Sample the node's own texture (this comes from the SpriteFrames).
    vec4 uv_color = texture(TEXTURE, UV);
    if (uv_color.a < 0.1) {
        discard;
    }
    
    // The UV lookup is stored in the red and green channels.
    vec2 lookup_uv = vec2(uv_color.r, uv_color.g);
    
    // Get the size of the composite texture.
    vec2 map_size = vec2(textureSize(map_texture, 0));
    
    // Convert the normalized lookup UV into texel coordinates,
    // then sample at the center of that texel.
    vec2 texel_coord = floor(lookup_uv * map_size);
    vec2 exact_uv = (texel_coord + 0.5) / map_size;
    
    // Sample the composite texture at the computed coordinates.
    vec4 final_color = texture(map_texture, exact_uv);
    
    // Multiply the alpha from both textures.
    final_color.a *= uv_color.a;
    
    COLOR = final_color;
}
