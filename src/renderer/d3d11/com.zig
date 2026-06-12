//! Minimal hand-written COM bindings for D3D11 / DXGI / D3DCompiler.
//! Same slot-cast approach as the DirectWrite font discovery: interfaces
//! are a single vtable pointer and methods are invoked by casting the
//! documented vtable slot. No C++ involved.
const std = @import("std");

pub const HRESULT = i32;
pub const BOOL = i32;
pub const HWND = std.os.windows.HWND;

pub const GUID = extern struct {
    d1: u32,
    d2: u16,
    d3: u16,
    d4: [8]u8,
};

pub fn comSlot(obj: anytype, comptime F: type, comptime index: usize) F {
    const com: *const extern struct { vtable: [*]const *const anyopaque } = @ptrCast(@alignCast(obj));
    return @ptrCast(@alignCast(com.vtable[index]));
}

pub fn comRelease(obj: anytype) void {
    const F = *const fn (@TypeOf(obj)) callconv(.winapi) u32;
    _ = comSlot(obj, F, 2)(obj);
}

// {6f15aaf2-d208-4e89-9ab4-489535d34f9c}
pub const IID_ID3D11Texture2D: GUID = .{
    .d1 = 0x6f15aaf2,
    .d2 = 0xd208,
    .d3 = 0x4e89,
    .d4 = .{ 0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c },
};

// {50c83a1c-e072-4c48-87b0-3630fa36a6d0}
pub const IID_IDXGIFactory2: GUID = .{
    .d1 = 0x50c83a1c,
    .d2 = 0xe072,
    .d3 = 0x4c48,
    .d4 = .{ 0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0 },
};

pub const D3D11_SDK_VERSION: u32 = 7;
pub const D3D_DRIVER_TYPE_HARDWARE: u32 = 1;
pub const D3D_FEATURE_LEVEL_11_0: u32 = 0xb000;

pub const DXGI_FORMAT = enum(u32) {
    unknown = 0,
    rgba32_float = 2,
    rgba32_uint = 3,
    rg32_float = 16,
    rg32_uint = 17,
    rg32_sint = 18,
    rgba8_unorm = 28,
    rgba8_unorm_srgb = 29,
    rgba8_uint = 30,
    rg16_uint = 36,
    rg16_sint = 38,
    r32_float = 41,
    r32_uint = 42,
    r16_uint = 57,
    r8_unorm = 61,
    r8_uint = 62,
    bgra8_unorm = 87,
    bgra8_unorm_srgb = 91,
    _,
};

pub const DXGI_SWAP_CHAIN_DESC1 = extern struct {
    Width: u32,
    Height: u32,
    Format: DXGI_FORMAT,
    Stereo: BOOL = 0,
    SampleDesc: extern struct { Count: u32 = 1, Quality: u32 = 0 } = .{},
    BufferUsage: u32, // DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20
    BufferCount: u32,
    Scaling: u32 = 0, // DXGI_SCALING_STRETCH
    SwapEffect: u32, // DXGI_SWAP_EFFECT_FLIP_DISCARD = 4
    AlphaMode: u32 = 0,
    Flags: u32 = 0,
};

pub const DXGI_USAGE_RENDER_TARGET_OUTPUT: u32 = 0x20;
pub const DXGI_SWAP_EFFECT_FLIP_DISCARD: u32 = 4;

pub const D3D11_USAGE_DEFAULT: u32 = 0;
pub const D3D11_USAGE_DYNAMIC: u32 = 2;
pub const D3D11_BIND_VERTEX_BUFFER: u32 = 0x1;
pub const D3D11_BIND_CONSTANT_BUFFER: u32 = 0x4;
pub const D3D11_BIND_SHADER_RESOURCE: u32 = 0x8;
pub const D3D11_BIND_RENDER_TARGET: u32 = 0x20;
pub const D3D11_CPU_ACCESS_WRITE: u32 = 0x10000;
pub const D3D11_RESOURCE_MISC_BUFFER_STRUCTURED: u32 = 0x40;
pub const D3D11_MAP_WRITE_DISCARD: u32 = 4;

