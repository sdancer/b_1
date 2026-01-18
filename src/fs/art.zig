//! ART File Loader
//! Port from: NBlood/source/build/src/cache1d.cpp and engine.cpp
//!
//! Loads BUILD engine ART files containing tile graphics.
//! ART files store multiple tiles with dimensions, animation data, and palette-indexed pixels.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const reader = @import("reader.zig");

const BinaryReader = reader.BinaryReader;

// =============================================================================
// ART File Constants
// =============================================================================

/// ART file version (should always be 1)
pub const ART_VERSION: i32 = 1;

/// Number of tiles per ART file
pub const TILES_PER_ART: i32 = 256;

/// Maximum tile dimensions
pub const MAX_TILE_SIZE: i32 = 4096;

// =============================================================================
// ART Structures
// =============================================================================

/// Tile animation data (packed in picanm)
pub const PicAnm = packed struct {
    /// Number of animation frames (0 = not animated)
    num: u6,
    /// Animation type: 0=none, 1=oscillate, 2=forward, 3=backward
    animtype: u2,
    /// X offset for centering
    xoffset: i8,
    /// Y offset for centering
    yoffset: i8,
    /// Animation speed (lower = faster)
    speed: u4,
    /// Extra flags
    extra: u4,
};

/// Individual tile information
pub const TileInfo = struct {
    /// Width of tile
    sizx: i16,
    /// Height of tile
    sizy: i16,
    /// Animation data
    picanm: PicAnm,
    /// Offset in data buffer (or null if not loaded)
    data_offset: ?usize,
    /// Size of pixel data
    data_size: usize,
};

/// Loaded ART file data
pub const ArtData = struct {
    /// First tile number in this file
    tilestart: i32,
    /// Last tile number in this file
    tileend: i32,
    /// Number of tiles
    numtiles: i32,
    /// Tile information array
    tiles: []TileInfo,
    /// Raw pixel data (all tiles concatenated)
    pixels: []u8,
    /// Allocator used
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ArtData) void {
        self.allocator.free(self.tiles);
        self.allocator.free(self.pixels);
    }

    /// Get pixel data for a specific tile
    pub fn getTilePixels(self: *const ArtData, tilenum: i32) ?[]const u8 {
        if (tilenum < self.tilestart or tilenum > self.tileend) {
            return null;
        }
        const idx: usize = @intCast(tilenum - self.tilestart);
        const tile = &self.tiles[idx];
        if (tile.data_offset) |offset| {
            return self.pixels[offset .. offset + tile.data_size];
        }
        return null;
    }
};

// =============================================================================
// ART Loading Functions
// =============================================================================

/// Load an ART file
pub fn loadArt(allocator: std.mem.Allocator, data: []const u8) !ArtData {
    var r = BinaryReader.init(data);

    // Read header
    const version = try r.readI32LE();
    if (version != ART_VERSION) {
        return error.UnsupportedArtVersion;
    }

    // Read tile range
    const numtiles_unused = try r.readI32LE();
    _ = numtiles_unused; // This field is ignored in modern BUILD
    const tilestart = try r.readI32LE();
    const tileend = try r.readI32LE();

    // Validate range
    if (tilestart < 0 or tileend < tilestart or tileend >= constants.MAXTILES) {
        return error.InvalidTileRange;
    }

    const numtiles: usize = @intCast(tileend - tilestart + 1);

    // Allocate tile info array
    const tiles = try allocator.alloc(TileInfo, numtiles);
    errdefer allocator.free(tiles);

    // Read tile dimensions (sizx array, then sizy array)
    for (0..numtiles) |i| {
        tiles[i].sizx = try r.readI16LE();
    }
    for (0..numtiles) |i| {
        tiles[i].sizy = try r.readI16LE();
    }

    // Read picanm array (animation data - 4 bytes per tile)
    for (0..numtiles) |i| {
        const picanm_raw = try r.readI32LE();
        tiles[i].picanm = @bitCast(picanm_raw);
    }

    // Calculate total pixel data size and offsets
    var total_pixels: usize = 0;
    for (0..numtiles) |i| {
        const sizx = tiles[i].sizx;
        const sizy = tiles[i].sizy;

        if (sizx <= 0 or sizy <= 0) {
            tiles[i].data_offset = null;
            tiles[i].data_size = 0;
        } else {
            tiles[i].data_offset = total_pixels;
            tiles[i].data_size = @as(usize, @intCast(sizx)) * @as(usize, @intCast(sizy));
            total_pixels += tiles[i].data_size;
        }
    }

    // Read all pixel data
    const pixels = try allocator.alloc(u8, total_pixels);
    errdefer allocator.free(pixels);

    if (total_pixels > 0) {
        const slice = try r.readSlice(total_pixels);
        @memcpy(pixels, slice);
    }

    return ArtData{
        .tilestart = tilestart,
        .tileend = tileend,
        .numtiles = @intCast(numtiles),
        .tiles = tiles,
        .pixels = pixels,
        .allocator = allocator,
    };
}

