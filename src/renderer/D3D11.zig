//! Graphics API wrapper for Direct3D 11 (Windows).
//!
//! The renderer draws into an offscreen target texture and presenting
//! copies it to a DXGI flip-model swapchain backbuffer. Shaders are
//! HLSL compiled at startup through d3dcompiler_47 (ships with
//! Windows 10+), so there is no build-time shader toolchain.
pub const D3D11 = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const shadertoy = @import("shadertoy.zig");
const apprt = @import("../apprt.zig");
const font = @import("../font/main.zig");
const configpkg = @import("../config.zig");
const rendererpkg = @import("../renderer.zig");
const Renderer = rendererpkg.GenericRenderer(D3D11);

const com = @import("d3d11/com.zig");

pub const GraphicsAPI = D3D11;
pub const Target = @import("d3d11/Target.zig");
pub const Frame = @import("d3d11/Frame.zig");
pub const RenderPass = @import("d3d11/RenderPass.zig");
pub const Pipeline = @import("d3d11/Pipeline.zig");
const bufferpkg = @import("d3d11/buffer.zig");
pub const Buffer = bufferpkg.Buffer;
pub const Sampler = @import("d3d11/Sampler.zig");
pub const Texture = @import("d3d11/Texture.zig");
pub const shaders = @import("d3d11/shaders.zig");

pub const custom_shader_target: shadertoy.Target = .glsl;
pub const custom_shader_y_is_down = true;

/// Frame completion is synchronous (the present copies the finished
/// target), so no multi-buffering is needed.
pub const swap_chain_count = 1;

const log = std.log.scoped(.d3d11);

const RECT = extern struct { l: i32, t: i32, r: i32, b: i32 };
extern "user32" fn GetClientRect(hWnd: std.os.windows.HWND, lpRect: *RECT) callconv(.winapi) i32;

alloc: std.mem.Allocator,

/// Alpha blending mode
blending: configpkg.Config.AlphaBlending,

/// Mutable device state behind a pointer so that the const-self API
/// callbacks (finalizeSurfaceInit et al) can fill it in.
state: *State,

/// The most recently presented target, in case we need to present it again.
last_target: ?Target = null,

pub const State = struct {
    device: *com.ID3D11Device,
    ctx: *com.ID3D11DeviceContext,
    swapchain: ?*com.IDXGISwapChain1 = null,
    hwnd: ?std.os.windows.HWND = null,
    swap_width: u32 = 0,
    swap_height: u32 = 0,
};

pub const InitError = error{
    D3D11Failed,
    OutOfMemory,
};

pub fn init(alloc: Allocator, opts: rendererpkg.Options) InitError!D3D11 {
    var device: ?*com.ID3D11Device = null;
    var ctx: ?*com.ID3D11DeviceContext = null;
    const levels = [_]u32{com.D3D_FEATURE_LEVEL_11_0};
    if (com.createDevice(
        null,
        com.D3D_DRIVER_TYPE_HARDWARE,
        null,
        0,
        &levels,
        levels.len,
        com.D3D11_SDK_VERSION,
        &device,
        null,
        &ctx,
    ) != 0 or device == null or ctx == null) {
        log.err("D3D11CreateDevice failed", .{});
        return error.D3D11Failed;
    }
    errdefer {
        ctx.?.release();
        device.?.release();
    }

    const state = try alloc.create(State);
    state.* = .{
        .device = device.?,
        .ctx = ctx.?,
    };

    log.info("D3D11 device created", .{});

    return .{
        .alloc = alloc,
        .blending = opts.config.blending,
        .state = state,
    };
}

pub fn deinit(self: *D3D11) void {
    if (self.state.swapchain) |sc| sc.release();
    self.state.ctx.release();
    self.state.device.release();
    self.alloc.destroy(self.state);
    self.* = undefined;
}

/// This is called early right after surface creation.
pub fn surfaceInit(surface: *apprt.Surface) !void {
    _ = surface;

    switch (apprt.runtime) {
        apprt.win32 => {},
        else => @compileError("unsupported app runtime for D3D11"),
    }
}

