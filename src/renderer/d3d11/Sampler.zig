//! Wrapper for handling samplers.
const Self = @This();

const com = @import("com.zig");

pub const Options = struct {
    device: *com.ID3D11Device,
};

sampler: *com.ID3D11SamplerState,

pub fn init(opts: Options) !Self {
    const desc: com.D3D11_SAMPLER_DESC = .{
        .Filter = com.D3D11_FILTER_MIN_MAG_MIP_LINEAR,
        .AddressU = com.D3D11_TEXTURE_ADDRESS_CLAMP,
        .AddressV = com.D3D11_TEXTURE_ADDRESS_CLAMP,
    };
    var sampler: ?*com.ID3D11SamplerState = null;
    if (opts.device.createSamplerState(&desc, &sampler) != 0 or sampler == null)
        return error.D3D11Failed;
    return .{ .sampler = sampler.? };
}

pub fn deinit(self: Self) void {
    self.sampler.release();
}
