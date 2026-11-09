shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.3;
uniform float pixel_resolution : hint_range(16.0, 128.0, 1.0) = 64.0;
uniform float variation : hint_range(0.0, 1000.0) = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 0.83, 1.0);
uniform vec4 yellow_color : source_color = vec4(1.0, 0.88, 0.08, 1.0);
uniform vec4 amber_color : source_color = vec4(0.86, 0.43, 0.025, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.00001), 0.0, 1.0);
    return length(p - a - ab * h);
}

void fragment() {
    vec2 p = ((floor(UV * pixel_resolution) + 0.5) / pixel_resolution - 0.5) * 2.0;
    float t = clamp(progress, 0.0, 1.0);
    float frame = floor(t * 16.0);
    float r = length(p);
    float angle = atan(p.y, p.x);
    float expansion = 1.0 - pow(1.0 - t, 2.4);
    float radius = 0.055 + expansion * 0.73;
    float jitter = sin(angle * 13.0 + variation + frame * 1.1) * 0.012;
    jitter += sin(angle * 23.0 - variation - frame * 0.6) * 0.007;
    float ring_d = abs(r - radius - jitter);
    float width = mix(0.034, 0.012, t);
    float breakup = hash(vec2(floor((angle + 3.141593) * 12.0), frame + variation));
    float ring_live = step(0.02, t) * (1.0 - step(0.88, t));
    ring_live *= step(max(0.0, (t - 0.48) * 1.7), breakup);
    float border = step(ring_d, width + 0.019) * ring_live;
    float yellow = step(ring_d, width) * ring_live;
    float white = step(ring_d, width * 0.28) * ring_live;

    // Twelve short zigzag bolts ride the expanding wave; branches flicker at 16 Hz.
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        float h = hash(vec2(fi + variation, 31.7));
        float a = fi * 6.283185 / 12.0 + (h - 0.5) * 0.30 + variation;
        vec2 dir = vec2(cos(a), sin(a));
        vec2 side = vec2(-dir.y, dir.x);
        float reach = (0.14 + h * 0.16) * (1.0 - t * 0.45);
        float start_r = radius * 0.70;
        vec2 previous = dir * start_r;
        float bolt_d = 5.0;
        float branch_d = 5.0;
        for (int j = 1; j <= 5; j++) {
            float fj = float(j);
            float zig = (hash(vec2(fi * 7.0 + fj + variation, frame)) - 0.5) * 0.12;
            vec2 point = dir * mix(start_r, min(radius + reach, 0.92), fj / 5.0);
            point += side * zig;
            bolt_d = min(bolt_d, segment_distance(p, previous, point));
            if (j == 3) {
                vec2 end = point + dir * 0.09 + side * (h > 0.5 ? 0.09 : -0.09);
                branch_d = segment_distance(p, point, end);
            }
            previous = point;
        }
        bolt_d = min(bolt_d, branch_d);
        float live = step(0.04 + h * 0.04, t) * (1.0 - step(0.55 + h * 0.29, t));
        float bolt_width = mix(0.018, 0.008, t);
        border = max(border, step(bolt_d, bolt_width + 0.018) * live);
        yellow = max(yellow, step(bolt_d, bolt_width) * live);
        white = max(white, step(bolt_d, bolt_width * 0.32) * live);
    }
    // Small square embers remain briefly after the wave passes.
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float h = hash(vec2(fi + variation, 81.3));
        float a = fi * 2.399963 + variation;
        vec2 center = vec2(cos(a), sin(a)) * (0.18 + expansion * (0.52 + h * 0.20));
        vec2 q = abs(p - center);
        float size = mix(0.029, 0.009, t);
        float live = step(0.14, t) * (1.0 - step(0.64 + h * 0.30, t));
        float spark = step(max(q.x, q.y), size) * live;
        yellow = max(yellow, spark);
    }
    // Central star on impact; no full-screen flash or bloom.
    float flash = step(t, 0.13) * step(0.001, t);
    float star = max(step(abs(p.x), 0.025) * step(abs(p.y), 0.20),
        step(abs(p.y), 0.025) * step(abs(p.x), 0.20));
    white = max(white, max(star, step(r, 0.10)) * flash);
    vec4 col = amber_color;
    if (yellow > 0.0) { col = yellow_color; }
    if (white > 0.0) { col = core_color; }
    col.a *= max(border, max(yellow, white));
    col.a *= step(0.001, t) * (1.0 - step(0.999, t));
    COLOR = col;
}
