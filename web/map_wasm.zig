//! WASM Map Loader
//! Simplified map loader for WASM that uses module imports.

const std = @import("std");
const types = @import("types");
const constants = @import("constants");
const globals = @import("globals");

// =============================================================================
// MAP File Constants
// =============================================================================

/// Blood MAP signature "BLM\x1a"
pub const MAP_SIGNATURE: u32 = 0x1a4d4c42;

/// Blood MAP version
pub const MAP_VERSION: u16 = 0x0700;

/// Blood map header encryption keys
pub const MAP_HEADER_NEW: u32 = 0x7474614D; // "Matt" as little-endian

/// Standard BUILD MAP versions
pub const BUILD_MAP_VERSION_7: u32 = 7;
pub const BUILD_MAP_VERSION_8: u32 = 8;
pub const BUILD_MAP_VERSION_9: u32 = 9;

// =============================================================================
// MapData Result
// =============================================================================

pub const MapData = struct {
    startx: i32,
    starty: i32,
    startz: i32,
    startang: i16,
    startsect: i16,
    numsectors: i32,
    numwalls: i32,
    numsprites: i32,
    pskybits: i16 = 0,
    visibility: i32 = 0,
    allocator: std.mem.Allocator,
    pskyoff: ?[]i16 = null,

    pub fn deinit(self: *MapData) void {
        if (self.pskyoff) |off| {
            self.allocator.free(off);
        }
    }
};

// =============================================================================
// Binary Reader
// =============================================================================

const BinaryReader = struct {
    data: []const u8,
    pos: usize = 0,

    fn init(data: []const u8) BinaryReader {
        return .{ .data = data };
    }

    fn seek(self: *BinaryReader, pos: usize) !void {
        if (pos > self.data.len) return error.SeekOutOfBounds;
        self.pos = pos;
    }

    fn skip(self: *BinaryReader, count: usize) !void {
        if (self.pos + count > self.data.len) return error.UnexpectedEof;
        self.pos += count;
    }

    fn readSlice(self: *BinaryReader, len: usize) ![]const u8 {
        if (self.pos + len > self.data.len) return error.UnexpectedEof;
        const slice = self.data[self.pos .. self.pos + len];
        self.pos += len;
        return slice;
    }

    fn readI32LE(self: *BinaryReader) !i32 {
        const slice = try self.readSlice(4);
        return std.mem.readInt(i32, slice[0..4], .little);
    }

    fn readU16LE(self: *BinaryReader) !u16 {
        const slice = try self.readSlice(2);
        return std.mem.readInt(u16, slice[0..2], .little);
    }

    fn readI16LE(self: *BinaryReader) !i16 {
        const slice = try self.readSlice(2);
        return std.mem.readInt(i16, slice[0..2], .little);
    }

    fn readI8(self: *BinaryReader) !i8 {
        const slice = try self.readSlice(1);
        return @bitCast(slice[0]);
    }

    fn readByte(self: *BinaryReader) !u8 {
        const slice = try self.readSlice(1);
        return slice[0];
    }
};

// =============================================================================
// Decryption
// =============================================================================

fn dbCrypt(ptr: []u8, key: u32) void {
    var k: u32 = key;
    for (ptr) |*b| {
        b.* ^= @truncate(k);
        k +%= 1;
    }
}

// =============================================================================
// Map Loading
// =============================================================================

pub fn loadMap(allocator: std.mem.Allocator, data: []const u8) !MapData {
    if (data.len < 4) return error.FileTooSmall;

    const sig = std.mem.readInt(u32, data[0..4], .little);
    if (sig == MAP_SIGNATURE) {
        return loadBloodMap(allocator, data);
    }
    return loadBuildMap(allocator, data);
}

