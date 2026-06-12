// Common definitions shared across the Ghostty D3D11 shaders. The
// cbuffer layout matches the `Uniforms` extern struct byte-for-byte via
// explicit packoffsets (the struct is shared with the OpenGL backend).

cbuffer Globals : register(b1) {
    float4x4 projection_matrix : packoffset(c0);
    float2 screen_size : packoffset(c4.x);
    float2 cell_size : packoffset(c4.z);
    uint grid_size_packed_2u16 : packoffset(c5.x);
    float4 grid_padding : packoffset(c6);
    uint padding_extend : packoffset(c7.x);
    float min_contrast : packoffset(c7.y);
    uint cursor_pos_packed_2u16 : packoffset(c7.z);
    uint cursor_color_packed_4u8 : packoffset(c7.w);
    uint bg_color_packed_4u8 : packoffset(c8.x);
    uint bools : packoffset(c8.y);
};

// Bools
static const uint CURSOR_WIDE = 1u;
static const uint USE_DISPLAY_P3 = 2u;
static const uint USE_LINEAR_BLENDING = 4u;
static const uint USE_LINEAR_CORRECTION = 8u;

// Padding extend
static const uint EXTEND_LEFT = 1u;
static const uint EXTEND_RIGHT = 2u;
static const uint EXTEND_UP = 4u;
static const uint EXTEND_DOWN = 8u;

uint4 unpack4u8(uint packed_value) {
    return uint4(
        (packed_value >> 0) & 0xFFu,
        (packed_value >> 8) & 0xFFu,
        (packed_value >> 16) & 0xFFu,
        (packed_value >> 24) & 0xFFu);
}

uint2 unpack2u16(uint packed_value) {
    return uint2(
        (packed_value >> 0) & 0xFFFFu,
        (packed_value >> 16) & 0xFFFFu);
}

float luminance(float3 color) {
    return dot(color, float3(0.2126f, 0.7152f, 0.0722f));
}

float contrast_ratio(float3 color1, float3 color2) {
    float luminance1 = luminance(color1) + 0.05;
    float luminance2 = luminance(color2) + 0.05;
    return max(luminance1, luminance2) / min(luminance1, luminance2);
}

float4 contrasted_color(float min_ratio, float4 fg, float4 bg) {
    float ratio = contrast_ratio(fg.rgb, bg.rgb);
    if (ratio < min_ratio) {
        float white_ratio = contrast_ratio(float3(1.0, 1.0, 1.0), bg.rgb);
        float black_ratio = contrast_ratio(float3(0.0, 0.0, 0.0), bg.rgb);
        if (white_ratio > black_ratio) {
            return float4(1.0, 1.0, 1.0, 1.0);
        } else {
            return float4(0.0, 0.0, 0.0, 1.0);
        }
    }
    return fg;
}

float4 linearize4(float4 srgb) {
    bool3 cutoff = srgb.rgb <= 0.04045;
    float3 higher = pow((srgb.rgb + 0.055) / 1.055, 2.4);
    float3 lower = srgb.rgb / 12.92;
    return float4(lerp(higher, lower, cutoff), srgb.a);
}

float linearize1(float v) {
    return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
}

float4 unlinearize4(float4 lin) {
    bool3 cutoff = lin.rgb <= 0.0031308;
    float3 higher = pow(lin.rgb, 1.0 / 2.4) * 1.055 - 0.055;
    float3 lower = lin.rgb * 12.92;
    return float4(lerp(higher, lower, cutoff), lin.a);
}

float unlinearize1(float v) {
    return v <= 0.0031308 ? v * 12.92 : pow(v, 1.0 / 2.4) * 1.055 - 0.055;
}

float4 load_color(uint4 in_color, bool linear_) {
    float4 color = float4(in_color) / 255.0f;
    if (linear_) color = linearize4(color);
    color.rgb *= color.a;
    return color;
}
