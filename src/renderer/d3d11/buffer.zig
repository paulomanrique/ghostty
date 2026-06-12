const std = @import("std");
const com = @import("com.zig");

const log = std.log.scoped(.d3d11);

/// What a buffer is used for; decides bind flags and whether we create
/// a shader resource view (StructuredBuffer in HLSL).
pub const Role = enum {
    vertex,
    uniform,
    storage,
};

pub const Options = struct {
    device: *com.ID3D11Device,
    ctx: *com.ID3D11DeviceContext,
    role: Role,
};

/// The handle passed around in render pass steps: the raw buffer plus
/// the SRV when this is a storage buffer.
pub const Handle = struct {
    res: *com.ID3D11Buffer,
    srv: ?*com.ID3D11ShaderResourceView,
};

/// D3D11 data storage for a set of equal types, mirroring the OpenGL
/// backend's buffer wrapper: preallocate, grow, and sync.
pub fn Buffer(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Handle bundle (buffer + optional SRV) passed to steps.
        buffer: Handle,

        opts: Options,

        /// Current allocated length in number of `T`s.
        len: usize,

        pub fn init(opts: Options, len: usize) !Self {
            const handle = try create(opts, @max(1, len));
            return .{
                .buffer = handle,
                .opts = opts,
                .len = @max(1, len),
            };
        }

        pub fn initFill(opts: Options, data: []const T) !Self {
            var self = try init(opts, data.len);
            errdefer self.deinit();
            try self.sync(data);
            return self;
        }

        pub fn deinit(self: Self) void {
            if (self.buffer.srv) |srv| srv.release();
            self.buffer.res.release();
        }

        fn create(opts: Options, len: usize) !Handle {
            // Uniform (constant) buffer sizes must be 16-byte multiples.
            const elem_size = @sizeOf(T);
            var byte_width: u32 = @intCast(len * elem_size);
            if (opts.role == .uniform) byte_width = (byte_width + 15) & ~@as(u32, 15);

            const desc: com.D3D11_BUFFER_DESC = .{
                .ByteWidth = byte_width,
                .Usage = com.D3D11_USAGE_DYNAMIC,
                .BindFlags = switch (opts.role) {
                    .vertex => com.D3D11_BIND_VERTEX_BUFFER,
                    .uniform => com.D3D11_BIND_CONSTANT_BUFFER,
                    .storage => com.D3D11_BIND_SHADER_RESOURCE,
                },
                .CPUAccessFlags = com.D3D11_CPU_ACCESS_WRITE,
                .MiscFlags = switch (opts.role) {
                    .storage => com.D3D11_RESOURCE_MISC_BUFFER_STRUCTURED,
                    else => 0,
                },
                .StructureByteStride = switch (opts.role) {
                    .storage => @intCast(elem_size),
                    else => 0,
                },
            };

            var buf: ?*com.ID3D11Buffer = null;
            if (opts.device.createBuffer(&desc, null, &buf) != 0 or buf == null)
                return error.D3D11Failed;
            errdefer buf.?.release();

            var srv: ?*com.ID3D11ShaderResourceView = null;
            if (opts.role == .storage) {
                var srv_desc: com.D3D11_SHADER_RESOURCE_VIEW_DESC = .{
                    .Format = .unknown,
                    .ViewDimension = com.D3D11_SRV_DIMENSION_BUFFER,
                    .u = .{ .Buffer = .{
                        .FirstElement = 0,
                        .NumElements = @intCast(len),
                    } },
                };
                if (opts.device.createShaderResourceView(@ptrCast(buf.?), &srv_desc, &srv) != 0 or srv == null)
                    return error.D3D11Failed;
            }

            return .{ .res = buf.?, .srv = srv };
        }

        fn mapWrite(self: *Self) ![*]T {
            var mapped: com.D3D11_MAPPED_SUBRESOURCE = undefined;
            if (self.opts.ctx.map(
                @ptrCast(self.buffer.res),
                0,
                com.D3D11_MAP_WRITE_DISCARD,
                &mapped,
            ) != 0) return error.D3D11Failed;
            return @ptrCast(@alignCast(mapped.pData.?));
        }

        fn ensureCapacity(self: *Self, total: usize) !void {
            if (total <= self.len) return;
            const new_handle = try create(self.opts, total * 2);
            if (self.buffer.srv) |srv| srv.release();
            self.buffer.res.release();
            self.buffer = new_handle;
            self.len = total * 2;
        }

        /// Sync new contents to the buffer, growing it if needed.
        pub fn sync(self: *Self, data: []const T) !void {
            try self.ensureCapacity(data.len);
            const dst = try self.mapWrite();
            defer self.opts.ctx.unmap(@ptrCast(self.buffer.res), 0);
            if (data.len > 0) @memcpy(dst[0..data.len], data);
        }

        /// Like sync but takes data from an array of ArrayLists.
        /// Returns the number of items synced.
        pub fn syncFromArrayLists(
            self: *Self,
            lists: []const std.ArrayListUnmanaged(T),
        ) !usize {
            var total: usize = 0;
            for (lists) |list| total += list.items.len;
            try self.ensureCapacity(total);

            const dst = try self.mapWrite();
            defer self.opts.ctx.unmap(@ptrCast(self.buffer.res), 0);
            var i: usize = 0;
            for (lists) |list| {
                if (list.items.len == 0) continue;
                @memcpy(dst[i..][0..list.items.len], list.items);
                i += list.items.len;
            }

            return total;
        }
    };
}
