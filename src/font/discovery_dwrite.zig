//! DirectWrite-based font discovery for Windows. Rasterization stays on
//! FreeType: discovery resolves a family/style request to a font file
//! path + face index through the system font collection.
//!
//! COM interfaces are called through hand-written vtable slot casts so
//! no C++ is involved; only documented, stable DirectWrite (dwrite.dll)
//! interfaces are used.
const std = @import("std");
const Allocator = std.mem.Allocator;

const font = @import("main.zig");
const Collection = @import("main.zig").Collection;
const DeferredFace = @import("main.zig").DeferredFace;
const Descriptor = @import("discovery.zig").Descriptor;

const log = std.log.scoped(.discovery);

const HRESULT = i32;
const BOOL = i32;

const GUID = extern struct {
    d1: u32,
    d2: u16,
    d3: u16,
    d4: [8]u8,
};

const IID_IDWriteFactory: GUID = .{
    .d1 = 0xb859ee5a,
    .d2 = 0xd838,
    .d3 = 0x4b5b,
    .d4 = .{ 0xa2, 0xe8, 0x1a, 0xdc, 0x7d, 0x93, 0xdb, 0x48 },
};

const IID_IDWriteLocalFontFileLoader: GUID = .{
    .d1 = 0xb2d9f3ec,
    .d2 = 0xc9fe,
    .d3 = 0x4a11,
    .d4 = .{ 0xa2, 0xec, 0xd8, 0x62, 0x08, 0xf7, 0xc0, 0xa2 },
};

const DWRITE_FACTORY_TYPE_SHARED: u32 = 0;

// DWRITE_FONT_WEIGHT / STRETCH / STYLE values we use.
const WEIGHT_REGULAR: u32 = 400;
const WEIGHT_BOLD: u32 = 700;
const STRETCH_NORMAL: u32 = 5;
const STYLE_NORMAL: u32 = 0;
const STYLE_ITALIC: u32 = 2;

extern "dwrite" fn DWriteCreateFactory(
    factoryType: u32,
    iid: *const GUID,
    factory: *?*anyopaque,
) callconv(.winapi) HRESULT;

/// All DirectWrite interfaces share this layout: a single pointer to a
/// vtable of function pointers. Methods are invoked by casting the
/// numbered slot to its typed signature. Slot order is ABI-stable and
/// documented in dwrite.h.
fn comSlot(obj: anytype, comptime F: type, comptime index: usize) F {
    const com: *const extern struct { vtable: [*]const *const anyopaque } = @ptrCast(@alignCast(obj));
    return @ptrCast(@alignCast(com.vtable[index]));
}

fn comRelease(obj: anytype) void {
    const F = *const fn (@TypeOf(obj)) callconv(.winapi) u32;
    _ = comSlot(obj, F, 2)(obj);
}

fn comQueryInterface(obj: anytype, iid: *const GUID, out: *?*anyopaque) HRESULT {
    const F = *const fn (@TypeOf(obj), *const GUID, *?*anyopaque) callconv(.winapi) HRESULT;
    return comSlot(obj, F, 0)(obj, iid, out);
}
const IDWriteFactory = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getSystemFontCollection(self: *IDWriteFactory, out: *?*IDWriteFontCollection) HRESULT {
        const F = *const fn (*IDWriteFactory, *?*IDWriteFontCollection, BOOL) callconv(.winapi) HRESULT;
        return comSlot(self, F, 3)(self, out, 0);
    }
};

const IDWriteFontCollection = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getFontFamilyCount(self: *IDWriteFontCollection) u32 {
        const F = *const fn (*IDWriteFontCollection) callconv(.winapi) u32;
        return comSlot(self, F, 3)(self);
    }

    pub fn getFontFamily(self: *IDWriteFontCollection, index: u32, out: *?*IDWriteFontFamily) HRESULT {
        const F = *const fn (*IDWriteFontCollection, u32, *?*IDWriteFontFamily) callconv(.winapi) HRESULT;
        return comSlot(self, F, 4)(self, index, out);
    }

    pub fn findFamilyName(self: *IDWriteFontCollection, name: [*:0]const u16, index: *u32, exists: *BOOL) HRESULT {
        const F = *const fn (*IDWriteFontCollection, [*:0]const u16, *u32, *BOOL) callconv(.winapi) HRESULT;
        return comSlot(self, F, 5)(self, name, index, exists);
    }
};

