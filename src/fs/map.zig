//! MAP File Loader
//! Port from: NBlood/source/blood/src/db.cpp
//!
//! Loads BUILD engine MAP files (Blood format).
//! The MAP format contains sectors, walls, and sprites that define the level geometry.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const reader = @import("reader.zig");

const BinaryReader = reader.BinaryReader;

// =============================================================================
// MAP File Constants
// =============================================================================

/// Blood MAP signature "BLM\x1a"
pub const MAP_SIGNATURE: u32 = 0x1a4d4c42;

/// Blood MAP version
pub const MAP_VERSION: u16 = 0x0700;

/// Blood map header encryption keys
pub const MAP_HEADER_NEW: u32 = 0x7474614D; // "Matt" as little-endian
pub const MAP_HEADER_OLD: u32 = 0x4D617474; // "ttaM" as little-endian

/// Standard BUILD MAP signature (Duke3D, etc.)
pub const BUILD_MAP_VERSION_7: u32 = 7;
pub const BUILD_MAP_VERSION_8: u32 = 8;
pub const BUILD_MAP_VERSION_9: u32 = 9;

// =============================================================================
// MAP Header Structures
// =============================================================================

/// Blood MAP signature header
pub const MapSignature = struct {
    signature: u32,
    version: u16,
};

/// Blood MAP header
pub const BloodMapHeader = struct {
    /// Player start X position
    posx: i32,
    /// Player start Y position
    posy: i32,
    /// Player start Z position
    posz: i32,
    /// Player start angle (0-2047)
    ang: i16,
    /// Player start sector
    cursectnum: i16,
    /// Sky parallax bits (log2 of sky tile count)
    pskybits: i16,
    /// Visibility
    visibility: i32,
    /// Song/map ID
    songid: i32,
    /// Parallax type
    parallaxtype: i8,
    /// Map revision
    maprevision: i32,
    /// Number of sectors
    numsectors: i16,
    /// Number of walls
    numwalls: i16,
    /// Number of sprites
    numsprites: i16,
};

/// Standard BUILD MAP header (Duke3D, Shadow Warrior, etc.)
pub const BuildMapHeader = struct {
    version: i32,
    posx: i32,
    posy: i32,
    posz: i32,
    ang: i16,
    cursectnum: i16,
    numsectors: u16,
};

/// Loaded map data
pub const MapData = struct {
    /// Player start position
    startx: i32,
    starty: i32,
    startz: i32,
    startang: i16,
    startsect: i16,

    /// Map geometry counts
    numsectors: i32,
    numwalls: i32,
    numsprites: i32,

    /// Sky settings
    pskybits: i16,
    visibility: i32,

    /// Allocator used
    allocator: std.mem.Allocator,

    /// Sky tile offsets (if any)
    pskyoff: ?[]i16,

    pub fn deinit(self: *MapData) void {
        if (self.pskyoff) |off| {
            self.allocator.free(off);
        }
    }
};

// =============================================================================
// MAP Loading Functions
// =============================================================================

/// Blood map header decryption (dbCrypt)
fn dbCrypt(ptr: []u8, key: u32) void {
    var k: u32 = key;
    for (ptr) |*b| {
        b.* ^= @truncate(k);
        k +%= 1;
    }
}

