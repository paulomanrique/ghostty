// TODO: Port the full background-image positioning logic from
// bg_image.v.glsl. Until then this emits a degenerate primitive so a
// configured background image simply doesn't draw on D3D11.
#include "common.hlsl"

struct VsInput {
    float opacity : ATTR0;
    uint info : ATTR1;
    uint vid : SV_VertexID;
};

struct VsOutput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD;
    float opacity : OPACITY;
};

VsOutput main(VsInput input) {
    VsOutput output;
    output.position = float4(0.0, 0.0, 0.0, 1.0);
    output.tex_coord = float2(0.0, 0.0);
    output.opacity = input.opacity;
    return output;
}
