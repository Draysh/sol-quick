#version 440

// A thin arc in `tone` (opaque, its `alpha` apart) round the middle of the
// item: `radius` pixels out, `thickness` wide, from the top clockwise over
// `sweep` of the circle (0–1), with round ends, its edges smoothed over a
// pixel.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tone;
    float alpha;
    vec2 size;
    float radius;
    float thickness;
    float sweep;
};

void main() {
    const float TAU = 6.28318531;
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    float r = length(p);
    float turn = atan(p.x, -p.y);
    if (turn < 0.0)
        turn += TAU;
    float end = clamp(sweep, 0.0, 1.0) * TAU;
    float d;
    if (turn <= end) {
        d = abs(r - radius);
    } else {
        vec2 last = radius * vec2(sin(end), -cos(end));
        d = min(distance(p, vec2(0.0, -radius)), distance(p, last));
    }
    float aa = max(fwidth(r), 1e-4);
    float cover = clamp((thickness * 0.5 - d) / aa + 0.5, 0.0, 1.0);
    fragColor = vec4(tone.rgb, 1.0) * (alpha * cover * qt_Opacity);
}
