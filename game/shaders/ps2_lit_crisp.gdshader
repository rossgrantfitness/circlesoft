// PS2 look, per-pixel lit, CRISP textures (nearest-neighbour, no mipmaps): the same shader as ps2_lit for the texture
// groups the profile's `texture_filter` block marks "nearest" (Ross's pixel-art city tiles).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D orm_texture : hint_default_white, filter_nearest, repeat_enable;

#include "ps2_lit_body.gdshaderinc"
