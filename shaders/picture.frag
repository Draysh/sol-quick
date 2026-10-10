#version 440

// A picture with rounded corners: the image's texture placed by `frame`
// (where its painted rect lies, in the item's 0–1 space: offset, then
// size), magnified by `zoom` about the centre (a picture lifting under the
// pointer), and cut to a rounded rect `radius` pixels round, its edge
// smoothed over a pixel. Outside a picture that only fits, nothing shows.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    vec4 frame;
    float zoom;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    vec2 half_ = size * 0.5;
    float r = min(radius, min(half_.x, half_.y));
    vec2 q = abs(px - half_) - (half_ - vec2(r));
    float d = r - length(max(q, 0.0)) - min(max(q.x, q.y), 0.0);
    float cover = clamp(d / max(fwidth(d), 1e-4) + 0.5, 0.0, 1.0);
    vec2 t = ((uv - 0.5) / zoom + 0.5 - frame.xy) / frame.zw;
    float inside = step(0.0, t.x) * step(t.x, 1.0) * step(0.0, t.y) * step(t.y, 1.0);
    fragColor = texture(source, t) * (qt_Opacity * cover * inside);
}
