shader_type canvas_item;

uniform sampler2D player_visual_texture : source_color;
uniform float player_visual_ready = 0.0;
uniform vec2 player_world_to_local_x = vec2(1.0, 0.0);
uniform vec2 player_world_to_local_y = vec2(0.0, 1.0);
uniform vec2 player_world_to_local_origin = vec2(0.0);
uniform vec2 player_visual_texture_size = vec2(1.0);
uniform vec2 player_visual_region_origin = vec2(0.0);
uniform vec2 player_visual_region_size = vec2(1.0);
uniform float occluded_opacity = 0.48;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tile_color = texture(TEXTURE, UV) * COLOR;
	if (player_visual_ready > 0.5) {
		// Convert this wall pixel into the player's actual visual texture space.
		// This makes the reveal follow the character silhouette instead of using
		// a circular area around the character.
		vec2 player_local = vec2(
			dot(world_position, player_world_to_local_x) + player_world_to_local_origin.x,
			dot(world_position, player_world_to_local_y) + player_world_to_local_origin.y
		);
		vec2 player_uv = player_visual_region_origin +
			(player_local + player_visual_region_size * 0.5) / player_visual_texture_size;
		float player_alpha = texture(player_visual_texture, player_uv).a;
		float occluded_pixel = smoothstep(0.04, 0.30, player_alpha);
		tile_color.a *= mix(1.0, occluded_opacity, occluded_pixel);
	}
	COLOR = tile_color;
}
