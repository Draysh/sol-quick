#version 440

// A HUD panel's glass: the blurred art under it, tinted, with any of its
// corners cut away at 45° and a hairline just inside its edge. `cuts` is
// how much each corner loses (top-left, top-right, bottom-right,
// bottom-left), in pixels; the edge is smoothed over a pixel. `rect` is
// the part of `source` under the panel (x, y, width, height, as fractions):
// the Shell's one blurred ground, shared by every panel. With `screen`, the
// part is found from where the panel is drawn on the window (`hud.vert`
// passes each corner's place on it, `ground` is where the ground lies on
// the window, as fractions), so a panel that scrolls or slides needs
// nothing set from outside. Without `glassy` (nothing to blur yet) it is
// the tint alone.
//
// It reads as glass: the tint lies a little thinner at the top than at the
// foot (not on Terra's bright sky), so the art shows through most where
// the panel catches the light;
// a faint sheen falls from the top edge; and the top edge (and the cut
// corner's diagonal) has a 1 px highlight, brightest in the middle.
//
// `motif` is the world's flavour on its panels, drawn here so it costs
// nothing more: 1, a faint seigaiha (overlapping waves) in the lower
// corners (Mercury); 2, a neon edge that glows inward and fine scanlines
// (Neptune); 3, a sheen of daylight from the top (Terra); 4, washi: a
// faint asanoha (hemp-leaf) lattice over the whole panel and the paper's
// fibres, for a sheet of paper (Mercury's cards); 0, none (Saturn).
// `accent` is its light, `glow` how lit the edge is (a hover).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 1) in vec2 onWindow;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cuts;
    vec4 tint;
    float tintAlpha;
    vec4 line;
    float lineAlpha;
    float glassy;
    vec4 rect;
    vec4 accent;
    float motif;
    float glow;
    float screen;
    float yUp;
    vec4 ground;
};
layout(binding = 1) uniform sampler2D source;

// How near `p` is to a ring of the seigaiha drawn with circles of radius `r`, 0 to 1.
float seigaiha(vec2 p, float r) {
    float ring = -1.0;
    float n0 = floor(p.y / r);
    // The row below is drawn over the row above, as the waves overlap.
    for (int k = 0; k < 2; k++) {
        float n = n0 + float(k);
        float off = mod(n, 2.0) * r;
        float cx = floor((p.x - off) / (2.0 * r) + 0.5) * 2.0 * r + off;
        for (int j = -1; j <= 1; j++) {
            float d = length(p - vec2(cx + float(j) * 2.0 * r, n * r));
            if (d < r) ring = d;
        }
    }
    if (ring < 0.0) return 0.0;
    float step = r / 3.0;
    float gap = abs(ring / step - floor(ring / step + 0.5)) * step;
    return 1.0 - smoothstep(0.4, 1.1, gap);
}

// The distance from `p` to the segment from `a` to `b`.
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return length(p - a - ab * t);
}

// How near `p` is to a line of the asanoha drawn on triangles of side `s`, 0 to 1: the
// triangles' own sides and, in each, a line from every corner to its middle.
float asanoha(vec2 p, float s) {
    float h = s * 0.8660254;
    // Which triangle `p` is in, on the skewed grid of the lattice.
    float v = p.y / h;
    float u = p.x / s - v * 0.5;
    vec2 cell = floor(vec2(u, v));
    vec2 f = vec2(u, v) - cell;
    vec2 a = cell, b = cell + vec2(1.0, 0.0), c = cell + vec2(0.0, 1.0);
    if (f.x + f.y > 1.0) a = cell + vec2(1.0, 1.0);
    // Back to pixels.
    vec2 A = vec2((a.x + a.y * 0.5) * s, a.y * h);
    vec2 B = vec2((b.x + b.y * 0.5) * s, b.y * h);
    vec2 C = vec2((c.x + c.y * 0.5) * s, c.y * h);
    vec2 M = (A + B + C) / 3.0;
    float d = min(min(segment(p, A, B), segment(p, B, C)), segment(p, C, A));
    d = min(d, min(min(segment(p, A, M), segment(p, B, M)), segment(p, C, M)));
    return 1.0 - smoothstep(0.35, 1.0, d);
}

