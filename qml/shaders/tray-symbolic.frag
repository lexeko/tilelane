#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 foreground;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 pixel = texture(source, qt_TexCoord0);
    float high = max(pixel.r, max(pixel.g, pixel.b));
    float low = min(pixel.r, min(pixel.g, pixel.b));
    // Saturation is unchanged by premultiplied alpha. Keep colored badges,
    // but tint neutral pixels so they remain visible on either theme.
    float saturation = (high - low) / max(high, 0.00001);
    float keepColor = smoothstep(0.05, 0.20, saturation);
    fragColor = mix(foreground * pixel.a, pixel, keepColor) * qt_Opacity;
}
