// PS2 look, per-pixel lit, SMOOTH textures (linear filtering with mipmaps). The default for Ross's final art
// (characters, enemies, weapons). See ps2_lit_body.gdshaderinc for what it does.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back, fog_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

#include "ps2_lit_body.gdshaderinc"