const IDWriteFontFamily = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    // IDWriteFontList
    pub fn getFontCount(self: *IDWriteFontFamily) u32 {
        const F = *const fn (*IDWriteFontFamily) callconv(.winapi) u32;
        return comSlot(self, F, 4)(self);
    }

    pub fn getFont(self: *IDWriteFontFamily, index: u32, out: *?*IDWriteFont) HRESULT {
        const F = *const fn (*IDWriteFontFamily, u32, *?*IDWriteFont) callconv(.winapi) HRESULT;
        return comSlot(self, F, 5)(self, index, out);
    }

    pub fn getFamilyNames(self: *IDWriteFontFamily, out: *?*IDWriteLocalizedStrings) HRESULT {
        const F = *const fn (*IDWriteFontFamily, *?*IDWriteLocalizedStrings) callconv(.winapi) HRESULT;
        return comSlot(self, F, 6)(self, out);
    }

    pub fn getMatchingFonts(
        self: *IDWriteFontFamily,
        weight: u32,
        stretch: u32,
        style: u32,
        out: *?*IDWriteFontList,
    ) HRESULT {
        const F = *const fn (*IDWriteFontFamily, u32, u32, u32, *?*IDWriteFontList) callconv(.winapi) HRESULT;
        return comSlot(self, F, 8)(self, weight, stretch, style, out);
    }
};

const IDWriteFontList = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getFontCount(self: *IDWriteFontList) u32 {
        const F = *const fn (*IDWriteFontList) callconv(.winapi) u32;
        return comSlot(self, F, 4)(self);
    }

    pub fn getFont(self: *IDWriteFontList, index: u32, out: *?*IDWriteFont) HRESULT {
        const F = *const fn (*IDWriteFontList, u32, *?*IDWriteFont) callconv(.winapi) HRESULT;
        return comSlot(self, F, 5)(self, index, out);
    }
};

const IDWriteFont = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getFontFamily(self: *IDWriteFont, out: *?*IDWriteFontFamily) HRESULT {
        const F = *const fn (*IDWriteFont, *?*IDWriteFontFamily) callconv(.winapi) HRESULT;
        return comSlot(self, F, 3)(self, out);
    }

    pub fn isSymbolFont(self: *IDWriteFont) bool {
        const F = *const fn (*IDWriteFont) callconv(.winapi) BOOL;
        return comSlot(self, F, 7)(self) != 0;
    }

    pub fn getFaceNames(self: *IDWriteFont, out: *?*IDWriteLocalizedStrings) HRESULT {
        const F = *const fn (*IDWriteFont, *?*IDWriteLocalizedStrings) callconv(.winapi) HRESULT;
        return comSlot(self, F, 8)(self, out);
    }

    pub fn hasCharacter(self: *IDWriteFont, cp: u32) bool {
        const F = *const fn (*IDWriteFont, u32, *BOOL) callconv(.winapi) HRESULT;
        var exists: BOOL = 0;
        if (comSlot(self, F, 12)(self, cp, &exists) != 0) return false;
        return exists != 0;
    }

    pub fn createFontFace(self: *IDWriteFont, out: *?*IDWriteFontFace) HRESULT {
        const F = *const fn (*IDWriteFont, *?*IDWriteFontFace) callconv(.winapi) HRESULT;
        return comSlot(self, F, 13)(self, out);
    }
};

const IDWriteFontFace = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getFiles(self: *IDWriteFontFace, count: *u32, files: ?[*]?*IDWriteFontFile) HRESULT {
        const F = *const fn (*IDWriteFontFace, *u32, ?[*]?*IDWriteFontFile) callconv(.winapi) HRESULT;
        return comSlot(self, F, 4)(self, count, files);
    }

    pub fn getIndex(self: *IDWriteFontFace) u32 {
        const F = *const fn (*IDWriteFontFace) callconv(.winapi) u32;
        return comSlot(self, F, 5)(self);
    }
};

