shader_type canvas_item;
render_mode unshaded;
uniform float seconds = 0.0;
uniform bool motion = false;
uniform bool spirit = false;
uniform vec2 lamp = vec2(.155,.635);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float breath = motion ? sin(seconds*1.5) : 0.0;
	// Feet / crop lower edge stay anchored; shoulders rise by less than one pixel.
	float upper = 1.0-smoothstep(.15,.98,uv.y);
	uv.y += breath*.0035*upper;
	uv.x += breath*.002*upper;
	vec4 ink = texture(TEXTURE,uv);
	float glow = exp(-dot((uv-lamp)*vec2(1.0,1.15),(uv-lamp)*vec2(1.0,1.15))*160.0);
	float wick = motion ? .045*sin(seconds*3.0)+.018*sin(seconds*7.5) : 0.0;
	vec3 light = spirit ? vec3(.55,1.0,.40) : vec3(1.0,.72,.30);
	ink.rgb += light*glow*(.045+wick);
	// The source carries its own alpha and brushwork; no painted-over face or halo.
	COLOR = ink*tint;
}
