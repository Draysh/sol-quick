#version 440

// A world, lit from one side. The item is a square 3.4 discs wide: the disc
// has radius 1 in its middle and the glow reaches out to 1.7. `mode` 0 is a
// disc (a planet or a moon), 1 a star (Sol), 2 a photograph used whole
// (Saturn). `away` points from the light to the shadow; `phase` 0 is new,
// 1 full. `effect` 1 adds Titan's haze, 2 Mercury's split rim. `live` 1
// drifts clouds over the disc, 2 makes a star's corona flicker; `time` is
// seconds, and 0 keeps everything still.

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
};
layout(binding = 1) uniform sampler2D source;

float ring(float d, float at, float width) {
    float x = (d - at) / width;
    return exp(-x * x);
}

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
    float px = 3.4 / 600.0; // about a pixel, for soft edges
    vec4 out_ = vec4(0.0);

    if (mode == 2) {
        // The photograph fitted into the disc's box, whole.
        vec2 uv = vec2((p.x + 1.0) * 0.5, (p.y / aspect + 1.0) * 0.5);
        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
            out_ = texture(source, uv);
        }
        fragColor = out_ * qt_Opacity;
        return;
    }

    vec2 uv = (p + 1.0) * 0.5;
    float inside = 1.0 - smoothstep(1.0 - px * 2.0, 1.0 + px, d);
    vec4 photo = texture(source, clamp(uv, 0.0, 1.0));

    if (mode == 1) {
        // A star: the corona, the tinted disc, a darker limb, and the night side.
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

    // A disc: the photograph, a soft terminator, and the limb glowing on the lit side.
    float reach = clamp(phase, 0.0, 1.0) * 2.0;
    vec2 occluder = away * reach;
    float shadow = phase < 1.0 ? 1.0 - smoothstep(0.90, 1.10, length(p - occluder)) : 0.0;
    // A touch of real shading across the lit side, so the body reads as a sphere.
    vec3 n = vec3(p, sqrt(max(0.0, 1.0 - d * d)));
    vec3 L = normalize(vec3(-away, 0.9));
    float lambert = clamp(dot(n, L), 0.0, 1.0);
    float lit = mix(0.85, 1.0, lambert);
    vec3 base = photo.a > 0.5 ? photo.rgb : vec3(0.10);
    if (live == 1) {
        // Clouds drifting across the sphere, thinner towards the limb, white in
        // the light and grey in the shadow; the photograph shows through.
        vec2 sphere = vec2(asin(clamp(p.x, -1.0, 1.0)), asin(clamp(p.y, -1.0, 1.0)));
        float c = clouds(sphere, time);
        float cover = smoothstep(0.52, 0.78, c) * 0.55 * (0.4 + 0.6 * n.z);
        base = mix(base, vec3(0.92, 0.94, 0.97), cover);
    }
    vec3 body = base * lit * (1.0 - shadow * 0.985);
    vec4 disc = vec4(body, 1.0) * inside;

    // The glow, only on the lit limb: masked by a soft circle on the shadow side.
    vec2 shade = away * (reach * 1.1 + 0.05);
    float litSide = smoothstep(1.0, 1.25, length(p - shade));
    float glow = 0.0;
    vec3 glowColor = world.rgb;
    // The atmosphere breathes: the glow swells a touch and back, slowly.
    float breath = live > 0 ? 1.0 + 0.12 * sin(time * 0.5) : 1.0;
    if (effect == 1) {
        float haze = live > 0 ? 1.0 + 0.25 * noise(vec2(atan(p.y, p.x) * 2.0 + time * 0.1, time * 0.07)) : 1.0;
        glow = (ring(d, 1.04, 0.05) * 0.7 + ring(d, 1.04, 0.012) * 0.3) * haze;
        glowColor = mix(world.rgb, vec3(0.91, 0.63, 0.38), 0.3);
    } else {
        glow = ring(d, 1.004, 0.03) * 0.8 * breath;
    }
    vec4 halo = vec4(glowColor, 1.0) * glow * litSide * smoothstep(0.97, 1.0, d);
    if (effect == 2) {
        float red = ring(length(p - vec2(-0.016, 0.01)), 1.01, 0.015) * 0.8;
        float blue = ring(length(p - vec2(0.016, -0.01)), 1.01, 0.015) * 0.8;
        halo += vec4(1.0, 0.29, 0.23, 1.0) * red * litSide + vec4(0.23, 0.48, 1.0, 1.0) * blue * litSide;
    }
    out_ = disc + halo * (1.0 - inside * 0.4);
    fragColor = out_ * qt_Opacity;
}