pub const D3D11_BUFFER_DESC = extern struct {
    ByteWidth: u32,
    Usage: u32,
    BindFlags: u32,
    CPUAccessFlags: u32 = 0,
    MiscFlags: u32 = 0,
    StructureByteStride: u32 = 0,
};

pub const D3D11_SUBRESOURCE_DATA = extern struct {
    pSysMem: ?*const anyopaque,
    SysMemPitch: u32 = 0,
    SysMemSlicePitch: u32 = 0,
};

pub const D3D11_TEXTURE2D_DESC = extern struct {
    Width: u32,
    Height: u32,
    MipLevels: u32 = 1,
    ArraySize: u32 = 1,
    Format: DXGI_FORMAT,
    SampleDesc: extern struct { Count: u32 = 1, Quality: u32 = 0 } = .{},
    Usage: u32 = D3D11_USAGE_DEFAULT,
    BindFlags: u32,
    CPUAccessFlags: u32 = 0,
    MiscFlags: u32 = 0,
};

pub const D3D11_SHADER_RESOURCE_VIEW_DESC = extern struct {
    Format: DXGI_FORMAT,
    ViewDimension: u32, // D3D11_SRV_DIMENSION_BUFFER = 1, TEXTURE2D = 4
    u: extern union {
        Buffer: extern struct {
            FirstElement: u32,
            NumElements: u32,
        },
        Texture2D: extern struct {
            MostDetailedMip: u32,
            MipLevels: u32,
        },
    },
};

pub const D3D11_SRV_DIMENSION_BUFFER: u32 = 1;
pub const D3D11_SRV_DIMENSION_TEXTURE2D: u32 = 4;

pub const D3D11_SAMPLER_DESC = extern struct {
    Filter: u32, // MIN_MAG_MIP_LINEAR = 0x15, POINT = 0
    AddressU: u32, // CLAMP = 3, WRAP = 1
    AddressV: u32,
    AddressW: u32 = 3,
    MipLODBias: f32 = 0,
    MaxAnisotropy: u32 = 1,
    ComparisonFunc: u32 = 1, // NEVER
    BorderColor: [4]f32 = .{ 0, 0, 0, 0 },
    MinLOD: f32 = 0,
    MaxLOD: f32 = std.math.floatMax(f32),
};

pub const D3D11_FILTER_MIN_MAG_MIP_LINEAR: u32 = 0x15;
pub const D3D11_TEXTURE_ADDRESS_WRAP: u32 = 1;
pub const D3D11_TEXTURE_ADDRESS_CLAMP: u32 = 3;

pub const D3D11_RENDER_TARGET_BLEND_DESC = extern struct {
    BlendEnable: BOOL,
    SrcBlend: u32, // ONE = 2
    DestBlend: u32, // INV_SRC_ALPHA = 6
    BlendOp: u32, // ADD = 1
    SrcBlendAlpha: u32,
    DestBlendAlpha: u32,
    BlendOpAlpha: u32,
    RenderTargetWriteMask: u8, // ALL = 0x0F
};

pub const D3D11_BLEND_DESC = extern struct {
    AlphaToCoverageEnable: BOOL = 0,
    IndependentBlendEnable: BOOL = 0,
    RenderTarget: [8]D3D11_RENDER_TARGET_BLEND_DESC,
};

pub const D3D11_BLEND_ONE: u32 = 2;
pub const D3D11_BLEND_INV_SRC_ALPHA: u32 = 6;
pub const D3D11_BLEND_OP_ADD: u32 = 1;

pub const D3D11_INPUT_ELEMENT_DESC = extern struct {
    SemanticName: [*:0]const u8,
    SemanticIndex: u32,
    Format: DXGI_FORMAT,
    InputSlot: u32 = 0,
    AlignedByteOffset: u32,
    InputSlotClass: u32, // PER_VERTEX = 0, PER_INSTANCE = 1
    InstanceDataStepRate: u32,
};