fn loadBloodMap(allocator: std.mem.Allocator, data: []const u8) !MapData {
    if (data.len < 6 + 37) return error.FileTooSmall;

    const sig = std.mem.readInt(u32, data[0..4], .little);
    if (sig != MAP_SIGNATURE) return error.InvalidMapSignature;

    const version = std.mem.readInt(u16, data[4..6], .little);
    if ((version & 0xFF00) != (MAP_VERSION & 0xFF00)) return error.UnsupportedMapVersion;

    var header: [37]u8 = undefined;
    @memcpy(&header, data[6..43]);

    const songid_raw = std.mem.readInt(u32, header[16..20], .little);
    if (songid_raw != 0 and songid_raw != MAP_HEADER_NEW and songid_raw != 0x4D617474) {
        dbCrypt(&header, MAP_HEADER_NEW);
    }

    const posx = std.mem.readInt(i32, header[0..4], .little);
    const posy = std.mem.readInt(i32, header[4..8], .little);
    const posz = std.mem.readInt(i32, header[8..12], .little);
    const ang = std.mem.readInt(i16, header[12..14], .little);
    const cursectnum = std.mem.readInt(i16, header[14..16], .little);
    const pskybits = std.mem.readInt(i16, header[16..18], .little);
    const visibility = std.mem.readInt(i32, header[18..22], .little);
    const maprevision = std.mem.readInt(i32, header[27..31], .little);
    const numsectors = std.mem.readInt(i16, header[31..33], .little);
    const numwalls = std.mem.readInt(i16, header[33..35], .little);
    const numsprites = std.mem.readInt(i16, header[35..37], .little);

    if (numsectors < 0 or numsectors > constants.MAXSECTORS) return error.InvalidSectorCount;
    if (numwalls < 0 or numwalls > constants.MAXWALLS) return error.InvalidWallCount;
    if (numsprites < 0 or numsprites > constants.MAXSPRITES) return error.InvalidSpriteCount;

    const is_encrypted = (version & 0xFF00) == 0x0700;
    const sector_key: u32 = @as(u32, @bitCast(maprevision)) *% 40;
    const wall_key: u32 = (@as(u32, @bitCast(maprevision)) *% 40) | MAP_HEADER_NEW;
    const sprite_key: u32 = (@as(u32, @bitCast(maprevision)) *% 44) | MAP_HEADER_NEW;

    var r = BinaryReader.init(data);
    try r.seek(43);

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

    var pskyoff: ?[]i16 = null;
    if (pskybits > 0 and pskybits <= 8) {
        const numskytiles: usize = @as(usize, 1) << @intCast(pskybits);
        pskyoff = try allocator.alloc(i16, numskytiles);
        for (0..numskytiles) |i| {
            pskyoff.?[i] = try r.readI16LE();
        }
    }

    for (0..@as(usize, @intCast(numsectors))) |i| {
        try readSectorEncrypted(&r, i, is_encrypted, sector_key);
        if (globals.sector[i].extra > 0 and xsector_size > 0) {
            try r.skip(xsector_size);
        }
    }

    for (0..@as(usize, @intCast(numwalls))) |i| {
        try readWallEncrypted(&r, i, is_encrypted, wall_key);
        if (globals.wall[i].extra > 0 and xwall_size > 0) {
            try r.skip(xwall_size);
        }
    }

    for (0..@as(usize, @intCast(numsprites))) |i| {
        try readSpriteEncrypted(&r, i, is_encrypted, sprite_key);
        if (globals.sprite[i].extra > 0 and xsprite_size > 0) {
            try r.skip(xsprite_size);
        }
    }

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

fn loadBuildMap(allocator: std.mem.Allocator, data: []const u8) !MapData {
    var r = BinaryReader.init(data);

    const version = try r.readI32LE();
    if (version != BUILD_MAP_VERSION_7 and version != BUILD_MAP_VERSION_8 and version != BUILD_MAP_VERSION_9) {
        return error.UnsupportedMapVersion;
    }

    const posx = try r.readI32LE();
    const posy = try r.readI32LE();
    const posz = try r.readI32LE();
    const ang = try r.readI16LE();
    const cursectnum = try r.readI16LE();
    const numsectors = try r.readU16LE();

    if (numsectors > constants.MAXSECTORS) return error.InvalidSectorCount;

    for (0..numsectors) |i| {
        try readSector(&r, i);
    }

    const numwalls = try r.readU16LE();
    if (numwalls > constants.MAXWALLS) return error.InvalidWallCount;

    for (0..numwalls) |i| {
        try readWall(&r, i);
    }

    const numsprites = try r.readU16LE();
    if (numsprites > constants.MAXSPRITES) return error.InvalidSpriteCount;

    for (0..numsprites) |i| {
        try readSprite(&r, i);
    }

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
        .allocator = allocator,
    };
}

// =============================================================================
// Structure Reading
// =============================================================================

fn readSectorEncrypted(r: *BinaryReader, index: usize, encrypted: bool, key: u32) !void {
    var buf: [40]u8 = undefined;
    const slice = try r.readSlice(40);
    @memcpy(&buf, slice);

    if (encrypted) dbCrypt(&buf, key);

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

fn readWallEncrypted(r: *BinaryReader, index: usize, encrypted: bool, key: u32) !void {
    var buf: [32]u8 = undefined;
    const slice = try r.readSlice(32);
    @memcpy(&buf, slice);

    if (encrypted) dbCrypt(&buf, key);

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

fn readSpriteEncrypted(r: *BinaryReader, index: usize, encrypted: bool, key: u32) !void {
    var buf: [44]u8 = undefined;
    const slice = try r.readSlice(44);
    @memcpy(&buf, slice);

    if (encrypted) dbCrypt(&buf, key);

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
