#version 440

// A picture graded in one colour on a light ground (`PaperTone`): its
// colours gone, its light kept, each pixel's lightness laid between two
// colours, the deep of the light in the shadows and paper in the
// highlights. `contrast` steepens the ramp round its middle and
// `brightness` lifts it (-1 to 1, as MultiEffect's), so the light lies in
// the shade and the paper where the picture is bright.
// A `middle` colour (when it isn't transparent) makes it three: shadow to
// middle up to `pivot`, then middle to highlight, so the highlight's colour
// lies only in the brightest parts (Luna's indigo night lit by the moon).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 shadow;
    vec4 highlight;
    float contrast;
    float brightness;
    vec4 middle;
    float pivot;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 p = texture(source, qt_TexCoord0);
    vec3 c = p.a > 0.0 ? p.rgb / p.a : vec3(0.0);
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    l = clamp((l - 0.5) * (1.0 + contrast) + 0.5 + brightness, 0.0, 1.0);
    vec3 g = middle.a > 0.0
        ? (l < pivot ? mix(shadow.rgb, middle.rgb, l / pivot) : mix(middle.rgb, highlight.rgb, smoothstep(pivot, 1.0, l)))
        : mix(shadow.rgb, highlight.rgb, l);
    fragColor = vec4(g * p.a, p.a) * qt_Opacity;
}