/// Load a Blood format MAP file
pub fn loadBloodMap(allocator: std.mem.Allocator, data: []const u8) !MapData {
    if (data.len < 6 + 37) return error.FileTooSmall;

    // Read and validate signature
    const sig = std.mem.readInt(u32, data[0..4], .little);
    if (sig != MAP_SIGNATURE) {
        return error.InvalidMapSignature;
    }

    const version = std.mem.readInt(u16, data[4..6], .little);
    if ((version & 0xFF00) != (MAP_VERSION & 0xFF00)) {
        return error.UnsupportedMapVersion;
    }

    // Copy header bytes (37 bytes starting at offset 6)
    var header: [37]u8 = undefined;
    @memcpy(&header, data[6..43]);

    // Check if header is encrypted by examining the songid field (offset 22 in header = offset 28 in file)
    // songid is at header offset 16 (0x10) for 4 bytes
    const songid_raw = std.mem.readInt(u32, header[16..20], .little);

    if (songid_raw != 0 and songid_raw != MAP_HEADER_NEW and songid_raw != MAP_HEADER_OLD) {
        // Header is encrypted, decrypt it
        dbCrypt(&header, MAP_HEADER_NEW);
    }

    // Parse header from decrypted bytes
    const posx = std.mem.readInt(i32, header[0..4], .little);
    const posy = std.mem.readInt(i32, header[4..8], .little);
    const posz = std.mem.readInt(i32, header[8..12], .little);
    const ang = std.mem.readInt(i16, header[12..14], .little);
    const cursectnum = std.mem.readInt(i16, header[14..16], .little);
    const pskybits = std.mem.readInt(i16, header[16..18], .little);
    const visibility = std.mem.readInt(i32, header[18..22], .little);
    // songid at 22..26
    // parallaxtype at 26
    const maprevision = std.mem.readInt(i32, header[27..31], .little);
    const numsectors = std.mem.readInt(i16, header[31..33], .little);
    const numwalls = std.mem.readInt(i16, header[33..35], .little);
    const numsprites = std.mem.readInt(i16, header[35..37], .little);

    // Validate counts
    if (numsectors < 0 or numsectors > constants.MAXSECTORS) {
        return error.InvalidSectorCount;
    }
    if (numwalls < 0 or numwalls > constants.MAXWALLS) {
        return error.InvalidWallCount;
    }
    if (numsprites < 0 or numsprites > constants.MAXSPRITES) {
        return error.InvalidSpriteCount;
    }

    // Determine if data is encrypted (version 0x0700)
    const is_encrypted = (version & 0xFF00) == 0x0700;

    // Calculate encryption keys for sectors, walls, and sprites
    const sector_key: u32 = @as(u32, @bitCast(maprevision)) *% 40;
    const wall_key: u32 = (@as(u32, @bitCast(maprevision)) *% 40) | MAP_HEADER_NEW;
    const sprite_key: u32 = (@as(u32, @bitCast(maprevision)) *% 44) | MAP_HEADER_NEW;

    // Create reader starting after the header (6 + 37 = 43)
    var r = BinaryReader.init(data);
    try r.seek(43);

    // Read MAPHEADER2 for modern maps (128 bytes)
    // Contains sizes of extended structures at offsets 64, 68, 72
    // MAPHEADER2 is encrypted using numwalls as the key
    var xsprite_size: u32 = 0;
    var xwall_size: u32 = 0;
    var xsector_size: u32 = 0;

    if (version == MAP_VERSION) {
        var header2: [128]u8 = undefined;
        const h2_slice = try r.readSlice(128);
        @memcpy(&header2, h2_slice);

        if (is_encrypted) {
            dbCrypt(&header2, @as(u32, @bitCast(@as(i32, numwalls))));
        }

        xsprite_size = std.mem.readInt(u32, header2[64..68], .little);
        xwall_size = std.mem.readInt(u32, header2[68..72], .little);
        xsector_size = std.mem.readInt(u32, header2[72..76], .little);
    }

    // Read sky tile offsets
    var pskyoff: ?[]i16 = null;
    if (pskybits > 0 and pskybits <= 8) {
        const numskytiles: usize = @as(usize, 1) << @intCast(pskybits);
        pskyoff = try allocator.alloc(i16, numskytiles);
        for (0..numskytiles) |i| {
            pskyoff.?[i] = try r.readI16LE();
        }
    }

    // Read sectors (40 bytes each) + extended data
    for (0..@as(usize, @intCast(numsectors))) |i| {
        try readSectorEncrypted(&r, i, is_encrypted, sector_key);
        // Skip XSECTOR if present
        if (globals.sector[i].extra > 0 and xsector_size > 0) {
            try r.skip(xsector_size);
        }
    }

    // Read walls (32 bytes each) + extended data
    for (0..@as(usize, @intCast(numwalls))) |i| {
        try readWallEncrypted(&r, i, is_encrypted, wall_key);
        // Skip XWALL if present
        if (globals.wall[i].extra > 0 and xwall_size > 0) {
            try r.skip(xwall_size);
        }
    }

    // Read sprites (44 bytes each) + extended data
    for (0..@as(usize, @intCast(numsprites))) |i| {
        try readSpriteEncrypted(&r, i, is_encrypted, sprite_key);
        // Skip XSPRITE if present
        if (globals.sprite[i].extra > 0 and xsprite_size > 0) {
            try r.skip(xsprite_size);
        }
    }

    // Update global counts
    globals.numsectors = numsectors;
    globals.numwalls = numwalls;

    return MapData{
        .startx = posx,
        .starty = posy,
        .startz = posz,
        .startang = ang,
        .startsect = cursectnum,
        .numsectors = numsectors,
        .numwalls = numwalls,
        .numsprites = numsprites,
        .pskybits = pskybits,
        .visibility = visibility,
        .allocator = allocator,
        .pskyoff = pskyoff,
    };
}

