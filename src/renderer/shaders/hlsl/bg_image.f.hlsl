// See bg_image.v.hlsl: background images are not drawn on D3D11 yet.
struct PsInput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD;
    float opacity : OPACITY;
};

float4 main(PsInput input) : SV_Target {
    return float4(0.0, 0.0, 0.0, 0.0);
}
