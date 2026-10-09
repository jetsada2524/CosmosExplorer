shader_type canvas_item;
// ==============================================================
//  cockpit_gradient.gdshader  (third-person vignette)
//  danger  → red edge vignette
//  safe_level → green edge vignette
// ==============================================================

uniform float danger     : hint_range(0.0, 1.0) = 0.0;
uniform float safe_level : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // map UV to -1..1 range, measure distance from center
    vec2  uv = UV * 2.0 - 1.0;
    float d  = length(uv);

    // vignette strength: 0 in center, 1 at corners
    float vig = smoothstep(0.45, 1.30, d);

    if (danger > 0.0) {
        COLOR = vec4(0.85, 0.05, 0.02, vig * 0.78 * danger);
    } else if (safe_level > 0.0) {
        COLOR = vec4(0.08, 0.85, 0.32, vig * 0.50 * safe_level);
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}