pub const D3D11_VIEWPORT = extern struct {
    TopLeftX: f32,
    TopLeftY: f32,
    Width: f32,
    Height: f32,
    MinDepth: f32 = 0,
    MaxDepth: f32 = 1,
};

pub const D3D11_MAPPED_SUBRESOURCE = extern struct {
    pData: ?*anyopaque,
    RowPitch: u32,
    DepthPitch: u32,
};

pub const D3D11_BOX = extern struct {
    left: u32,
    top: u32,
    front: u32 = 0,
    right: u32,
    bottom: u32,
    back: u32 = 1,
};

pub const D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST: u32 = 4;
pub const D3D_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP: u32 = 5;

extern "d3d11" fn D3D11CreateDevice(
    pAdapter: ?*anyopaque,
    DriverType: u32,
    Software: ?*anyopaque,
    Flags: u32,
    pFeatureLevels: ?[*]const u32,
    FeatureLevels: u32,
    SDKVersion: u32,
    ppDevice: *?*ID3D11Device,
    pFeatureLevel: ?*u32,
    ppImmediateContext: *?*ID3D11DeviceContext,
) callconv(.winapi) HRESULT;

pub const createDevice = D3D11CreateDevice;

extern "dxgi" fn CreateDXGIFactory1(
    riid: *const GUID,
    ppFactory: *?*anyopaque,
) callconv(.winapi) HRESULT;

pub const createDXGIFactory1 = CreateDXGIFactory1;

extern "d3dcompiler_47" fn D3DCompile(
    pSrcData: [*]const u8,
    SrcDataSize: usize,
    pSourceName: ?[*:0]const u8,
    pDefines: ?*const anyopaque,
    pInclude: ?*anyopaque,
    pEntrypoint: [*:0]const u8,
    pTarget: [*:0]const u8,
    Flags1: u32,
    Flags2: u32,
    ppCode: *?*ID3DBlob,
    ppErrorMsgs: ?*?*ID3DBlob,
) callconv(.winapi) HRESULT;

pub const compile = D3DCompile;

pub const ID3DBlob = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getBufferPointer(self: *ID3DBlob) [*]const u8 {
        const F = *const fn (*ID3DBlob) callconv(.winapi) [*]const u8;
        return comSlot(self, F, 3)(self);
    }

    pub fn getBufferSize(self: *ID3DBlob) usize {
        const F = *const fn (*ID3DBlob) callconv(.winapi) usize;
        return comSlot(self, F, 4)(self);
    }
};

