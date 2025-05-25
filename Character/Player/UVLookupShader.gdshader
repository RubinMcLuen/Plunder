shader_type canvas_item;

/* Per-sprite palette with red flash.
   Unused pixels are discarded so hidden parts never show. */

uniform sampler2D map_texture;
uniform bool  hurt_mode = false;
uniform vec4  hurt_color : source_color = vec4(0.678, 0.196, 0.196, 0.6);  // #AD3232

void fragment() {
    vec4 src = texture(TEXTURE, UV);
    if (src.a < 0.05) { discard; }

    vec2 sz  = vec2(textureSize(map_texture, 0));
    vec4 col = texture(map_texture, (floor(src.rg * sz) + 0.5) / sz);

    if (col.a < 0.05) { discard; }

    col.a *= src.a;

    if (hurt_mode)
        col.rgb = mix(col.rgb, hurt_color.rgb, hurt_color.a);

        // full RGBA modulate
        // preserve RGB, but multiply alpha by modulate.a
    COLOR = vec4(col.rgb, col.a * COLOR.a);


}
