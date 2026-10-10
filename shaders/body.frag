#version 440

// A world, lit from one side. The item is a square 3.4 radii wide: the
// disc has radius 1 in its middle and the glow reaches out to 1.7. `mode` 0 is a
// disc (a planet or a moon), 1 a star (Sol), 2 a photograph used whole
// (Saturn). `away` points from the light to the shadow; `phase` 0 is new,
// 1 full. `fit` is where the disc is in the photograph (centre and radius in
// its coordinates) and how far to turn the photograph (radians, clockwise).
// `air` is how much atmosphere there is (0 none, 1 Titan's); `effect` 1 makes
// it a haze that rings even the night side. `live` 1 drifts clouds over the
// disc, 2 makes a star's corona flicker; `time` is seconds, and 0 keeps
// everything still.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 away;
    float phase;
    vec4 world;
    int mode;
    int effect;
    float aspect;   // the photograph's height / width (mode 2)
    float time;
    int live;
    float day;      // 1 by day: the night side lets the sky through, as the moon does in daylight
    vec4 fit;
    float air;
};
layout(binding = 1) uniform sampler2D source;

// Cheap value noise, enough for clouds and a flicker.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float clouds(vec2 p, float t) {
    float n = noise(p * 3.0 + vec2(t * 0.05, 0.0)) * 0.5;
    n += noise(p * 7.0 + vec2(t * 0.09, t * 0.02)) * 0.3;
    n += noise(p * 15.0 - vec2(t * 0.13, 0.0)) * 0.2;
    return n;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 3.4;
    float d = length(p);
    float px = max(fwidth(d), 1e-4); // a pixel, at any size, for soft edges
    vec4 out_ = vec4(0.0);

    if (mode == 2) {
        // The photograph fitted into the disc's box, whole; the black of
        // space in it lets whatever is behind show through. The photograph is
        // light on black, so it is laid on as light: what is nearly black
        // becomes see-through, and no dark fringe is left at the edges (by
        // day, on a pale sky, the dim limb goes too). Only the body and its
        // rings, a flat ellipse across the box: stray specks (moons too small
        // to read) are left out.
        vec2 uv = fit.xy + vec2(p.x, p.y / aspect) * fit.z;
        float band = length(p / vec2(1.0, 0.45));
        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0 && band < 1.05) {
            vec3 c = texture(source, uv).rgb;
            float bright = max(c.r, max(c.g, c.b));
            float a = smoothstep(mix(0.02, 0.04, day), mix(0.14, 0.3, day), bright) * smoothstep(1.05, 0.98, band);
            vec3 lit = max(c - vec3(0.015), vec3(0.0)) / 0.985;
            out_ = vec4(min(lit, vec3(a * 1.6)), a);
        }
        fragColor = out_ * qt_Opacity;
        return;
    }

    float inside = 1.0 - smoothstep(1.0 - px * 1.5, 1.0 + px * 0.5, d);

    if (mode == 1) {
        // A star: the corona, the tinted disc, a darker limb, and the night side.
        vec4 photo = texture(source, clamp((p + 1.0) * 0.5, 0.0, 1.0));
        float flicker = live == 2 ? 0.85 + 0.3 * noise(vec2(atan(p.y, p.x) * 3.0, time * 0.4)) : 1.0;
        float corona = smoothstep(1.7, 0.55, d) * flicker;
        vec3 coronaColor = mix(vec3(0.72, 0.25, 0.10) * 0.16, world.rgb * 0.55, smoothstep(0.75, 0.55, d));
        out_ = vec4(coronaColor, 1.0) * corona * smoothstep(1.7, 1.0, d) * (1.0 - inside);
        vec3 tinted = vec3(
            0.75 * photo.r + 0.45 * photo.g + 0.10 * photo.b + 0.06,
            0.32 * photo.r + 0.32 * photo.g + 0.06 * photo.b + 0.01,
            0.06 * photo.r + 0.06 * photo.g + 0.03 * photo.b);
        if (live == 2) {
            // Granules: a slow boil over the surface.
            tinted *= 0.92 + 0.16 * noise(p * 9.0 + vec2(time * 0.06, -time * 0.04));
        }
        float limb = smoothstep(0.55, 1.0, d);
        tinted = mix(tinted, vec3(0.16, 0.03, 0.0), limb * 0.5);
        tinted *= 1.0 - smoothstep(0.88, 1.0, d) * 0.85;
        if (phase < 1.0) {
            float along = dot(p, normalize(away + vec2(1e-5))) * 0.5 + 0.5;
            tinted *= 1.0 - mix(0.92, 0.0, smoothstep(0.0, 1.0, along));
        }
        vec4 disc = vec4(tinted, 1.0) * inside;
        out_ = out_ * (1.0 - inside) + disc;
        fragColor = out_ * qt_Opacity;
        return;
    }

    // A disc: a sphere lit by a distant sun. The light's direction comes from
    // the phase (the lit fraction k = (1 + cos a) / 2) and `away`: towards the
    // viewer at full, behind the body at new.
    float cosA = clamp(phase, 0.0, 1.0) * 2.0 - 1.0;
    float sinA = sqrt(max(0.0, 1.0 - cosA * cosA));
    vec3 L = vec3(-normalize(away + vec2(1e-5)) * sinA, cosA);
    float dd = min(d, 1.0);
    vec3 n = vec3(p / max(d, 1e-4) * dd, sqrt(max(0.0, 1.0 - dd * dd)));
    float mu0 = dot(n, L);  // the sun's height over the ground
    float mu = n.z;         // the viewer's

    // Small on screen (the sidebar's 22 px, the bar's 24), the night side is
    // lifted a little so the whole body still reads.
    float size = 2.0 / px;
    float small = 1.0 - smoothstep(28.0, 96.0, size);
    float thick = clamp(air, 0.0, 1.0);

    // The photograph: the disc where it is in the picture, turned so its own
    // light faces this one.
    float ct = cos(fit.w);
    float st = sin(fit.w);
    vec2 q = p / max(d, 1.0);
    vec2 turned = vec2(ct * q.x + st * q.y, -st * q.x + ct * q.y);
    vec4 photo = texture(source, clamp(fit.xy + turned * fit.z, 0.0, 1.0));
    vec3 base = photo.a > 0.5 ? photo.rgb : vec3(0.10);
    if (live == 1) {
        // Clouds drifting across the sphere, thinner towards the limb, white
        // where the sun is on them; the photograph shows through.
        vec2 sphere = vec2(asin(clamp(p.x, -1.0, 1.0)), asin(clamp(p.y, -1.0, 1.0)));
        float c = clouds(sphere, time);
        float cover = smoothstep(0.52, 0.78, c) * 0.5 * (0.4 + 0.6 * mu);
        // Under a haze (Titan) the clouds are faint, and the haze's colour.
        vec3 cloud = effect == 1 ? mix(base, vec3(1.0, 0.86, 0.62), 0.5) : vec3(0.92, 0.94, 0.97);
        base = mix(base, cloud, effect == 1 ? cover * 0.6 : cover);
    }

    // The terminator: soft where there is air to bend the light, crisp on rock,
    // never sharper than a pixel and a half.
    float w = max(mix(0.035, 0.14, thick), px * 1.5);
    float dayside = smoothstep(-w * 0.6, w, mu0);
    // How the ground brightens with the sun's height: rock like the Moon's is
    // as bright at its limb as in its middle when full (Lommel–Seeliger),
    // cloud and air darken towards a low sun (Lambert, against the photograph's
    // own shading).
    float m0 = max(mu0, 0.0);
    float rock = 2.0 * m0 / (m0 + mu + 0.02);
    float soft = m0 / max(mu, 0.32);
    float shade = min(mix(rock, soft, min(1.0, thick * 2.0)), 1.25);
    // A gentle darkening at the very limb of a body without air.
    shade *= mix(mix(0.8, 1.0, smoothstep(0.0, 0.45, mu)), 1.0, min(1.0, thick * 2.0));
    // Air over the lit ground, thicker towards the limb: a veil of the world's colour.
    float veil = thick * pow(1.0 - mu, 2.5) * smoothstep(-0.1, 0.5, mu0);
    vec3 ground = mix(base * shade, world.rgb * (0.35 + 0.65 * smoothstep(0.0, 0.6, mu0)), min(0.6, veil * 0.8));
    // The night side: almost black, with a faint ambient that grows towards new,
    // as earthshine does on the young moon.
    float ambient = mix(0.025 + 0.09 * pow(1.0 - clamp(phase, 0.0, 1.0), 2.0), 0.16, small) * (1.0 - day * 0.75);
    vec3 body = mix(base * ambient, ground, dayside);
    // By day the sky shows through wherever the body is dark (the night side,
    // the dusk towards the terminator), and the body's light adds to it, as
    // the moon's does in daylight.
    float glowing = smoothstep(0.0, 0.3, dot(body, vec3(0.3, 0.5, 0.2)));
    float alpha = mix(1.0, max(0.08, glowing), day);
    vec4 disc = vec4(body, alpha) * inside;

    // The atmosphere seen edge-on: a thin rim beyond the limb, brightest under
    // the sun and wrapping a little past the terminator; backlit, it rings the
    // whole body. A haze (Titan) also rings the night side, faintly.
    vec4 halo = vec4(0.0);
    if (thick > 0.0) {
        vec2 dir = p / max(d, 1e-4);
        float depth = max(0.012 + 0.055 * thick, px * 1.2);
        float above = max(d - 1.0, 0.0);
        float fall = exp(-above / depth) * smoothstep(1.0 - px * 1.5, 1.0 + px * 0.5, d);
        float under = dot(dir, L.xy) + 0.4 * L.z;
        float litRim = smoothstep(-0.35, 0.55, under) + smoothstep(0.4, 1.0, -L.z) * 0.6;
        if (effect == 1) litRim = mix(0.3, 1.0, clamp(litRim, 0.0, 1.0));
        // The atmosphere breathes: the rim swells a touch and back, slowly.
        float breath = live > 0 ? 1.0 + 0.05 * sin(time * 0.5) : 1.0;
        float strength = (0.25 + 0.65 * thick) * mix(1.0, 0.6, day);
        float glow = fall * clamp(litRim, 0.0, 1.0) * strength * breath;
        vec3 glowColor = effect == 1 ? mix(world.rgb, vec3(0.95, 0.62, 0.30), 0.35) : world.rgb;
        halo = vec4(glowColor * glow, glow * 0.35);
    }
    out_ = disc + halo * (1.0 - inside);
    fragColor = out_ * qt_Opacity;
}
