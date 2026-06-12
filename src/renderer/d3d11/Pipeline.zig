//! Wrapper for handling render pipelines: compiled vertex + pixel
//! shaders, the input layout derived from the vertex attributes type,
//! and the blend state.
const Self = @This();

const std = @import("std");
const com = @import("com.zig");

const log = std.log.scoped(.d3d11);

pub const Options = struct {
    device: *com.ID3D11Device,

    /// HLSL source of the vertex/pixel shaders.
    vertex_fn: [:0]const u8,
    fragment_fn: [:0]const u8,

    /// Vertex step function
    step_fn: StepFunction = .per_vertex,

    /// Whether to enable blending.
    blending_enabled: bool = true,

    pub const StepFunction = enum {
        constant,
        per_vertex,
        per_instance,
    };
};

vs: *com.ID3D11VertexShader,
ps: *com.ID3D11PixelShader,
layout: ?*com.ID3D11InputLayout,
blend: ?*com.ID3D11BlendState,
stride: usize,
blending_enabled: bool,

fn compileShader(src: [:0]const u8, target: [*:0]const u8) !*com.ID3DBlob {
    var blob: ?*com.ID3DBlob = null;
    var errors: ?*com.ID3DBlob = null;
    const hr = com.compile(
        src.ptr,
        src.len,
        null,
        null,
        null,
        "main",
        target,
        0,
        0,
        &blob,
        &errors,
    );
    if (errors) |e| {
        defer e.release();
        if (hr != 0) {
            log.err("HLSL compile error: {s}", .{
                e.getBufferPointer()[0..e.getBufferSize()],
            });
        }
    }
    if (hr != 0 or blob == null) return error.ShaderCompileFailed;
    return blob.?;
}

pub fn init(comptime VertexAttributes: ?type, opts: Options) !Self {
    const vs_blob = try compileShader(opts.vertex_fn, "vs_5_0");
    defer vs_blob.release();
    const ps_blob = try compileShader(opts.fragment_fn, "ps_5_0");
    defer ps_blob.release();

    var vs: ?*com.ID3D11VertexShader = null;
    if (opts.device.createVertexShader(
        vs_blob.getBufferPointer(),
        vs_blob.getBufferSize(),
        null,
        &vs,
    ) != 0 or vs == null) return error.D3D11Failed;
    errdefer vs.?.release();

    var ps: ?*com.ID3D11PixelShader = null;
    if (opts.device.createPixelShader(
        ps_blob.getBufferPointer(),
        ps_blob.getBufferSize(),
        null,
        &ps,
    ) != 0 or ps == null) return error.D3D11Failed;
    errdefer ps.?.release();

    var layout: ?*com.ID3D11InputLayout = null;
    if (VertexAttributes) |VA| {
        const descs = comptime inputLayout(VA);
        var per_desc = descs;
        for (&per_desc) |*d| {
            d.InputSlotClass = switch (opts.step_fn) {
                .per_vertex => 0,
                .per_instance, .constant => 1,
            };
            d.InstanceDataStepRate = switch (opts.step_fn) {
                .per_vertex => 0,
                .per_instance => 1,
                .constant => 0,
            };
        }
        if (opts.device.createInputLayout(
            &per_desc,
            per_desc.len,
            vs_blob.getBufferPointer(),
            vs_blob.getBufferSize(),
            &layout,
        ) != 0 or layout == null) return error.D3D11Failed;
    }
    errdefer if (layout) |l| l.release();

    var blend: ?*com.ID3D11BlendState = null;
    if (opts.blending_enabled) {
        var desc: com.D3D11_BLEND_DESC = .{
            .RenderTarget = std.mem.zeroes([8]com.D3D11_RENDER_TARGET_BLEND_DESC),
        };
        desc.RenderTarget[0] = .{
            .BlendEnable = 1,
            .SrcBlend = com.D3D11_BLEND_ONE,
            .DestBlend = com.D3D11_BLEND_INV_SRC_ALPHA,
            .BlendOp = com.D3D11_BLEND_OP_ADD,
            .SrcBlendAlpha = com.D3D11_BLEND_ONE,
            .DestBlendAlpha = com.D3D11_BLEND_INV_SRC_ALPHA,
            .BlendOpAlpha = com.D3D11_BLEND_OP_ADD,
            .RenderTargetWriteMask = 0x0F,
        };
        if (opts.device.createBlendState(&desc, &blend) != 0 or blend == null)
            return error.D3D11Failed;
    }

    return .{
        .vs = vs.?,
        .ps = ps.?,
        .layout = layout,
        .blend = blend,
        .stride = if (VertexAttributes) |VA| @sizeOf(VA) else 0,
        .blending_enabled = opts.blending_enabled,
    };
}

pub fn deinit(self: *const Self) void {
    if (self.blend) |b| b.release();
    if (self.layout) |l| l.release();
    self.ps.release();
    self.vs.release();
}

/// Build the input element descriptors for a vertex attributes struct
/// at comptime, using ATTR0..ATTRn semantics matching the HLSL inputs.
fn inputLayout(comptime T: type) [@typeInfo(T).@"struct".fields.len]com.D3D11_INPUT_ELEMENT_DESC {
    const fields = @typeInfo(T).@"struct".fields;
    var descs: [fields.len]com.D3D11_INPUT_ELEMENT_DESC = undefined;
    inline for (fields, 0..) |field, i| {
        const FT = switch (@typeInfo(field.type)) {
            .@"struct" => |s| s.backing_integer.?,
            .@"enum" => |e| e.tag_type,
            else => field.type,
        };

        const format: com.DXGI_FORMAT = switch (FT) {
            [2]u32 => .rg32_uint,
            [4]u32 => .rgba32_uint,
            [2]i16 => .rg16_sint,
            [2]u16 => .rg16_uint,
            [4]u8 => .rgba8_uint,
            u8 => .r8_uint,
            u32 => .r32_uint,
            f32 => .r32_float,
            [2]f32 => .rg32_float,
            [4]f32 => .rgba32_float,
            else => @compileError("unsupported vertex attribute type: " ++ @typeName(FT)),
        };

        descs[i] = .{
            .SemanticName = "ATTR",
            .SemanticIndex = i,
            .Format = format,
            .AlignedByteOffset = @offsetOf(T, field.name),
            .InputSlotClass = 1,
            .InstanceDataStepRate = 1,
        };
    }
    return descs;
}