/// Load a standard BUILD format MAP file (Duke3D, Shadow Warrior, etc.)
pub fn loadBuildMap(allocator: std.mem.Allocator, data: []const u8) !MapData {
    var r = BinaryReader.init(data);

    // Read version
    const version = try r.readI32LE();
    if (version != BUILD_MAP_VERSION_7 and version != BUILD_MAP_VERSION_8 and version != BUILD_MAP_VERSION_9) {
        return error.UnsupportedMapVersion;
    }

    // Read header
    const posx = try r.readI32LE();
    const posy = try r.readI32LE();
    const posz = try r.readI32LE();
    const ang = try r.readI16LE();
    const cursectnum = try r.readI16LE();
    const numsectors = try r.readU16LE();

    // Validate
    if (numsectors > constants.MAXSECTORS) {
        return error.InvalidSectorCount;
    }

    // Read sectors
    for (0..numsectors) |i| {
        try readSector(&r, i);
    }

    // Read wall count and walls
    const numwalls = try r.readU16LE();
    if (numwalls > constants.MAXWALLS) {
        return error.InvalidWallCount;
    }

    for (0..numwalls) |i| {
        try readWall(&r, i);
    }

    // Read sprite count and sprites
    const numsprites = try r.readU16LE();
    if (numsprites > constants.MAXSPRITES) {
        return error.InvalidSpriteCount;
    }

    for (0..numsprites) |i| {
        try readSprite(&r, i);
    }

    // Update globals
    globals.numsectors = @intCast(numsectors);
    globals.numwalls = @intCast(numwalls);

    return MapData{
        .startx = posx,
        .starty = posy,
        .startz = posz,
        .startang = ang,
        .startsect = cursectnum,
        .numsectors = @intCast(numsectors),
        .numwalls = @intCast(numwalls),
        .numsprites = @intCast(numsprites),
        .pskybits = 0,
        .visibility = 0,
        .allocator = allocator,
        .pskyoff = null,
    };
}

/// Auto-detect map format and load
pub fn loadMap(allocator: std.mem.Allocator, data: []const u8) !MapData {
    if (data.len < 4) {
        return error.FileTooSmall;
    }

    // Check for Blood signature
    const sig = std.mem.readInt(u32, data[0..4], .little);
    if (sig == MAP_SIGNATURE) {
        return loadBloodMap(allocator, data);
    }

    // Otherwise try standard BUILD format
    return loadBuildMap(allocator, data);
}

/// Load a map from a file path
pub fn loadMapFromFile(allocator: std.mem.Allocator, path: []const u8) !MapData {
    const data = try reader.loadFile(allocator, path);
    defer allocator.free(data);

    return loadMap(allocator, data);
}

// =============================================================================
// Structure Reading (with encryption support)
// =============================================================================

/// Read a sector with optional decryption (40 bytes)
fn readSectorEncrypted(r: *BinaryReader, index: usize, encrypted: bool, key: u32) !void {
    var buf: [40]u8 = undefined;
    const slice = try r.readSlice(40);
    @memcpy(&buf, slice);

    if (encrypted) {
        dbCrypt(&buf, key);
    }

    var sec = &globals.sector[index];
    sec.wallptr = std.mem.readInt(i16, buf[0..2], .little);
    sec.wallnum = std.mem.readInt(i16, buf[2..4], .little);
    sec.ceilingz = std.mem.readInt(i32, buf[4..8], .little);
    sec.floorz = std.mem.readInt(i32, buf[8..12], .little);
    sec.ceilingstat = std.mem.readInt(u16, buf[12..14], .little);
    sec.floorstat = std.mem.readInt(u16, buf[14..16], .little);
    sec.ceilingpicnum = std.mem.readInt(i16, buf[16..18], .little);
    sec.ceilingheinum = std.mem.readInt(i16, buf[18..20], .little);
    sec.ceilingshade = @bitCast(buf[20]);
    sec.ceilingpal = buf[21];
    sec.ceilingxpanning = buf[22];
    sec.ceilingypanning = buf[23];
    sec.floorpicnum = std.mem.readInt(i16, buf[24..26], .little);
    sec.floorheinum = std.mem.readInt(i16, buf[26..28], .little);
    sec.floorshade = @bitCast(buf[28]);
    sec.floorpal = buf[29];
    sec.floorxpanning = buf[30];
    sec.floorypanning = buf[31];
    sec.visibility = buf[32];
    sec.fogpal = buf[33];
    sec.lotag = std.mem.readInt(i16, buf[34..36], .little);
    sec.hitag = std.mem.readInt(i16, buf[36..38], .little);
    sec.extra = std.mem.readInt(i16, buf[38..40], .little);
}

