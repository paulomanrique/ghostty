#include "common.hlsl"

Texture2D<float4> image : register(t0);
SamplerState image_sampler : register(s0);

struct PsInput {
    float4 position : SV_Position;
    nointerpolation float4 bg_color : BG_COLOR;
    nointerpolation float2 offset : OFFSET;
    nointerpolation float2 scale : SCALE;
    nointerpolation float opacity : OPACITY;
    nointerpolation uint repeat : REPEAT;
};

float4 main(PsInput input) : SV_Target {
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;

    // Texture coordinate from the screen position, offset by the dest
    // rect origin and scaled by the dest/texture size ratio.
    float2 tex_coord = (input.position.xy - input.offset) * input.scale;

    float tex_w;
    float tex_h;
    image.GetDimensions(tex_w, tex_h);
    float2 tex_size = float2(tex_w, tex_h);

    // If we need to repeat the texture, wrap the coordinates.
    if (input.repeat != 0) {
        tex_coord = fmod(fmod(tex_coord, tex_size) + tex_size, tex_size);
    }

    float4 rgba;
    if (any(tex_coord < float2(0.0, 0.0)) || any(tex_coord > tex_size)) {
        rgba = float4(0.0, 0.0, 0.0, 0.0);
    } else {
        rgba = image.SampleLevel(image_sampler, tex_coord / tex_size, 0);

        if (!use_linear_blending) {
            rgba = unlinearize4(rgba);
        }

        rgba.rgb *= rgba.a;
    }

    // Cap the opacity so it isn't overexposed relative to the
    // background color alpha.
    rgba *= min(input.opacity, 1.0 / input.bg_color.a);

    // Blend onto a fully opaque version of the background color.
    rgba += max(float4(0.0, 0.0, 0.0, 0.0), float4(input.bg_color.rgb, 1.0) * (1.0 - rgba.a));

    // Multiply everything by the background color alpha.
    rgba *= input.bg_color.a;

    return rgba;
}
