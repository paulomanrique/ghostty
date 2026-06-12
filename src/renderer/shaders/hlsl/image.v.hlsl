#include "common.hlsl"

Texture2D<float4> image : register(t0);

struct VsInput {
    float2 grid_pos : ATTR0;
    float2 cell_offset : ATTR1;
    float4 source_rect : ATTR2;
    float2 dest_size : ATTR3;
    uint vid : SV_VertexID;
};

struct VsOutput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD;
};

VsOutput main(VsInput input) {
    // Quad corner from the vertex id (triangle strip).
    float2 corner;
    corner.x = (input.vid == 1 || input.vid == 3) ? 1.0 : 0.0;
    corner.y = (input.vid == 2 || input.vid == 3) ? 1.0 : 0.0;

    float2 tex_coord = input.source_rect.xy + input.source_rect.zw * corner;

    float tex_w;
    float tex_h;
    image.GetDimensions(tex_w, tex_h);
    tex_coord /= float2(tex_w, tex_h);

    float2 image_pos = (cell_size * input.grid_pos) + input.cell_offset;
    image_pos += input.dest_size * corner;

    VsOutput output;
    output.position = mul(projection_matrix, float4(image_pos.xy, 1.0, 1.0));
    output.tex_coord = tex_coord;
    return output;
}
