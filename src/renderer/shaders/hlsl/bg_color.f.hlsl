#include "common.hlsl"

float4 main(float4 frag_coord : SV_Position) : SV_Target {
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;
    return load_color(unpack4u8(bg_color_packed_4u8), use_linear_blending);
}
