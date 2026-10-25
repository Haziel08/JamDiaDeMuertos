shader_type canvas_item;
// Filtro de paleta: redibuja lo que hay en pantalla usando SOLO los colores de la paleta.
// Va en un ColorRect a pantalla completa, dentro de un CanvasLayer encima del mapa
// y debajo del HUD (así la interfaz conserva sus colores).

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec4 palette[16] : source_color;
uniform int palette_size : hint_range(1, 16) = 8;
// 0 = color más parecido · 1 = por brillo (rampa de oscuro a claro)
uniform int mode : hint_range(0, 1) = 1;
uniform float strength : hint_range(0.0, 1.0) = 1.0;   // 0 = original, 1 = solo paleta
uniform float contrast : hint_range(0.5, 2.0) = 1.15;  // solo para el modo por brillo
uniform float saturation : hint_range(0.0, 2.0) = 1.0; // >1 = colores más vivos (efecto atardecer)

// --- Atardecer: luz cálida que va de naranja (arriba) a lila (abajo) y orillas oscuras ---
uniform float sunset : hint_range(0.0, 1.0) = 0.55;          // 0 = sin atardecer
uniform vec4 sky_top : source_color = vec4(1.0, 0.55, 0.32, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.55, 0.36, 0.62, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.5;        // oscurece las esquinas

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 nearest_color(vec3 c) {
	// Distancia "redmean": se parece más a cómo vemos el color que la distancia RGB simple.
	vec3 best = palette[0].rgb;
	float best_d = 1e9;
	for (int i = 0; i < 16; i++) {
		if (i >= palette_size) break;
		vec3 p = palette[i].rgb;
		float rm = (c.r + p.r) * 0.5;
		vec3 d = c - p;
		float dist = (2.0 + rm) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rm) * d.b * d.b;
		if (dist < best_d) { best_d = dist; best = p; }
	}
	return best;
}

vec3 brightness_ramp(vec3 c) {
	// Ordena la paleta de oscuro a claro y asigna cada píxel según su brillo.
	float l = clamp((luma(c) - 0.5) * contrast + 0.5, 0.0, 1.0);
	// Cuenta cuántos colores de la paleta son más oscuros que el píxel
	// (equivale a escoger el escalón de la rampa sin tener que ordenar).
	float target = l * float(palette_size - 1);
	vec3 best = palette[0].rgb;
	float best_d = 1e9;
	for (int i = 0; i < 16; i++) {
		if (i >= palette_size) break;
		float rank = 0.0;
		float li = luma(palette[i].rgb);
		for (int j = 0; j < 16; j++) {
			if (j >= palette_size) break;
			if (luma(palette[j].rgb) < li) rank += 1.0;
		}
		float d = abs(rank - target);
		if (d < best_d) { best_d = d; best = palette[i].rgb; }
	}
	return best;
}

void fragment() {
	vec4 original = texture(screen_texture, SCREEN_UV);
	vec3 mapped = mode == 0 ? nearest_color(original.rgb) : brightness_ramp(original.rgb);
	vec3 color = mix(original.rgb, mapped, strength);
	// Saturación: separa el color de su brillo y lo intensifica.
	float l = luma(color);
	color = clamp(vec3(l) + (color - vec3(l)) * saturation, 0.0, 1.0);
	// Luz de atardecer (mezcla tipo "soft light": tiñe sin quemar los claros).
	vec3 tint = mix(sky_top.rgb, sky_bottom.rgb, SCREEN_UV.y);
	vec3 lit = mix(2.0 * color * tint, 1.0 - 2.0 * (1.0 - color) * (1.0 - tint), step(0.5, color));
	color = mix(color, lit, sunset);
	// Viñeta: las orillas de la pantalla se oscurecen, como luz que se va.
	vec2 c = SCREEN_UV - 0.5;
	c.x *= 1.6;
	color *= 1.0 - vignette * smoothstep(0.35, 0.95, length(c));
	COLOR = vec4(color, 1.0);
}
