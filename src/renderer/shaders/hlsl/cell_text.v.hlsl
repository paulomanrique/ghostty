#include "common.hlsl"

// Per-instance cell text attributes; layout mirrors shaders.CellText.
struct VsInput {
    uint2 glyph_pos : ATTR0;
    uint2 glyph_size : ATTR1;
    int2 bearings : ATTR2;
    uint2 grid_pos : ATTR3;
    uint4 color : ATTR4;
    uint atlas : ATTR5;
    uint glyph_bools : ATTR6;
    uint vid : SV_VertexID;
};

struct VsOutput {
    float4 position : SV_Position;
    nointerpolation uint atlas : ATLAS;
    nointerpolation float4 color : COLOR;
    nointerpolation float4 bg_color : BG_COLOR;
    float2 tex_coord : TEXCOORD;
};

static const uint NO_MIN_CONTRAST = 1u;
static const uint IS_CURSOR_GLYPH = 2u;

StructuredBuffer<uint> bg_colors : register(t1);

VsOutput main(VsInput input) {
    uint2 grid_size = unpack2u16(grid_size_packed_2u16);
    uint2 cursor_pos = unpack2u16(cursor_pos_packed_2u16);
    bool cursor_wide = (bools & CURSOR_WIDE) != 0;
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;

    float2 cell_pos = cell_size * float2(input.grid_pos);

    // Quad corner from the vertex id (triangle strip).
    float2 corner;
    corner.x = (input.vid == 1 || input.vid == 3) ? 1.0 : 0.0;
    corner.y = (input.vid == 2 || input.vid == 3) ? 1.0 : 0.0;

    VsOutput output;
    output.atlas = input.atlas;

    float2 size = float2(input.glyph_size);
    float2 offset = float2(input.bearings);
    offset.y = cell_size.y - offset.y;

    cell_pos = cell_pos + size * corner + offset;
    output.position = mul(projection_matrix, float4(cell_pos.x, cell_pos.y, 0.0f, 1.0f));

    // Texture coordinate in pixels (not normalized); the fragment
    // shader loads texels directly.
    output.tex_coord = float2(input.glyph_pos) + float2(input.glyph_size) * corner;

    // Color, always linearized for min-contrast math.
    output.color = load_color(input.color, true);
    output.bg_color = load_color(
        unpack4u8(bg_colors[input.grid_pos.y * grid_size.x + input.grid_pos.x]),
        true);
    float4 global_bg = load_color(unpack4u8(bg_color_packed_4u8), true);
    output.bg_color += global_bg * (1.0 - output.bg_color.a);

    if (min_contrast > 1.0f && (input.glyph_bools & NO_MIN_CONTRAST) == 0) {
        output.color = contrasted_color(min_contrast, output.color, output.bg_color);
    }

    bool is_cursor_pos = ((input.grid_pos.x == cursor_pos.x) ||
            (cursor_wide && (input.grid_pos.x == (cursor_pos.x + 1)))) &&
        (input.grid_pos.y == cursor_pos.y);

    if ((input.glyph_bools & IS_CURSOR_GLYPH) == 0 && is_cursor_pos) {
        output.color = load_color(unpack4u8(cursor_color_packed_4u8), use_linear_blending);
    }

    return output;
}
