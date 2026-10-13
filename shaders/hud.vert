#version 440

// The glass's corners, and where each is drawn on the window, as fractions
// of it from the top left (`onWindow`), for `hud.frag` to find the part of
// the ground under it without being told: the item's matrix already says
// where it is, however it scrolled or slid there. `yUp` is the graphics
// API's way up (OpenGL's clip space has y up; Vulkan, Metal and Direct3D
// have it down). Only right for a panel drawn straight into the window, not
// into a layer. The uniform block is the fragment shader's, as Qt requires.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(location = 1) out vec2 onWindow;

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

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
    vec2 ndc = gl_Position.xy / gl_Position.w;
    onWindow = vec2(ndc.x * 0.5 + 0.5, yUp > 0.5 ? 0.5 - ndc.y * 0.5 : ndc.y * 0.5 + 0.5);
}