pub const ID3D11Device = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn createBuffer(
        self: *ID3D11Device,
        desc: *const D3D11_BUFFER_DESC,
        initial: ?*const D3D11_SUBRESOURCE_DATA,
        out: *?*ID3D11Buffer,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, *const D3D11_BUFFER_DESC, ?*const D3D11_SUBRESOURCE_DATA, *?*ID3D11Buffer) callconv(.winapi) HRESULT;
        return comSlot(self, F, 3)(self, desc, initial, out);
    }

    pub fn createTexture2D(
        self: *ID3D11Device,
        desc: *const D3D11_TEXTURE2D_DESC,
        initial: ?*const D3D11_SUBRESOURCE_DATA,
        out: *?*ID3D11Texture2D,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, *const D3D11_TEXTURE2D_DESC, ?*const D3D11_SUBRESOURCE_DATA, *?*ID3D11Texture2D) callconv(.winapi) HRESULT;
        return comSlot(self, F, 5)(self, desc, initial, out);
    }

    pub fn createShaderResourceView(
        self: *ID3D11Device,
        resource: *anyopaque,
        desc: ?*const D3D11_SHADER_RESOURCE_VIEW_DESC,
        out: *?*ID3D11ShaderResourceView,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, *anyopaque, ?*const D3D11_SHADER_RESOURCE_VIEW_DESC, *?*ID3D11ShaderResourceView) callconv(.winapi) HRESULT;
        return comSlot(self, F, 7)(self, resource, desc, out);
    }

    pub fn createRenderTargetView(
        self: *ID3D11Device,
        resource: *anyopaque,
        desc: ?*const anyopaque,
        out: *?*ID3D11RenderTargetView,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, *anyopaque, ?*const anyopaque, *?*ID3D11RenderTargetView) callconv(.winapi) HRESULT;
        return comSlot(self, F, 9)(self, resource, desc, out);
    }

    pub fn createInputLayout(
        self: *ID3D11Device,
        descs: [*]const D3D11_INPUT_ELEMENT_DESC,
        count: u32,
        bytecode: [*]const u8,
        bytecode_len: usize,
        out: *?*ID3D11InputLayout,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, [*]const D3D11_INPUT_ELEMENT_DESC, u32, [*]const u8, usize, *?*ID3D11InputLayout) callconv(.winapi) HRESULT;
        return comSlot(self, F, 11)(self, descs, count, bytecode, bytecode_len, out);
    }

    pub fn createVertexShader(
        self: *ID3D11Device,
        bytecode: [*]const u8,
        len: usize,
        linkage: ?*anyopaque,
        out: *?*ID3D11VertexShader,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, [*]const u8, usize, ?*anyopaque, *?*ID3D11VertexShader) callconv(.winapi) HRESULT;
        return comSlot(self, F, 12)(self, bytecode, len, linkage, out);
    }

    pub fn createPixelShader(
        self: *ID3D11Device,
        bytecode: [*]const u8,
        len: usize,
        linkage: ?*anyopaque,
        out: *?*ID3D11PixelShader,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, [*]const u8, usize, ?*anyopaque, *?*ID3D11PixelShader) callconv(.winapi) HRESULT;
        return comSlot(self, F, 15)(self, bytecode, len, linkage, out);
    }

    pub fn createBlendState(
        self: *ID3D11Device,
        desc: *const D3D11_BLEND_DESC,
        out: *?*ID3D11BlendState,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, *const D3D11_BLEND_DESC, *?*ID3D11BlendState) callconv(.winapi) HRESULT;
        return comSlot(self, F, 20)(self, desc, out);
    }

    pub fn createSamplerState(
        self: *ID3D11Device,
        desc: *const D3D11_SAMPLER_DESC,
        out: *?*ID3D11SamplerState,
    ) HRESULT {
        const F = *const fn (*ID3D11Device, *const D3D11_SAMPLER_DESC, *?*ID3D11SamplerState) callconv(.winapi) HRESULT;
        return comSlot(self, F, 23)(self, desc, out);
    }
};