/// Read a wall with optional decryption (32 bytes)
fn readWallEncrypted(r: *BinaryReader, index: usize, encrypted: bool, key: u32) !void {
    var buf: [32]u8 = undefined;
    const slice = try r.readSlice(32);
    @memcpy(&buf, slice);

    if (encrypted) {
        dbCrypt(&buf, key);
    }

    var wal = &globals.wall[index];
    wal.x = std.mem.readInt(i32, buf[0..4], .little);
    wal.y = std.mem.readInt(i32, buf[4..8], .little);
    wal.point2 = std.mem.readInt(i16, buf[8..10], .little);
    wal.nextwall = std.mem.readInt(i16, buf[10..12], .little);
    wal.nextsector = std.mem.readInt(i16, buf[12..14], .little);
    wal.cstat = std.mem.readInt(u16, buf[14..16], .little);
    wal.picnum = std.mem.readInt(i16, buf[16..18], .little);
    wal.overpicnum = std.mem.readInt(i16, buf[18..20], .little);
    wal.shade = @bitCast(buf[20]);
    wal.pal = buf[21];
    wal.xrepeat = buf[22];
    wal.yrepeat = buf[23];
    wal.xpanning = buf[24];
    wal.ypanning = buf[25];
    wal.lotag = std.mem.readInt(i16, buf[26..28], .little);
    wal.hitag = std.mem.readInt(i16, buf[28..30], .little);
    wal.extra = std.mem.readInt(i16, buf[30..32], .little);
}

/// Read a sprite with optional decryption (44 bytes)
fn readSpriteEncrypted(r: *BinaryReader, index: usize, encrypted: bool, key: u32) !void {
    var buf: [44]u8 = undefined;
    const slice = try r.readSlice(44);
    @memcpy(&buf, slice);

    if (encrypted) {
        dbCrypt(&buf, key);
    }

    var spr = &globals.sprite[index];
    spr.x = std.mem.readInt(i32, buf[0..4], .little);
    spr.y = std.mem.readInt(i32, buf[4..8], .little);
    spr.z = std.mem.readInt(i32, buf[8..12], .little);
    spr.cstat = std.mem.readInt(u16, buf[12..14], .little);
    spr.picnum = std.mem.readInt(i16, buf[14..16], .little);
    spr.shade = @bitCast(buf[16]);
    spr.pal = buf[17];
    spr.clipdist = buf[18];
    spr.blend = buf[19];
    spr.xrepeat = buf[20];
    spr.yrepeat = buf[21];
    spr.xoffset = @bitCast(buf[22]);
    spr.yoffset = @bitCast(buf[23]);
    spr.sectnum = std.mem.readInt(i16, buf[24..26], .little);
    spr.statnum = std.mem.readInt(i16, buf[26..28], .little);
    spr.ang = std.mem.readInt(i16, buf[28..30], .little);
    spr.owner = std.mem.readInt(i16, buf[30..32], .little);
    spr.xvel = std.mem.readInt(i16, buf[32..34], .little);
    spr.yvel = std.mem.readInt(i16, buf[34..36], .little);
    spr.zvel = std.mem.readInt(i16, buf[36..38], .little);
    spr.lotag = std.mem.readInt(i16, buf[38..40], .little);
    spr.hitag = std.mem.readInt(i16, buf[40..42], .little);
    spr.extra = std.mem.readInt(i16, buf[42..44], .little);
}

// =============================================================================
// Structure Reading (unencrypted)
// =============================================================================

/// Read a sector from the file (40 bytes)
fn readSector(r: *BinaryReader, index: usize) !void {
    var sec = &globals.sector[index];

    sec.wallptr = try r.readI16LE();
    sec.wallnum = try r.readI16LE();
    sec.ceilingz = try r.readI32LE();
    sec.floorz = try r.readI32LE();
    sec.ceilingstat = try r.readU16LE();
    sec.floorstat = try r.readU16LE();
    sec.ceilingpicnum = try r.readI16LE();
    sec.ceilingheinum = try r.readI16LE();
    sec.ceilingshade = try r.readI8();
    sec.ceilingpal = try r.readByte();
    sec.ceilingxpanning = try r.readByte();
    sec.ceilingypanning = try r.readByte();
    sec.floorpicnum = try r.readI16LE();
    sec.floorheinum = try r.readI16LE();
    sec.floorshade = try r.readI8();
    sec.floorpal = try r.readByte();
    sec.floorxpanning = try r.readByte();
    sec.floorypanning = try r.readByte();
    sec.visibility = try r.readByte();
    sec.fogpal = try r.readByte();
    sec.lotag = try r.readI16LE();
    sec.hitag = try r.readI16LE();
    sec.extra = try r.readI16LE();
}

