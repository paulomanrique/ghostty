#include "common.hlsl"

Texture2D<float4> image : register(t0);

struct VsInput {
    float opacity : ATTR0;
    uint info : ATTR1;
    uint vid : SV_VertexID;
};

struct VsOutput {
    float4 position : SV_Position;
    nointerpolation float4 bg_color : BG_COLOR;
    nointerpolation float2 offset : OFFSET;
    nointerpolation float2 scale : SCALE;
    nointerpolation float opacity : OPACITY;
    nointerpolation uint repeat : REPEAT;
};

// 4 bits of info.
static const uint BG_IMAGE_POSITION = 15u;
static const uint BG_IMAGE_TL = 0u;
static const uint BG_IMAGE_TC = 1u;
static const uint BG_IMAGE_TR = 2u;
static const uint BG_IMAGE_ML = 3u;
static const uint BG_IMAGE_MC = 4u;
static const uint BG_IMAGE_MR = 5u;
static const uint BG_IMAGE_BL = 6u;
static const uint BG_IMAGE_BC = 7u;
static const uint BG_IMAGE_BR = 8u;

// 2 bits of info shifted 4.
static const uint BG_IMAGE_FIT = 3u << 4;
static const uint BG_IMAGE_CONTAIN = 0u << 4;
static const uint BG_IMAGE_COVER = 1u << 4;
static const uint BG_IMAGE_STRETCH = 2u << 4;
static const uint BG_IMAGE_NO_FIT = 3u << 4;

// 1 bit of info shifted 6.
static const uint BG_IMAGE_REPEAT = 1u << 6;

VsOutput main(VsInput input) {
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;

    VsOutput output;

    // Single full-screen triangle clipped to viewport.
    float4 position;
    position.x = (input.vid == 2) ? 3.0 : -1.0;
    position.y = (input.vid == 0) ? -3.0 : 1.0;
    position.z = 1.0;
    position.w = 1.0;
    output.position = position;

    output.opacity = input.opacity;
    output.repeat = input.info & BG_IMAGE_REPEAT;

    float tex_w;
    float tex_h;
    image.GetDimensions(tex_w, tex_h);
    float2 tex_size = float2(tex_w, tex_h);

    float2 dest_size = tex_size;
    switch (input.info & BG_IMAGE_FIT) {
        case BG_IMAGE_CONTAIN: {
            float s = min(screen_size.x / tex_size.x, screen_size.y / tex_size.y);
            dest_size = tex_size * s;
            break;
        }
        case BG_IMAGE_COVER: {
            float s = max(screen_size.x / tex_size.x, screen_size.y / tex_size.y);
            dest_size = tex_size * s;
            break;
        }
        case BG_IMAGE_STRETCH: {
            dest_size = screen_size;
            break;
        }
        case BG_IMAGE_NO_FIT: {
            dest_size = tex_size;
            break;
        }
        default:
            break;
    }

    float2 start = float2(0.0, 0.0);
    float2 mid = (screen_size - dest_size) / 2.0;
    float2 end = screen_size - dest_size;

    float2 dest_offset = mid;
    switch (input.info & BG_IMAGE_POSITION) {
        case BG_IMAGE_TL: dest_offset = float2(start.x, start.y); break;
        case BG_IMAGE_TC: dest_offset = float2(mid.x, start.y); break;
        case BG_IMAGE_TR: dest_offset = float2(end.x, start.y); break;
        case BG_IMAGE_ML: dest_offset = float2(start.x, mid.y); break;
        case BG_IMAGE_MC: dest_offset = float2(mid.x, mid.y); break;
        case BG_IMAGE_MR: dest_offset = float2(end.x, mid.y); break;
        case BG_IMAGE_BL: dest_offset = float2(start.x, end.y); break;
        case BG_IMAGE_BC: dest_offset = float2(mid.x, end.y); break;
        case BG_IMAGE_BR: dest_offset = float2(end.x, end.y); break;
        default: break;
    }

    output.offset = dest_offset;
    output.scale = tex_size / dest_size;

    // Fully opaque version of the bg color, with the alpha kept
    // separate for the fragment shader.
    uint4 u_bg_color = unpack4u8(bg_color_packed_4u8);
    output.bg_color = float4(
        load_color(uint4(u_bg_color.rgb, 255), use_linear_blending).rgb,
        float(u_bg_color.a) / 255.0);

    return output;
}
