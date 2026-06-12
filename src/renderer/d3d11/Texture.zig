//! Wrapper for handling textures (ID3D11Texture2D + SRV).
const Self = @This();

const std = @import("std");
const com = @import("com.zig");

const log = std.log.scoped(.d3d11);

/// Options for initializing a texture. The device handles are embedded
/// here by the API's *Options() helpers since texture constructors are
/// called by the generic renderer without access to the API.
pub const Options = struct {
    device: *com.ID3D11Device,
    ctx: *com.ID3D11DeviceContext,
    format: com.DXGI_FORMAT,
};

texture: *com.ID3D11Texture2D,
srv: *com.ID3D11ShaderResourceView,
ctx: *com.ID3D11DeviceContext,

/// The width/height of this texture.
width: usize,
height: usize,

/// Bytes per pixel for the format, used for region updates.
bpp: usize,

pub const Error = error{D3D11Failed};

fn bytesPerPixel(format: com.DXGI_FORMAT) usize {
    return switch (format) {
        .r8_unorm => 1,
        else => 4,
    };
}

pub fn init(
    opts: Options,
    width: usize,
    height: usize,
    data: ?[]const u8,
) Error!Self {
    const bpp = bytesPerPixel(opts.format);

    var desc: com.D3D11_TEXTURE2D_DESC = .{
        .Width = @intCast(@max(1, width)),
        .Height = @intCast(@max(1, height)),
        .Format = opts.format,
        .BindFlags = com.D3D11_BIND_SHADER_RESOURCE,
    };

    var initial: com.D3D11_SUBRESOURCE_DATA = .{
        .pSysMem = if (data) |d| d.ptr else null,
        .SysMemPitch = @intCast(width * bpp),
    };

    var tex: ?*com.ID3D11Texture2D = null;
    if (opts.device.createTexture2D(
        &desc,
        if (data != null) &initial else null,
        &tex,
    ) != 0 or tex == null) return error.D3D11Failed;
    errdefer tex.?.release();

    var srv: ?*com.ID3D11ShaderResourceView = null;
    if (opts.device.createShaderResourceView(@ptrCast(tex.?), null, &srv) != 0 or srv == null)
        return error.D3D11Failed;

    return .{
        .texture = tex.?,
        .srv = srv.?,
        .ctx = opts.ctx,
        .width = width,
        .height = height,
        .bpp = bpp,
    };
}

pub fn deinit(self: Self) void {
    self.srv.release();
    self.texture.release();
}

/// Replace a region of the texture with the provided data.
pub fn replaceRegion(
    self: Self,
    x: usize,
    y: usize,
    width: usize,
    height: usize,
    data: []const u8,
) Error!void {
    if (width == 0 or height == 0) return;
    const box: com.D3D11_BOX = .{
        .left = @intCast(x),
        .top = @intCast(y),
        .right = @intCast(x + width),
        .bottom = @intCast(y + height),
    };
    self.ctx.updateSubresource(
        @ptrCast(self.texture),
        0,
        &box,
        data.ptr,
        @intCast(width * self.bpp),
        0,
    );
}
