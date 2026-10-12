#version 440

// A star's light: `tone` (opaque, its `alpha` apart), `strength` bright at
// the middle, falling off through two stops (`falloff`: where, and how much
// of the heart is left; then the second) to nothing at the edge of the
// item's circle.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tone;
    float alpha;
    float strength;
    vec4 falloff;
};

void main() {
    float d = length(qt_TexCoord0 - 0.5) * 2.0;
    float a;
    if (d < falloff.x)
        a = mix(1.0, falloff.y, d / max(falloff.x, 1e-4));
    else if (d < falloff.z)
        a = mix(falloff.y, falloff.w, (d - falloff.x) / max(falloff.z - falloff.x, 1e-4));
    else
        a = mix(falloff.w, 0.0, clamp((d - falloff.z) / max(1.0 - falloff.z, 1e-4), 0.0, 1.0));
    fragColor = vec4(tone.rgb, 1.0) * (alpha * a * strength * qt_Opacity);
}
