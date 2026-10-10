#version 440

// Glass over a blurred page: the picture bends a little at the panel's
// edges, as light does through a thick pane, and a thin highlight runs
// along the top. `edge` is how far in the bend reaches, in pixels; 0 is
// flat glass. `radius` rounds the corners: outside them nothing shows,
// and the edge between is smoothed over a pixel.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float edge;
    float radius;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    // Distance inside the rounded panel's edge, in pixels (negative outside).
    vec2 half_ = size * 0.5;
    float r = min(radius, min(half_.x, half_.y));
    vec2 q = abs(px - half_) - (half_ - vec2(r));
    float d = r - length(max(q, 0.0)) - min(max(q.x, q.y), 0.0);
    float cover = clamp(d / max(fwidth(d), 1e-4) + 0.5, 0.0, 1.0);
    // A soft curve into the edge.
    float bend = edge > 0.0 ? pow(clamp(1.0 - d / edge, 0.0, 1.0), 2.0) : 0.0;
    // Bend towards the centre, more the closer to the edge.
    vec2 dir = normalize((uv - 0.5) + vec2(1e-5));
    vec2 shifted = uv - dir * bend * (6.0 / size);
    vec4 c = texture(source, clamp(shifted, 0.0, 1.0));
    // A highlight along the top edge and a faint one at the bottom.
    float top = exp(-px.y * px.y / 2.0) * 0.14;
    float bottom = exp(-(size.y - px.y) * (size.y - px.y) / 6.0) * 0.04;
    c.rgb += vec3(top + bottom);
    fragColor = c * (qt_Opacity * cover);
}
