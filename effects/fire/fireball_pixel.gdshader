shader_type canvas_item;
render_mode unshaded, blend_mix;

// Animate progress from 0 to 1. No textures or TIME dependency.
uniform float progress : hint_range(0.0, 1.0) = 0.32;
uniform float pixel_resolution : hint_range(16.0, 128.0, 1.0) = 64.0;
uniform float variation : hint_range(0.0, 1000.0) = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.72, 1.0);
uniform vec4 yellow_color : source_color = vec4(1.0, 0.76, 0.20, 1.0);
uniform vec4 orange_color : source_color = vec4(1.0, 0.32, 0.055, 1.0);
uniform vec4 red_color : source_color = vec4(0.67, 0.085, 0.055, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.20, 0.15, 0.23, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_value(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
    vec2 p = ((floor(UV * pixel_resolution) + 0.5) / pixel_resolution - 0.5) * 2.0;
    float t = clamp(progress, 0.0, 1.0);
    float frame = floor(t * 18.0) / 18.0;
    vec2 seed = vec2(variation * 3.13, variation * 0.71);
    vec2 flow = p * 5.0 + vec2(0.0, frame * 3.6) + seed;
    float n = noise_value(flow) * 0.67 + noise_value(flow * 2.1) * 0.33;
    float radius = 0.06 + 0.52 * (1.0 - pow(1.0 - min(t * 3.0, 1.0), 3.0));
    radius *= 1.0 - 0.24 * smoothstep(0.40, 1.0, t);
    // Lift the smoke while the flame cools.
    vec2 body_p = p + vec2(0.0, 0.13 * t);
    float d = length(body_p * vec2(1.0, 1.06));
    float shape = radius - d + (n - 0.5) * (0.13 + t * 0.22);
    float body = step(0.0, shape);
    float erosion = smoothstep(0.52, 1.0, t);
    body *= step(erosion * 0.90, n);
    float heat = clamp(shape / max(radius, 0.01) + n * 0.60 - t * 0.70, 0.0, 1.0);
    vec4 col = red_color;
    if (heat > 0.22) { col = orange_color; }
    if (heat > 0.46) { col = yellow_color; }
    if (heat > 0.70) { col = core_color; }
    if (t > 0.43 && heat < 0.18 + (t - 0.43) * 0.95) {
        col = smoke_color;
        if (n > 0.56) { col.rgb *= 1.30; }
    }
    col.a *= body;
    // A thin, expanding shock ring. Hard edges preserve pixel-art contours.
    float ring_radius = 0.12 + 0.72 * (1.0 - pow(1.0 - t, 3.0));
    float ring = step(abs(length(p) - ring_radius), 0.023);
    ring *= step(t, 0.37) * step(0.035, t);
    if (ring > 0.0) { col = orange_color; }
    // Deterministic sparks: every instance can have its own variation.
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        float h = hash(vec2(fi + variation, 8.1));
        float angle = fi * 2.399963 + h * 0.4 + variation;
        vec2 dir = vec2(cos(angle), sin(angle));
        float travel = (0.12 + 0.69 * (1.0 - pow(1.0 - t, 2.0))) * (0.80 + h * 0.20);
        vec2 center = dir * travel + vec2(0.0, t * t * 0.10);
        float spark_size = mix(0.035, 0.012, t);
        float spark = step(max(abs(p.x - center.x), abs(p.y - center.y)), spark_size);
        spark *= step(0.06, t) * step(t, 0.58 + h * 0.20);
        if (spark > 0.0) { col = yellow_color; }
    }
    // Short impact flash, confined to the effect itself.
    if (t > 0.0 && t < 0.085 && length(p) < 0.12 + t * 3.0) { col = core_color; }
    col.a *= step(0.001, t) * (1.0 - step(0.999, t));
    COLOR = col;
}