/// Read a wall from the file (32 bytes)
fn readWall(r: *BinaryReader, index: usize) !void {
    var wal = &globals.wall[index];

    wal.x = try r.readI32LE();
    wal.y = try r.readI32LE();
    wal.point2 = try r.readI16LE();
    wal.nextwall = try r.readI16LE();
    wal.nextsector = try r.readI16LE();
    wal.cstat = try r.readU16LE();
    wal.picnum = try r.readI16LE();
    wal.overpicnum = try r.readI16LE();
    wal.shade = try r.readI8();
    wal.pal = try r.readByte();
    wal.xrepeat = try r.readByte();
    wal.yrepeat = try r.readByte();
    wal.xpanning = try r.readByte();
    wal.ypanning = try r.readByte();
    wal.lotag = try r.readI16LE();
    wal.hitag = try r.readI16LE();
    wal.extra = try r.readI16LE();
}

/// Read a sprite from the file (44 bytes)
fn readSprite(r: *BinaryReader, index: usize) !void {
    var spr = &globals.sprite[index];

    spr.x = try r.readI32LE();
    spr.y = try r.readI32LE();
    spr.z = try r.readI32LE();
    spr.cstat = try r.readU16LE();
    spr.picnum = try r.readI16LE();
    spr.shade = try r.readI8();
    spr.pal = try r.readByte();
    spr.clipdist = try r.readByte();
    spr.blend = try r.readByte();
    spr.xrepeat = try r.readByte();
    spr.yrepeat = try r.readByte();
    spr.xoffset = try r.readI8();
    spr.yoffset = try r.readI8();
    spr.sectnum = try r.readI16LE();
    spr.statnum = try r.readI16LE();
    spr.ang = try r.readI16LE();
    spr.owner = try r.readI16LE();
    spr.xvel = try r.readI16LE();
    spr.yvel = try r.readI16LE();
    spr.zvel = try r.readI16LE();
    spr.lotag = try r.readI16LE();
    spr.hitag = try r.readI16LE();
    spr.extra = try r.readI16LE();
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Get sector bounds (min/max x,y)
pub fn getSectorBounds(sectnum: i16) struct { minx: i32, miny: i32, maxx: i32, maxy: i32 } {
    if (sectnum < 0 or sectnum >= globals.numsectors) {
        return .{ .minx = 0, .miny = 0, .maxx = 0, .maxy = 0 };
    }

    const sec = &globals.sector[@intCast(sectnum)];
    const startwall: usize = @intCast(sec.wallptr);
    const endwall = startwall + @as(usize, @intCast(sec.wallnum));

    var minx: i32 = std.math.maxInt(i32);
    var miny: i32 = std.math.maxInt(i32);
    var maxx: i32 = std.math.minInt(i32);
    var maxy: i32 = std.math.minInt(i32);

    for (startwall..endwall) |i| {
        const wal = &globals.wall[i];
        minx = @min(minx, wal.x);
        miny = @min(miny, wal.y);
        maxx = @max(maxx, wal.x);
        maxy = @max(maxy, wal.y);
    }

    return .{ .minx = minx, .miny = miny, .maxx = maxx, .maxy = maxy };
}

/// Get map bounds (all sectors)
pub fn getMapBounds() struct { minx: i32, miny: i32, maxx: i32, maxy: i32 } {
    var minx: i32 = std.math.maxInt(i32);
    var miny: i32 = std.math.maxInt(i32);
    var maxx: i32 = std.math.minInt(i32);
    var maxy: i32 = std.math.minInt(i32);

    for (0..@as(usize, @intCast(globals.numwalls))) |i| {
        const wal = &globals.wall[i];
        minx = @min(minx, wal.x);
        miny = @min(miny, wal.y);
        maxx = @max(maxx, wal.x);
        maxy = @max(maxy, wal.y);
    }

    return .{ .minx = minx, .miny = miny, .maxx = maxx, .maxy = maxy };
}

// =============================================================================
// Tests
// =============================================================================

test "map signature" {
    try std.testing.expectEqual(@as(u32, 0x1a4d4c42), MAP_SIGNATURE);
}

test "sector bounds empty" {
    globals.numsectors = 0;
    const bounds = getSectorBounds(0);
    try std.testing.expectEqual(@as(i32, 0), bounds.minx);
}
