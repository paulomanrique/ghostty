#include "common.hlsl"

Texture2D<float4> image : register(t0);
SamplerState image_sampler : register(s0);

struct PsInput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD;
};

float4 main(PsInput input) : SV_Target {
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;

    float4 rgba = image.SampleLevel(image_sampler, input.tex_coord, 0);

    if (!use_linear_blending) {
        rgba = unlinearize4(rgba);
    }

    rgba.rgb *= rgba.a;

    return rgba;
}