/// ID3D11DeviceContext vtable slots, after IUnknown (0-2) and
/// ID3D11DeviceChild (3-6).
pub const ID3D11DeviceContext = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn vsSetConstantBuffers(self: *ID3D11DeviceContext, start: u32, bufs: []const ?*ID3D11Buffer) void {
        const F = *const fn (*ID3D11DeviceContext, u32, u32, [*]const ?*ID3D11Buffer) callconv(.winapi) void;
        comSlot(self, F, 7)(self, start, @intCast(bufs.len), bufs.ptr);
    }

    pub fn psSetShaderResources(self: *ID3D11DeviceContext, start: u32, srvs: []const ?*ID3D11ShaderResourceView) void {
        const F = *const fn (*ID3D11DeviceContext, u32, u32, [*]const ?*ID3D11ShaderResourceView) callconv(.winapi) void;
        comSlot(self, F, 8)(self, start, @intCast(srvs.len), srvs.ptr);
    }

    pub fn psSetShader(self: *ID3D11DeviceContext, shader: ?*ID3D11PixelShader) void {
        const F = *const fn (*ID3D11DeviceContext, ?*ID3D11PixelShader, ?*anyopaque, u32) callconv(.winapi) void;
        comSlot(self, F, 9)(self, shader, null, 0);
    }

    pub fn psSetSamplers(self: *ID3D11DeviceContext, start: u32, samplers: []const ?*ID3D11SamplerState) void {
        const F = *const fn (*ID3D11DeviceContext, u32, u32, [*]const ?*ID3D11SamplerState) callconv(.winapi) void;
        comSlot(self, F, 10)(self, start, @intCast(samplers.len), samplers.ptr);
    }

    pub fn vsSetShader(self: *ID3D11DeviceContext, shader: ?*ID3D11VertexShader) void {
        const F = *const fn (*ID3D11DeviceContext, ?*ID3D11VertexShader, ?*anyopaque, u32) callconv(.winapi) void;
        comSlot(self, F, 11)(self, shader, null, 0);
    }

    pub fn map(
        self: *ID3D11DeviceContext,
        resource: *anyopaque,
        subresource: u32,
        map_type: u32,
        mapped: *D3D11_MAPPED_SUBRESOURCE,
    ) HRESULT {
        const F = *const fn (*ID3D11DeviceContext, *anyopaque, u32, u32, u32, *D3D11_MAPPED_SUBRESOURCE) callconv(.winapi) HRESULT;
        return comSlot(self, F, 14)(self, resource, subresource, map_type, 0, mapped);
    }

    pub fn unmap(self: *ID3D11DeviceContext, resource: *anyopaque, subresource: u32) void {
        const F = *const fn (*ID3D11DeviceContext, *anyopaque, u32) callconv(.winapi) void;
        comSlot(self, F, 15)(self, resource, subresource);
    }

    pub fn psSetConstantBuffers(self: *ID3D11DeviceContext, start: u32, bufs: []const ?*ID3D11Buffer) void {
        const F = *const fn (*ID3D11DeviceContext, u32, u32, [*]const ?*ID3D11Buffer) callconv(.winapi) void;
        comSlot(self, F, 16)(self, start, @intCast(bufs.len), bufs.ptr);
    }

    pub fn iaSetInputLayout(self: *ID3D11DeviceContext, layout: ?*ID3D11InputLayout) void {
        const F = *const fn (*ID3D11DeviceContext, ?*ID3D11InputLayout) callconv(.winapi) void;
        comSlot(self, F, 17)(self, layout);
    }

    pub fn iaSetVertexBuffers(
        self: *ID3D11DeviceContext,
        start: u32,
        bufs: []const ?*ID3D11Buffer,
        strides: [*]const u32,
        offsets: [*]const u32,
    ) void {
        const F = *const fn (*ID3D11DeviceContext, u32, u32, [*]const ?*ID3D11Buffer, [*]const u32, [*]const u32) callconv(.winapi) void;
        comSlot(self, F, 18)(self, start, @intCast(bufs.len), bufs.ptr, strides, offsets);
    }

    pub fn drawInstanced(
        self: *ID3D11DeviceContext,
        vertex_count: u32,
        instance_count: u32,
        start_vertex: u32,
        start_instance: u32,
    ) void {
        const F = *const fn (*ID3D11DeviceContext, u32, u32, u32, u32) callconv(.winapi) void;
        comSlot(self, F, 21)(self, vertex_count, instance_count, start_vertex, start_instance);
    }

    pub fn iaSetPrimitiveTopology(self: *ID3D11DeviceContext, topology: u32) void {
        const F = *const fn (*ID3D11DeviceContext, u32) callconv(.winapi) void;
        comSlot(self, F, 24)(self, topology);
    }

    pub fn vsSetShaderResources(self: *ID3D11DeviceContext, start: u32, srvs: []const ?*ID3D11ShaderResourceView) void {
        const F = *const fn (*ID3D11DeviceContext, u32, u32, [*]const ?*ID3D11ShaderResourceView) callconv(.winapi) void;
        comSlot(self, F, 25)(self, start, @intCast(srvs.len), srvs.ptr);
    }

    pub fn omSetRenderTargets(self: *ID3D11DeviceContext, rtvs: []const ?*ID3D11RenderTargetView) void {
        const F = *const fn (*ID3D11DeviceContext, u32, [*]const ?*ID3D11RenderTargetView, ?*anyopaque) callconv(.winapi) void;
        comSlot(self, F, 33)(self, @intCast(rtvs.len), rtvs.ptr, null);
    }

    pub fn omSetBlendState(self: *ID3D11DeviceContext, state: ?*ID3D11BlendState) void {
        const F = *const fn (*ID3D11DeviceContext, ?*ID3D11BlendState, ?*const [4]f32, u32) callconv(.winapi) void;
        comSlot(self, F, 35)(self, state, null, 0xFFFFFFFF);
    }

    pub fn rsSetViewports(self: *ID3D11DeviceContext, viewports: []const D3D11_VIEWPORT) void {
        const F = *const fn (*ID3D11DeviceContext, u32, [*]const D3D11_VIEWPORT) callconv(.winapi) void;
        comSlot(self, F, 44)(self, @intCast(viewports.len), viewports.ptr);
    }

    pub fn copyResource(self: *ID3D11DeviceContext, dst: *anyopaque, src: *anyopaque) void {
        const F = *const fn (*ID3D11DeviceContext, *anyopaque, *anyopaque) callconv(.winapi) void;
        comSlot(self, F, 47)(self, dst, src);
    }

    pub fn updateSubresource(
        self: *ID3D11DeviceContext,
        dst: *anyopaque,
        subresource: u32,
        box: ?*const D3D11_BOX,
        data: *const anyopaque,
        row_pitch: u32,
        depth_pitch: u32,
    ) void {
        const F = *const fn (*ID3D11DeviceContext, *anyopaque, u32, ?*const D3D11_BOX, *const anyopaque, u32, u32) callconv(.winapi) void;
        comSlot(self, F, 48)(self, dst, subresource, box, data, row_pitch, depth_pitch);
    }

    pub fn clearRenderTargetView(self: *ID3D11DeviceContext, rtv: *ID3D11RenderTargetView, color: *const [4]f32) void {
        const F = *const fn (*ID3D11DeviceContext, *ID3D11RenderTargetView, *const [4]f32) callconv(.winapi) void;
        comSlot(self, F, 50)(self, rtv, color);
    }
};

