//! Wrapper for handling render passes.
const Self = @This();

const std = @import("std");
const com = @import("com.zig");

const Sampler = @import("Sampler.zig");
const Target = @import("Target.zig");
const Texture = @import("Texture.zig");
const Pipeline = @import("Pipeline.zig");
const bufferpkg = @import("buffer.zig");

const log = std.log.scoped(.d3d11);

/// Options for beginning a render pass.
pub const Options = struct {
    ctx: *com.ID3D11DeviceContext,

    /// Color attachments for this render pass.
    attachments: []const Attachment,

    pub const Attachment = struct {
        target: union(enum) {
            texture: Texture,
            target: Target,
        },
        clear_color: ?[4]f32 = null,
    };
};

/// Describes a step in a render pass.
pub const Step = struct {
    pipeline: Pipeline,
    uniforms: ?bufferpkg.Handle = null,
    buffers: []const ?bufferpkg.Handle = &.{},
    textures: []const ?Texture = &.{},
    samplers: []const ?Sampler = &.{},
    draw: Draw,

    pub const Draw = struct {
        type: Primitive,
        vertex_count: usize,
        instance_count: usize = 1,
    };

    pub const Primitive = enum {
        triangle,
        triangle_strip,
    };
};

ctx: *com.ID3D11DeviceContext,
attachments: []const Options.Attachment,
step_number: usize = 0,

/// Begin a render pass.
pub fn begin(opts: Options) Self {
    return .{
        .ctx = opts.ctx,
        .attachments = opts.attachments,
    };
}

/// Add a step to this render pass.
pub fn step(self: *Self, s: Step) void {
    if (s.draw.instance_count == 0) return;

    const ctx = self.ctx;

    // Bind the render target. Texture attachments are only used by the
    // custom (post-process) shader pipeline which is not supported on
    // D3D11 yet.
    const rtv: *com.ID3D11RenderTargetView, const vp_w: usize, const vp_h: usize = switch (self.attachments[0].target) {
        .target => |t| .{ t.rtv, t.width, t.height },
        .texture => {
            log.warn("texture attachments unsupported on d3d11 (custom shaders)", .{});
            return;
        },
    };

    ctx.omSetRenderTargets(&.{rtv});
    ctx.rsSetViewports(&.{.{
        .TopLeftX = 0,
        .TopLeftY = 0,
        .Width = @floatFromInt(vp_w),
        .Height = @floatFromInt(vp_h),
    }});

    defer self.step_number += 1;

    // Clear on the first step if requested.
    if (self.step_number == 0) if (self.attachments[0].clear_color) |c| {
        ctx.clearRenderTargetView(rtv, &c);
    };

    // Shaders + input layout + blending.
    ctx.vsSetShader(s.pipeline.vs);
    ctx.psSetShader(s.pipeline.ps);
    ctx.iaSetInputLayout(s.pipeline.layout);
    ctx.omSetBlendState(s.pipeline.blend);
    ctx.iaSetPrimitiveTopology(switch (s.draw.type) {
        .triangle => com.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,
        .triangle_strip => com.D3D_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP,
    });

    // Uniforms at constant buffer slot 1 (matches the other backends).
    if (s.uniforms) |ubo| {
        ctx.vsSetConstantBuffers(1, &.{ubo.res});
        ctx.psSetConstantBuffers(1, &.{ubo.res});
    }

    // Buffer 0 is the vertex/instance buffer; the rest are storage
    // buffers bound as StructuredBuffer SRVs at the matching t-slot in
    // both stages. Textures are bound afterwards so they take priority
    // on the pixel stage (no current step needs both).
    if (s.buffers.len > 0) {
        if (s.buffers[0]) |vbo| {
            const strides = [1]u32{@intCast(s.pipeline.stride)};
            const offsets = [1]u32{0};
            ctx.iaSetVertexBuffers(0, &.{vbo.res}, &strides, &offsets);
        }

        for (s.buffers[1..], 1..) |b, i| if (b) |buf| {
            if (buf.srv) |srv| {
                var srvs = [1]?*com.ID3D11ShaderResourceView{srv};
                ctx.vsSetShaderResources(@intCast(i), &srvs);
                ctx.psSetShaderResources(@intCast(i), &srvs);
            }
        };
    }

    // Bind textures and samplers on the pixel stage.
    for (s.textures, 0..) |t, i| if (t) |tex| {
        var srvs = [1]?*com.ID3D11ShaderResourceView{tex.srv};
        ctx.psSetShaderResources(@intCast(i), &srvs);
    };

    for (s.samplers, 0..) |s_, i| if (s_) |sampler| {
        var samplers = [1]?*com.ID3D11SamplerState{sampler.sampler};
        ctx.psSetSamplers(@intCast(i), &samplers);
    };

    ctx.drawInstanced(
        @intCast(s.draw.vertex_count),
        @intCast(s.draw.instance_count),
        0,
        0,
    );
}

/// Complete this render pass.
pub fn complete(self: *const Self) void {
    _ = self;
}
