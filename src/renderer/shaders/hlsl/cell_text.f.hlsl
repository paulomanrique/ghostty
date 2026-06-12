#include "common.hlsl"

Texture2D<float4> atlas_grayscale : register(t0);
Texture2D<float4> atlas_color : register(t1);

struct PsInput {
    float4 position : SV_Position;
    nointerpolation uint atlas : ATLAS;
    nointerpolation float4 color : COLOR;
    nointerpolation float4 bg_color : BG_COLOR;
    float2 tex_coord : TEXCOORD;
};

static const uint ATLAS_GRAYSCALE = 0u;
static const uint ATLAS_COLOR = 1u;

float4 main(PsInput input) : SV_Target {
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;
    bool use_linear_correction = (bools & USE_LINEAR_CORRECTION) != 0;

    if (input.atlas == ATLAS_COLOR) {
        // Color glyphs are premultiplied linear colors.
        float4 color = atlas_color.Load(int3(int2(input.tex_coord), 0));

        if (use_linear_blending) {
            return color;
        }

        color.rgb /= color.a;
        color = unlinearize4(color);
        color.rgb *= color.a;
        return color;
    }

    // Grayscale atlas. Our input color is always linear.
    float4 color = input.color;

    if (!use_linear_blending) {
        color.rgb /= color.a;
        color = unlinearize4(color);
        color.rgb *= color.a;
    }

    float a = atlas_grayscale.Load(int3(int2(input.tex_coord), 0)).r;

    if (use_linear_correction) {
        float4 bg = input.bg_color;
        float fg_l = luminance(color.rgb);
        float bg_l = luminance(bg.rgb);
        if (abs(fg_l - bg_l) > 0.001) {
            float blend_l = linearize1(unlinearize1(fg_l) * a + unlinearize1(bg_l) * (1.0 - a));
            a = clamp((blend_l - bg_l) / (fg_l - bg_l), 0.0, 1.0);
        }
    }

    color *= a;
    return color;
}