/// Create the swapchain for the surface window. Called just prior to
/// spinning up the renderer thread.
pub fn finalizeSurfaceInit(self: *const D3D11, surface: *apprt.Surface) !void {
    const state = self.state;
    state.hwnd = surface.hwnd;

    var rect: RECT = undefined;
    if (GetClientRect(surface.hwnd, &rect) == 0) return error.D3D11Failed;
    const width: u32 = @intCast(@max(1, rect.r - rect.l));
    const height: u32 = @intCast(@max(1, rect.b - rect.t));

    var factory_raw: ?*anyopaque = null;
    if (com.createDXGIFactory1(&com.IID_IDXGIFactory2, &factory_raw) != 0 or factory_raw == null)
        return error.D3D11Failed;
    const factory: *com.IDXGIFactory2 = @ptrCast(@alignCast(factory_raw.?));
    defer factory.release();

    const desc: com.DXGI_SWAP_CHAIN_DESC1 = .{
        .Width = width,
        .Height = height,
        .Format = .rgba8_unorm,
        .BufferUsage = com.DXGI_USAGE_RENDER_TARGET_OUTPUT,
        .BufferCount = 2,
        .SwapEffect = com.DXGI_SWAP_EFFECT_FLIP_DISCARD,
    };

    var swapchain: ?*com.IDXGISwapChain1 = null;
    if (factory.createSwapChainForHwnd(
        @ptrCast(state.device),
        surface.hwnd,
        &desc,
        &swapchain,
    ) != 0 or swapchain == null) return error.D3D11Failed;

    state.swapchain = swapchain;
    state.swap_width = width;
    state.swap_height = height;

    log.info("D3D11 swapchain created {d}x{d}", .{ width, height });
}

/// Callback called by renderer.Thread when it begins. The D3D11
/// immediate context is used by the renderer thread only after this
/// point, so no per-thread setup is needed.
pub fn threadEnter(self: *const D3D11, surface: *apprt.Surface) !void {
    _ = self;
    _ = surface;
}

pub fn threadExit(self: *const D3D11) void {
    _ = self;
}

pub fn displayRealized(self: *const D3D11) void {
    _ = self;
}

pub fn drawFrameStart(self: *D3D11) void {
    _ = self;
}

pub fn drawFrameEnd(self: *D3D11) void {
    _ = self;
}

pub fn initShaders(
    self: *const D3D11,
    alloc: Allocator,
    custom_shaders: []const [:0]const u8,
) !shaders.Shaders {
    return try shaders.Shaders.init(
        self.state.device,
        alloc,
        custom_shaders,
    );
}

/// Get the current size of the runtime surface.
pub fn surfaceSize(self: *const D3D11) !struct { width: u32, height: u32 } {
    const hwnd = self.state.hwnd orelse return .{ .width = 1, .height = 1 };
    var rect: RECT = undefined;
    if (GetClientRect(hwnd, &rect) == 0) return .{ .width = 1, .height = 1 };
    return .{
        .width = @intCast(@max(1, rect.r - rect.l)),
        .height = @intCast(@max(1, rect.b - rect.t)),
    };
}

fn targetFormat(self: *const D3D11) com.DXGI_FORMAT {
    return if (self.blending.isLinear()) .rgba8_unorm_srgb else .rgba8_unorm;
}

pub fn initTarget(self: *const D3D11, width: usize, height: usize) !Target {
    return Target.init(.{
        .device = self.state.device,
        .width = width,
        .height = height,
        .format = self.targetFormat(),
    });
}