pub const IDXGIFactory2 = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn createSwapChainForHwnd(
        self: *IDXGIFactory2,
        device: *anyopaque,
        hwnd: HWND,
        desc: *const DXGI_SWAP_CHAIN_DESC1,
        out: *?*IDXGISwapChain1,
    ) HRESULT {
        const F = *const fn (*IDXGIFactory2, *anyopaque, HWND, *const DXGI_SWAP_CHAIN_DESC1, ?*const anyopaque, ?*anyopaque, *?*IDXGISwapChain1) callconv(.winapi) HRESULT;
        return comSlot(self, F, 15)(self, device, hwnd, desc, null, null, out);
    }
};

pub const IDXGISwapChain1 = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn present(self: *IDXGISwapChain1, sync_interval: u32, flags: u32) HRESULT {
        const F = *const fn (*IDXGISwapChain1, u32, u32) callconv(.winapi) HRESULT;
        return comSlot(self, F, 8)(self, sync_interval, flags);
    }

    pub fn getBuffer(self: *IDXGISwapChain1, index: u32, iid: *const GUID, out: *?*anyopaque) HRESULT {
        const F = *const fn (*IDXGISwapChain1, u32, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT;
        return comSlot(self, F, 9)(self, index, iid, out);
    }

    pub fn resizeBuffers(self: *IDXGISwapChain1, count: u32, width: u32, height: u32, format: DXGI_FORMAT, flags: u32) HRESULT {
        const F = *const fn (*IDXGISwapChain1, u32, u32, u32, DXGI_FORMAT, u32) callconv(.winapi) HRESULT;
        return comSlot(self, F, 13)(self, count, width, height, format, flags);
    }
};

// Opaque resource interfaces — only ever released or passed through.
pub const ID3D11Buffer = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11Texture2D = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11ShaderResourceView = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11RenderTargetView = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11InputLayout = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11VertexShader = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11PixelShader = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11BlendState = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
pub const ID3D11SamplerState = extern struct {
    vtable: [*]const *const anyopaque,
    pub fn release(self: *@This()) void {
        comRelease(self);
    }
};