/// Load an ART file from path
pub fn loadArtFromFile(allocator: std.mem.Allocator, path: []const u8) !ArtData {
    const data = try reader.loadFile(allocator, path);
    defer allocator.free(data);

    return loadArt(allocator, data);
}

// =============================================================================
// Tile Management
// =============================================================================

/// Global tile dimensions (populated from ART files)
pub var tilesizx: [constants.MAXTILES]i16 = .{0} ** constants.MAXTILES;
pub var tilesizy: [constants.MAXTILES]i16 = .{0} ** constants.MAXTILES;

/// Global tile animation data
pub var picanm: [constants.MAXTILES]PicAnm = .{PicAnm{
    .num = 0,
    .animtype = 0,
    .xoffset = 0,
    .yoffset = 0,
    .speed = 0,
    .extra = 0,
}} ** constants.MAXTILES;

/// Tile data pointers (null if not loaded)
pub var tiledata: [constants.MAXTILES]?[*]const u8 = .{null} ** constants.MAXTILES;

/// Load tiles from ART data into global arrays
pub fn loadTilesToGlobals(art: *const ArtData, pixel_storage: []u8) void {
    var storage_offset: usize = 0;

    for (0..@as(usize, @intCast(art.numtiles))) |i| {
        const tilenum: usize = @intCast(art.tilestart + @as(i32, @intCast(i)));
        if (tilenum >= constants.MAXTILES) continue;

        tilesizx[tilenum] = art.tiles[i].sizx;
        tilesizy[tilenum] = art.tiles[i].sizy;
        picanm[tilenum] = art.tiles[i].picanm;

        // Copy pixel data to storage and set pointer
        if (art.tiles[i].data_offset) |offset| {
            const size = art.tiles[i].data_size;
            if (storage_offset + size <= pixel_storage.len) {
                const dest = pixel_storage[storage_offset .. storage_offset + size];
                const src = art.pixels[offset .. offset + size];
                @memcpy(dest, src);
                tiledata[tilenum] = @ptrCast(&pixel_storage[storage_offset]);
                storage_offset += size;
            }
        } else {
            tiledata[tilenum] = null;
        }
    }
}

/// Calculate total pixel storage needed for an ART file
pub fn calculateStorageNeeded(art: *const ArtData) usize {
    var total: usize = 0;
    for (art.tiles) |tile| {
        total += tile.data_size;
    }
    return total;
}

// =============================================================================
// Tile Queries
// =============================================================================

/// Get tile width
pub fn getTileSizeX(tilenum: i32) i16 {
    if (tilenum < 0 or tilenum >= constants.MAXTILES) return 0;
    return tilesizx[@intCast(tilenum)];
}

/// Get tile height
pub fn getTileSizeY(tilenum: i32) i16 {
    if (tilenum < 0 or tilenum >= constants.MAXTILES) return 0;
    return tilesizy[@intCast(tilenum)];
}

