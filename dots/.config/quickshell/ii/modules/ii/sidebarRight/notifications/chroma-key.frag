// Compile with: qsb --qt6 -o chroma-key.frag.qsb chroma-key.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float chroma;
    float panelR;
    float panelG;
    float panelB;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 color = texture(source, qt_TexCoord0);
    // Green screen: keep pixels that are not dominated by green.
    float key = color.g - max(color.r, color.b);
    float alpha = 1.0 - smoothstep(0.18, 0.38, key) * chroma;
    // The video surface sits above ordinary siblings, so the effect paints an
    // opaque cutout against the panel colour instead of relying on alpha.
    vec3 panel = vec3(panelR, panelG, panelB);
    vec3 rgb = mix(panel, color.rgb, alpha);
    fragColor = vec4(rgb, 1.0) * qt_Opacity;
}