const IDWriteFontFile = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getReferenceKey(self: *IDWriteFontFile, key: *?*const anyopaque, size: *u32) HRESULT {
        const F = *const fn (*IDWriteFontFile, *?*const anyopaque, *u32) callconv(.winapi) HRESULT;
        return comSlot(self, F, 3)(self, key, size);
    }

    pub fn getLoader(self: *IDWriteFontFile, out: *?*IDWriteFontFileLoader) HRESULT {
        const F = *const fn (*IDWriteFontFile, *?*IDWriteFontFileLoader) callconv(.winapi) HRESULT;
        return comSlot(self, F, 4)(self, out);
    }
};

const IDWriteFontFileLoader = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn queryInterface(self: *@This(), iid: *const GUID, out: *?*anyopaque) HRESULT {
        return comQueryInterface(self, iid, out);
    }
};

const IDWriteLocalFontFileLoader = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getFilePathLengthFromKey(self: *IDWriteLocalFontFileLoader, key: *const anyopaque, key_size: u32, length: *u32) HRESULT {
        const F = *const fn (*IDWriteLocalFontFileLoader, *const anyopaque, u32, *u32) callconv(.winapi) HRESULT;
        return comSlot(self, F, 4)(self, key, key_size, length);
    }

    pub fn getFilePathFromKey(self: *IDWriteLocalFontFileLoader, key: *const anyopaque, key_size: u32, path: [*]u16, path_len: u32) HRESULT {
        const F = *const fn (*IDWriteLocalFontFileLoader, *const anyopaque, u32, [*]u16, u32) callconv(.winapi) HRESULT;
        return comSlot(self, F, 5)(self, key, key_size, path, path_len);
    }
};

const IDWriteLocalizedStrings = extern struct {
    vtable: [*]const *const anyopaque,

    pub fn release(self: *@This()) void {
        comRelease(self);
    }

    pub fn getCount(self: *IDWriteLocalizedStrings) u32 {
        const F = *const fn (*IDWriteLocalizedStrings) callconv(.winapi) u32;
        return comSlot(self, F, 3)(self);
    }

    pub fn findLocaleName(self: *IDWriteLocalizedStrings, locale: [*:0]const u16, index: *u32, exists: *BOOL) HRESULT {
        const F = *const fn (*IDWriteLocalizedStrings, [*:0]const u16, *u32, *BOOL) callconv(.winapi) HRESULT;
        return comSlot(self, F, 4)(self, locale, index, exists);
    }

    pub fn getStringLength(self: *IDWriteLocalizedStrings, index: u32, length: *u32) HRESULT {
        const F = *const fn (*IDWriteLocalizedStrings, u32, *u32) callconv(.winapi) HRESULT;
        return comSlot(self, F, 7)(self, index, length);
    }

    pub fn getString(self: *IDWriteLocalizedStrings, index: u32, buf: [*]u16, size: u32) HRESULT {
        const F = *const fn (*IDWriteLocalizedStrings, u32, [*]u16, u32) callconv(.winapi) HRESULT;
        return comSlot(self, F, 8)(self, index, buf, size);
    }
};