// A little value noise, for the paper's fibres.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), w.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), w.x), w.y);
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 far = size - px;
    const float k = 0.70710678;
    // Distance inside the panel's edge, in pixels: its sides, then each cut corner's diagonal.
    float d = min(min(px.x, px.y), min(far.x, far.y));
    d = min(d, (px.x + px.y - cuts.x) * k);
    d = min(d, (far.x + px.y - cuts.y) * k);
    d = min(d, (far.x + far.y - cuts.z) * k);
    d = min(d, (px.x + far.y - cuts.w) * k);
    float cover = clamp(d + 0.5, 0.0, 1.0);
    // The art (premultiplied, opaque) under the tint.
    float baseA = glassy > 0.5 ? 1.0 : 0.0;
    vec2 at = screen > 0.5 ? (onWindow - ground.xy) / ground.zw : rect.xy + qt_TexCoord0 * rect.zw;
    vec3 base = glassy > 0.5 ? texture(source, at).rgb : vec3(0.0);
    // Thinner at the top, fuller at the foot (glass over art only: paper, the tint alone and Terra's
    // bright summer sky, where quiet words need all of the tint, stay even).
    float ta = glassy > 0.5 && motif < 2.5 ? clamp(tintAlpha + mix(-0.06, 0.04, qt_TexCoord0.y), 0.0, 1.0) : tintAlpha;
    vec3 c = base * (1.0 - ta) + tint.rgb * ta;
    float a = baseA * (1.0 - ta) + ta;
    // The sheen: a little light from the top edge, gone a third of the way down.
    c = mix(c, vec3(1.0), 0.045 * pow(clamp(1.0 - px.y / max(1.0, min(size.y, 160.0)), 0.0, 1.0), 2.0));

    vec3 hair = line.rgb;
    float hairA = lineAlpha;
    if (motif > 0.5 && motif < 1.5) {
        // Waves in the lower corners, fading towards the middle.
        float corner = min(length(vec2(px.x, far.y)), length(far));
        float w = (1.0 - smoothstep(30.0, 130.0, corner)) * seigaiha(vec2(px.x, px.y), 11.0);
        c = mix(c, accent.rgb, 0.16 * w);
    } else if (motif > 1.5 && motif < 2.5) {
        // Fine scanlines, and the edge lit in neon, glowing inward.
        c *= 1.0 - 0.07 * step(0.5, fract(px.y / 3.0));
        float lit = 0.35 + 0.65 * glow;
        c = mix(c, accent.rgb, lit * 0.32 * exp(-max(d, 0.0) / 7.0));
        hair = accent.rgb;
        hairA = 0.55 + 0.45 * glow;
    } else if (motif > 2.5 && motif < 3.5) {
        // Daylight from above.
        c = mix(c, vec3(1.0), 0.07 * (1.0 - qt_TexCoord0.y));
    } else if (motif > 3.5) {
        // Paper: long fibres running every way, a lattice of hemp leaves, and the light through it, warmer below.
        vec2 q = mat2(0.8, -0.6, 0.6, 0.8) * px;
        float fibre = smoothstep(0.62, 0.95, noise(q * vec2(0.035, 0.42))) + smoothstep(0.7, 0.98, noise(px.yx * vec2(0.05, 0.5) + 17.0));
        c = mix(c, vec3(1.0), 0.05 * fibre);
        c = mix(c, accent.rgb, 0.06 * asanoha(px, 34.0));
        c *= 1.0 - 0.035 * qt_TexCoord0.y;
    }
    // The hairline: the outermost pixel inside the edge.
    float la = hairA * clamp(1.5 - d, 0.0, 1.0);
    c = c * (1.0 - la) + hair * la;
    a = a * (1.0 - la) + la;
    // The highlight: the top edge and the top-right cut catch the light, brightest mid-way along.
    float top = min(px.y, (far.x + px.y - cuts.y) * k);
    float along = sin(3.14159265 * clamp(qt_TexCoord0.x, 0.0, 1.0));
    float ha = (0.18 + 0.32 * along) * clamp(1.5 - top, 0.0, 1.0) * step(0.5, min(size.x, size.y));
    c = c * (1.0 - ha) + vec3(1.0) * ha;
    a = a * (1.0 - ha) + ha;
    fragColor = vec4(c, a) * (qt_Opacity * cover);
}