/// Get tile animation frame count
pub fn getTileAnimFrames(tilenum: i32) i32 {
    if (tilenum < 0 or tilenum >= constants.MAXTILES) return 0;
    return @as(i32, picanm[@intCast(tilenum)].num);
}

/// Get tile animation type
pub fn getTileAnimType(tilenum: i32) i32 {
    if (tilenum < 0 or tilenum >= constants.MAXTILES) return 0;
    return @as(i32, picanm[@intCast(tilenum)].animtype);
}

/// Check if tile is valid (has dimensions)
pub fn isTileValid(tilenum: i32) bool {
    if (tilenum < 0 or tilenum >= constants.MAXTILES) return false;
    const idx: usize = @intCast(tilenum);
    return tilesizx[idx] > 0 and tilesizy[idx] > 0;
}

// =============================================================================
// Palette Loading
// =============================================================================

/// Palette entry
pub const PaletteEntry = struct {
    r: u8,
    g: u8,
    b: u8,
};

/// Full 256-color palette
pub const Palette = [256]PaletteEntry;

/// Load a palette from raw data (768 bytes = 256 * 3)
pub fn loadPalette(data: []const u8) !Palette {
    if (data.len < 768) {
        return error.InvalidPaletteSize;
    }

    var pal: Palette = undefined;
    for (0..256) |i| {
        // BUILD palettes are stored as 6-bit values (0-63), need to scale to 8-bit
        pal[i] = .{
            .r = @as(u8, data[i * 3 + 0]) << 2,
            .g = @as(u8, data[i * 3 + 1]) << 2,
            .b = @as(u8, data[i * 3 + 2]) << 2,
        };
    }

    return pal;
}

/// Load palette from file
pub fn loadPaletteFromFile(allocator: std.mem.Allocator, path: []const u8) !Palette {
    const data = try reader.loadFile(allocator, path);
    defer allocator.free(data);

    return loadPalette(data);
}

// =============================================================================
// ART File Naming
// =============================================================================

/// Generate ART filename for a given file number
/// Returns something like "tiles000.art" for filenum=0
pub fn getArtFilename(buf: []u8, filenum: i32) []u8 {
    // Manual zero-padding for 3 digits
    const num: u32 = if (filenum < 0) 0 else @intCast(filenum);
    const d0: u8 = @intCast((num / 100) % 10);
    const d1: u8 = @intCast((num / 10) % 10);
    const d2: u8 = @intCast(num % 10);
    return std.fmt.bufPrint(buf, "tiles{c}{c}{c}.art", .{ '0' + d0, '0' + d1, '0' + d2 }) catch buf[0..0];
}

/// Calculate which ART file contains a given tile
pub fn getArtFileForTile(tilenum: i32) i32 {
    return @divTrunc(tilenum, TILES_PER_ART);
}

// =============================================================================
// Tests
// =============================================================================

test "art version" {
    try std.testing.expectEqual(@as(i32, 1), ART_VERSION);
}

test "picanm size" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(PicAnm));
}

test "tile queries empty" {
    // Reset state
    tilesizx[0] = 0;
    tilesizy[0] = 0;

    try std.testing.expect(!isTileValid(0));
    try std.testing.expectEqual(@as(i16, 0), getTileSizeX(-1));
    try std.testing.expectEqual(@as(i16, 0), getTileSizeY(constants.MAXTILES));
}

test "art filename generation" {
    var buf: [32]u8 = undefined;
    const name = getArtFilename(&buf, 0);
    try std.testing.expectEqualStrings("tiles000.art", name);

    const name2 = getArtFilename(&buf, 15);
    try std.testing.expectEqualStrings("tiles015.art", name2);
}

test "art file for tile" {
    try std.testing.expectEqual(@as(i32, 0), getArtFileForTile(0));
    try std.testing.expectEqual(@as(i32, 0), getArtFileForTile(255));
    try std.testing.expectEqual(@as(i32, 1), getArtFileForTile(256));
    try std.testing.expectEqual(@as(i32, 10), getArtFileForTile(2560));
}
