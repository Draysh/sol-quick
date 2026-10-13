#version 440

// An impact frame's silhouette of what was hit: its shape (the source's
// alpha) filled flat in `color`, smeared along `smear` (a fraction of its
// size, the way it was struck) by averaging the shape back along it, so the
// first drawing of a hit reads as a stretched blur of motion and the next
// as a hard flat shape.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color;
    vec2 smear;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float a = 0.0;
    const int n = 12;
    for (int i = 0; i < n; i++) {
        vec2 at = qt_TexCoord0 - smear * (float(i) / float(n - 1));
        if (at.x >= 0.0 && at.y >= 0.0 && at.x <= 1.0 && at.y <= 1.0) a += texture(source, at).a;
    }
    a = length(smear) > 0.0 ? clamp(a / float(n) * 1.6, 0.0, 1.0) : texture(source, qt_TexCoord0).a;
    fragColor = vec4(color.rgb, 1.0) * color.a * a * qt_Opacity;
}