/// DirectWrite discovery. Matches the Discover interface used by the
/// other backends: argless init, lazy factory/collection creation on
/// first use.
pub const DWrite = struct {
    factory: ?*IDWriteFactory = null,
    collection: ?*IDWriteFontCollection = null,

    pub fn init() DWrite {
        return .{};
    }

    pub fn deinit(self: *DWrite) void {
        if (self.collection) |c| c.release();
        if (self.factory) |f| f.release();
        self.* = undefined;
    }

    fn ensure(self: *DWrite) !*IDWriteFontCollection {
        if (self.collection) |c| return c;

        var raw: ?*anyopaque = null;
        if (DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &IID_IDWriteFactory, &raw) != 0)
            return error.DWriteFactoryFailed;
        const factory: *IDWriteFactory = @ptrCast(@alignCast(raw.?));
        errdefer factory.release();

        var collection: ?*IDWriteFontCollection = null;
        if (factory.getSystemFontCollection(&collection) != 0 or collection == null)
            return error.DWriteCollectionFailed;

        self.factory = factory;
        self.collection = collection;
        return collection.?;
    }

    pub fn discover(self: *DWrite, alloc: Allocator, desc: Descriptor) !DiscoverIterator {
        const collection = try self.ensure();

        // Without a family, enumerate the whole system collection
        // (optionally filtered by codepoint). This drives list-fonts.
        const family = desc.family orelse return .{
            .alloc = alloc,
            .mode = .{ .scan = .{ .collection = collection } },
            .codepoint = desc.codepoint,
        };

        // Look up the family by name (UTF-16).
        var family16_buf: [256:0]u16 = undefined;
        const family16_len = std.unicode.utf8ToUtf16Le(&family16_buf, family) catch
            return .{ .alloc = alloc, .mode = .empty };
        if (family16_len >= family16_buf.len) return .{ .alloc = alloc, .mode = .empty };
        family16_buf[family16_len] = 0;

        var index: u32 = 0;
        var exists: BOOL = 0;
        if (collection.findFamilyName(&family16_buf, &index, &exists) != 0 or exists == 0)
            return .{ .alloc = alloc, .mode = .empty };

        var fam: ?*IDWriteFontFamily = null;
        if (collection.getFontFamily(index, &fam) != 0 or fam == null)
            return .{ .alloc = alloc, .mode = .empty };
        defer fam.?.release();

        // GetMatchingFonts returns the family's fonts sorted by
        // closeness to the requested style, so the first result is the
        // best match.
        const weight: u32 = if (desc.bold) WEIGHT_BOLD else WEIGHT_REGULAR;
        const style: u32 = if (desc.italic) STYLE_ITALIC else STYLE_NORMAL;
        var list: ?*IDWriteFontList = null;
        if (fam.?.getMatchingFonts(weight, STRETCH_NORMAL, style, &list) != 0 or list == null)
            return .{ .alloc = alloc, .mode = .empty };

        return .{ .alloc = alloc, .mode = .{ .list = .{ .list = list.? } } };
    }

    pub fn discoverFallback(
        self: *DWrite,
        alloc: Allocator,
        collection: *Collection,
        desc: Descriptor,
    ) !DiscoverIterator {
        _ = collection;

        // With a specific family requested, fall back to plain discovery.
        if (desc.family != null) return self.discover(alloc, desc);

        const sys = try self.ensure();
        return .{
            .alloc = alloc,
            .mode = .{ .scan = .{ .collection = sys } },
            .codepoint = desc.codepoint,
        };
    }

    pub const DiscoverIterator = struct {
        alloc: Allocator,
        mode: union(enum) {
            empty,
            list: struct {
                list: *IDWriteFontList,
                i: u32 = 0,
            },
            scan: struct {
                collection: *IDWriteFontCollection,
                family_i: u32 = 0,
                font_i: u32 = 0,
            },
        },
        codepoint: u32 = 0,

        pub fn deinit(self: *DiscoverIterator) void {
            switch (self.mode) {
                .empty, .scan => {},
                .list => |l| l.list.release(),
            }
            self.* = undefined;
        }

        pub fn next(self: *DiscoverIterator) !?DeferredFace {
            switch (self.mode) {
                .empty => return null,

                .list => |*l| while (l.i < l.list.getFontCount()) {
                    var fnt: ?*IDWriteFont = null;
                    if (l.list.getFont(l.i, &fnt) != 0 or fnt == null) {
                        l.i += 1;
                        continue;
                    }
                    defer fnt.?.release();
                    l.i += 1;
                    if (deferredFromFont(self.alloc, fnt.?) catch null) |face|
                        return face;
                } else return null,

                .scan => |*s| while (s.family_i < s.collection.getFontFamilyCount()) {
                    var fam: ?*IDWriteFontFamily = null;
                    if (s.collection.getFontFamily(s.family_i, &fam) != 0 or fam == null) {
                        s.family_i += 1;
                        s.font_i = 0;
                        continue;
                    }
                    defer fam.?.release();

                    const count = fam.?.getFontCount();
                    while (s.font_i < count) {
                        var fnt: ?*IDWriteFont = null;
                        const i = s.font_i;
                        s.font_i += 1;
                        if (fam.?.getFont(i, &fnt) != 0 or fnt == null) continue;
                        defer fnt.?.release();

                        if (fnt.?.isSymbolFont()) continue;
                        if (self.codepoint > 0 and !fnt.?.hasCharacter(self.codepoint)) continue;

                        if (deferredFromFont(self.alloc, fnt.?) catch null) |face|
                            return face;
                    }

                    s.family_i += 1;
                    s.font_i = 0;
                } else return null,
            }
        }
    };
};