/// Present the provided target by copying it to the swapchain
/// backbuffer, resizing the swapchain first if it doesn't match.
pub fn present(self: *D3D11, target: Target) !void {
    const state = self.state;
    const swapchain = state.swapchain orelse return error.D3D11Failed;

    const tw: u32 = @intCast(target.width);
    const th: u32 = @intCast(target.height);
    if (tw != state.swap_width or th != state.swap_height) {
        if (swapchain.resizeBuffers(0, tw, th, .unknown, 0) != 0) {
            log.warn("swapchain resize failed {d}x{d}", .{ tw, th });
            return error.D3D11Failed;
        }
        state.swap_width = tw;
        state.swap_height = th;
    }

    var back_raw: ?*anyopaque = null;
    if (swapchain.getBuffer(0, &com.IID_ID3D11Texture2D, &back_raw) != 0 or back_raw == null)
        return error.D3D11Failed;
    const backbuffer: *com.ID3D11Texture2D = @ptrCast(@alignCast(back_raw.?));
    defer backbuffer.release();

    state.ctx.copyResource(@ptrCast(backbuffer), @ptrCast(target.texture));

    if (swapchain.present(0, 0) != 0) return error.D3D11Failed;

    self.last_target = target;
}

/// Present the last presented target again.
pub fn presentLastTarget(self: *D3D11) !void {
    if (self.last_target) |target| try self.present(target);
}

/// Begin a frame.
pub inline fn beginFrame(
    self: *const D3D11,
    renderer: *Renderer,
    target: *Target,
) !Frame {
    _ = self;
    return try Frame.begin(.{}, renderer, target);
}

pub inline fn bufferOptions(self: D3D11, role: bufferpkg.Role) bufferpkg.Options {
    return .{
        .device = self.state.device,
        .ctx = self.state.ctx,
        .role = role,
    };
}

pub inline fn instanceBufferOptions(self: D3D11) bufferpkg.Options {
    return self.bufferOptions(.vertex);
}

pub inline fn uniformBufferOptions(self: D3D11) bufferpkg.Options {
    return self.bufferOptions(.uniform);
}

pub inline fn fgBufferOptions(self: D3D11) bufferpkg.Options {
    return self.bufferOptions(.vertex);
}

pub inline fn bgBufferOptions(self: D3D11) bufferpkg.Options {
    return self.bufferOptions(.storage);
}

pub inline fn imageBufferOptions(self: D3D11) bufferpkg.Options {
    return self.bufferOptions(.vertex);
}

pub inline fn bgImageBufferOptions(self: D3D11) bufferpkg.Options {
    return self.bufferOptions(.vertex);
}

/// Returns the options to use when constructing textures.
pub inline fn textureOptions(self: D3D11) Texture.Options {
    return .{
        .device = self.state.device,
        .ctx = self.state.ctx,
        .format = self.targetFormat(),
    };
}

/// Returns the options to use when constructing samplers.
pub inline fn samplerOptions(self: D3D11) Sampler.Options {
    return .{ .device = self.state.device };
}

/// Pixel format for image texture options.
pub const ImageTextureFormat = enum {
    /// 1 byte per pixel grayscale.
    gray,
    /// 4 bytes per pixel RGBA.
    rgba,
    /// 4 bytes per pixel BGRA.
    bgra,
};

/// Returns the options to use when constructing textures for images.
pub inline fn imageTextureOptions(
    self: D3D11,
    format: ImageTextureFormat,
    srgb: bool,
) Texture.Options {
    return .{
        .device = self.state.device,
        .ctx = self.state.ctx,
        .format = switch (format) {
            .gray => .r8_unorm,
            .rgba => if (srgb) .rgba8_unorm_srgb else .rgba8_unorm,
            .bgra => if (srgb) .bgra8_unorm_srgb else .bgra8_unorm,
        },
    };
}

/// Initializes a Texture suitable for the provided font atlas.
pub fn initAtlasTexture(
    self: *const D3D11,
    atlas: *const font.Atlas,
) Texture.Error!Texture {
    const format: com.DXGI_FORMAT = switch (atlas.format) {
        .grayscale => .r8_unorm,
        .bgra => .bgra8_unorm_srgb,
        else => @panic("unsupported atlas format for D3D11 texture"),
    };

    return try Texture.init(
        .{
            .device = self.state.device,
            .ctx = self.state.ctx,
            .format = format,
        },
        atlas.size,
        atlas.size,
        atlas.data,
    );
}
