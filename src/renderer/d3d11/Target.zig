//! Represents a render target: an offscreen texture with a render
//! target view. Presenting copies it to the swapchain backbuffer.
const Self = @This();

const std = @import("std");
const com = @import("com.zig");

const log = std.log.scoped(.d3d11);

pub const Options = struct {
    device: *com.ID3D11Device,
    width: usize,
    height: usize,
    format: com.DXGI_FORMAT,
};

texture: *com.ID3D11Texture2D,
rtv: *com.ID3D11RenderTargetView,

width: usize,
height: usize,

pub fn init(opts: Options) !Self {
    var desc: com.D3D11_TEXTURE2D_DESC = .{
        .Width = @intCast(@max(1, opts.width)),
        .Height = @intCast(@max(1, opts.height)),
        .Format = opts.format,
        .BindFlags = com.D3D11_BIND_RENDER_TARGET | com.D3D11_BIND_SHADER_RESOURCE,
    };

    var tex: ?*com.ID3D11Texture2D = null;
    if (opts.device.createTexture2D(&desc, null, &tex) != 0 or tex == null)
        return error.D3D11Failed;
    errdefer tex.?.release();

    var rtv: ?*com.ID3D11RenderTargetView = null;
    if (opts.device.createRenderTargetView(@ptrCast(tex.?), null, &rtv) != 0 or rtv == null)
        return error.D3D11Failed;

    return .{
        .texture = tex.?,
        .rtv = rtv.?,
        .width = opts.width,
        .height = opts.height,
    };
}

pub fn deinit(self: *Self) void {
    self.rtv.release();
    self.texture.release();
}