/// Resolve an IDWriteFont to a DeferredFace carrying the font file
/// path, face index, and display names. Returns null for fonts that
/// aren't backed by a local file (remote/memory fonts).
fn deferredFromFont(alloc: Allocator, fnt: *IDWriteFont) !?DeferredFace {
    // Font file path via the font face reference key.
    var face: ?*IDWriteFontFace = null;
    if (fnt.createFontFace(&face) != 0 or face == null) return null;
    defer face.?.release();

    var file_count: u32 = 1;
    var file: ?*IDWriteFontFile = null;
    if (face.?.getFiles(&file_count, @ptrCast(&file)) != 0 or file == null) return null;
    defer file.?.release();

    var key: ?*const anyopaque = null;
    var key_size: u32 = 0;
    if (file.?.getReferenceKey(&key, &key_size) != 0 or key == null) return null;

    var loader: ?*IDWriteFontFileLoader = null;
    if (file.?.getLoader(&loader) != 0 or loader == null) return null;
    defer loader.?.release();

    var local_raw: ?*anyopaque = null;
    if (loader.?.queryInterface(&IID_IDWriteLocalFontFileLoader, &local_raw) != 0 or local_raw == null)
        return null; // not a local file
    const local: *IDWriteLocalFontFileLoader = @ptrCast(@alignCast(local_raw.?));
    defer local.release();

    var path_len: u32 = 0;
    if (local.getFilePathLengthFromKey(key.?, key_size, &path_len) != 0) return null;
    const path16 = try alloc.alloc(u16, path_len + 1);
    defer alloc.free(path16);
    if (local.getFilePathFromKey(key.?, key_size, path16.ptr, path_len + 1) != 0) return null;

    const path = try std.unicode.utf16LeToUtf8AllocZ(alloc, path16[0..path_len]);
    errdefer alloc.free(path);

    // Family name for display/matching.
    const family = blk: {
        var fam: ?*IDWriteFontFamily = null;
        if (fnt.getFontFamily(&fam) != 0 or fam == null) break :blk try alloc.dupeZ(u8, "");
        defer fam.?.release();
        var names: ?*IDWriteLocalizedStrings = null;
        if (fam.?.getFamilyNames(&names) != 0 or names == null) break :blk try alloc.dupeZ(u8, "");
        defer names.?.release();
        break :blk try localizedString(alloc, names.?);
    };
    errdefer alloc.free(family);

    // Style/face name (e.g. "Bold Italic").
    const style_name = blk: {
        var names: ?*IDWriteLocalizedStrings = null;
        if (fnt.getFaceNames(&names) != 0 or names == null) break :blk try alloc.dupeZ(u8, "");
        defer names.?.release();
        break :blk try localizedString(alloc, names.?);
    };
    defer alloc.free(style_name);

    const full_name = try std.fmt.allocPrintSentinel(alloc, "{s} {s}", .{ family, style_name }, 0);
    errdefer alloc.free(full_name);

    return DeferredFace{
        .dw = .{
            .alloc = alloc,
            .path = path,
            .index = @intCast(face.?.getIndex()),
            .family = family,
            .name = full_name,
        },
    };
}

/// Pick the en-us string if present, the first one otherwise.
fn localizedString(alloc: Allocator, strings: *IDWriteLocalizedStrings) ![:0]const u8 {
    var index: u32 = 0;
    var exists: BOOL = 0;
    const en_us = std.unicode.utf8ToUtf16LeStringLiteral("en-us");
    if (strings.findLocaleName(en_us, &index, &exists) != 0 or exists == 0) index = 0;
    if (strings.getCount() == 0) return try alloc.dupeZ(u8, "");

    var len: u32 = 0;
    if (strings.getStringLength(index, &len) != 0) return try alloc.dupeZ(u8, "");
    const buf16 = try alloc.alloc(u16, len + 1);
    defer alloc.free(buf16);
    if (strings.getString(index, buf16.ptr, len + 1) != 0) return try alloc.dupeZ(u8, "");

    return try std.unicode.utf16LeToUtf8AllocZ(alloc, buf16[0..len]);
}
