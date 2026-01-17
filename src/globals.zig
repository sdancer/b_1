//! BUILD Engine Global State
//! Port from: NBlood/source/build/include/build.h (lines 596-833)
//!
//! This module contains all global state used by the rendering engine.
//! In C, these are extern variables accessed throughout the codebase.

const std = @import("std");
const types = @import("types.zig");
const constants = @import("constants.zig");

// =============================================================================
// Core Entity Arrays
// =============================================================================

/// All sectors in the map
pub var sector: [constants.MAXSECTORS + constants.M32_FIXME_SECTORS]types.SectorType = undefined;

/// All walls in the map
pub var wall: [constants.MAXWALLS + constants.M32_FIXME_WALLS]types.WallType = undefined;

/// All sprites in the map
pub var sprite: [constants.MAXSPRITES]types.SpriteType = undefined;

/// Temporary sprites for rendering (sorted/processed each frame)
pub var tsprite: [constants.MAXSPRITESONSCREEN]types.TSpriteType = undefined;

// =============================================================================
// Entity Extension Arrays
// =============================================================================

/// Sprite extension data (for models, animation, etc.)
pub var spriteext: [constants.MAXSPRITES + constants.MAXUNIQHUDID]types.SpriteExt = undefined;

/// Sprite smoothing data (for interpolation)
pub var spritesmooth: [constants.MAXSPRITES + constants.MAXUNIQHUDID]types.SpriteSmooth = undefined;

/// Wall extension data
pub var wallext: [constants.MAXWALLS]types.WallExt = undefined;

// =============================================================================
// Change Tracking Arrays
// =============================================================================

/// Sector change revision tracking
pub var sectorchanged: [constants.MAXSECTORS]u32 = [_]u32{0} ** constants.MAXSECTORS;

/// Wall change revision tracking
pub var wallchanged: [constants.MAXWALLS]u32 = [_]u32{0} ** constants.MAXWALLS;

/// Sprite change revision tracking
pub var spritechanged: [constants.MAXSPRITES]u32 = [_]u32{0} ** constants.MAXSPRITES;

// =============================================================================
// Entity Counts
// =============================================================================

/// Number of sectors in current map
pub var numsectors: i32 = 0;

/// Number of walls in current map
pub var numwalls: i32 = 0;

/// Number of sprites in current map (note: uppercase N matches C code)
pub var Numsprites: i32 = 0;

// =============================================================================
// Rendering State
// =============================================================================

/// Masked walls for sorting during rendering
pub var maskwall: [constants.MAXWALLSB]i16 = undefined;

/// Count of masked walls to render
pub var maskwallcnt: i16 = 0;

/// Pointers to temporary sprites for rendering
pub var tspriteptr: [constants.MAXSPRITESONSCREEN + 1]?*types.TSpriteType = [_]?*types.TSpriteType{null} ** (constants.MAXSPRITESONSCREEN + 1);

/// Count of sprites to render
pub var spritesortcnt: i32 = 0;

// =============================================================================
// Display State
// =============================================================================

/// Screen width in pixels
pub var xdim: i32 = 0;

/// Screen height in pixels
pub var ydim: i32 = 0;

/// Viewing range (FOV related)
pub var viewingrange: i32 = 0;

/// Y/X aspect ratio
pub var yxaspect: i32 = 0;

/// Scanline lookup table (pointer to array of row offsets)
pub var ylookup: ?[*]isize = null;

/// Bytes per scanline
pub var bytesperline: i32 = 0;

/// Frame buffer pointer
pub var frameplace: isize = 0;

/// Rotatesprite Y offset for screen effects
pub var rotatesprite_y_offset: i32 = 0;

/// Unique HUD ID for model tracking
pub var guniqhudid: i32 = 0;

// =============================================================================
// View Window
// =============================================================================

/// Top-left corner of viewable area
pub var windowxy1: types.Vec2 = .{ .x = 0, .y = 0 };

/// Bottom-right corner of viewable area
pub var windowxy2: types.Vec2 = .{ .x = 0, .y = 0 };

// =============================================================================
// Palette/Color State
// =============================================================================

/// Main 256-color palette (RGB, 3 bytes per color)
pub var palette: [768]u8 = [_]u8{0} ** 768;

/// Number of shade tables
pub var numshades: i16 = 0;

/// Shade/lighting lookup tables
pub var palookup: [constants.MAXPALOOKUPS]?[*]u8 = [_]?[*]u8{null} ** constants.MAXPALOOKUPS;

/// Transparency blend tables
pub var blendtable: [constants.MAXBLENDTABS]?[*]u8 = [_]?[*]u8{null} ** constants.MAXBLENDTABS;

// =============================================================================
// Sprite Lists (doubly-linked list structure)
// =============================================================================

/// Head of sprite status lists
pub var headspritestat: [constants.MAXSTATUS + 1]i16 = [_]i16{-1} ** (constants.MAXSTATUS + 1);

/// Head of sprite sector lists
pub var headspritesect: [constants.MAXSECTORS + 1]i16 = [_]i16{-1} ** (constants.MAXSECTORS + 1);

/// Previous sprite in status list
pub var prevspritestat: [constants.MAXSPRITES]i16 = undefined;

/// Next sprite in status list
pub var nextspritestat: [constants.MAXSPRITES]i16 = undefined;

/// Previous sprite in sector list
pub var prevspritesect: [constants.MAXSPRITES]i16 = undefined;

/// Next sprite in sector list
pub var nextspritesect: [constants.MAXSPRITES]i16 = undefined;

// =============================================================================
// YAX (True Room Over Room) State
// =============================================================================

/// Ceiling/floor bunch numbers for each sector [sectnum][0=ceil, 1=floor]
pub var yax_bunchnum: [constants.MAXSECTORS][2]i16 = [_][2]i16{[_]i16{ -1, -1 }} ** constants.MAXSECTORS;

/// Next wall in YAX chain [wallnum][0=ceil, 1=floor]
pub var yax_nextwall: [constants.MAXWALLS][2]i16 = [_][2]i16{[_]i16{ -1, -1 }} ** constants.MAXWALLS;

/// Head sector for each bunch [0=ceil, 1=floor][bunchnum]
pub var headsectbunch: [2][constants.YAX_MAXBUNCHES]i16 = [_][constants.YAX_MAXBUNCHES]i16{[_]i16{-1} ** constants.YAX_MAXBUNCHES} ** 2;

/// Next sector in bunch
pub var nextsectbunch: [2][constants.MAXSECTORS]i16 = [_][constants.MAXSECTORS]i16{[_]i16{-1} ** constants.MAXSECTORS} ** 2;

/// Number of YAX bunches
pub var numyaxbunches: i32 = 0;

/// Disable mask pass for TROR
pub var r_tror_nomaskpass: i32 = 0;

// =============================================================================
// Visibility Bitmaps (for editor/renderer)
// =============================================================================

/// Bitmap of sectors to skip drawing (editor gray sectors)
pub var graysectbitmap: [(constants.MAXSECTORS + 7) >> 3]u8 = [_]u8{0} ** ((constants.MAXSECTORS + 7) >> 3);

/// Bitmap of walls to skip drawing (editor gray walls)
pub var graywallbitmap: [(constants.MAXWALLS + 7) >> 3]u8 = [_]u8{0} ** ((constants.MAXWALLS + 7) >> 3);

// =============================================================================
// Sin/Cos Table
// =============================================================================

/// Sine table with 2048 entries (sin * 16383)
pub var sintable: [constants.SINTABLE_SIZE]i16 = undefined;

// =============================================================================
// Rendering Mode
// =============================================================================

/// Current rendering mode (classic, polymost, polymer)
pub var rendmode: i32 = @intFromEnum(@import("enums.zig").RendMode.polymost);

/// OpenGL rendering mode
pub var glrendmode: i32 = @intFromEnum(@import("enums.zig").RendMode.polymost);

// =============================================================================
// Global Rendering Parameters
// =============================================================================

/// Current tile being rendered
pub var globalpicnum: i32 = 0;

/// Current palette for rendering
pub var globalpal: i32 = 0;

/// Current shade level
pub var globalshade: i32 = 0;

/// Global orientation flags
pub var globalorientation: i32 = 0;

/// Global visibility
pub var globalvisibility: i32 = 0;

/// Global flags
pub var globalflags: i32 = 0;

// =============================================================================
// Hitscan Goal
// =============================================================================

/// Target coordinates for hitscan operations
pub var hitscangoal: types.Vec2 = .{ .x = std.math.maxInt(i32), .y = std.math.maxInt(i32) };

// =============================================================================
// Blood Hack Flag
// =============================================================================

/// Blood-specific compatibility flag
pub var bloodhack: i32 = 1;

// =============================================================================
// Initialization Functions
// =============================================================================

/// Initialize all global arrays to default state
pub fn initGlobals() void {
    // Zero out main entity arrays
    @memset(std.mem.asBytes(&sector), 0);
    @memset(std.mem.asBytes(&wall), 0);
    @memset(std.mem.asBytes(&sprite), 0);
    @memset(std.mem.asBytes(&tsprite), 0);

    // Zero out extension arrays
    @memset(std.mem.asBytes(&spriteext), 0);
    @memset(std.mem.asBytes(&spritesmooth), 0);
    @memset(std.mem.asBytes(&wallext), 0);

    // Reset counts
    numsectors = 0;
    numwalls = 0;
    Numsprites = 0;
    spritesortcnt = 0;
    maskwallcnt = 0;

    // Reset sprite lists
    for (&headspritestat) |*h| h.* = -1;
    for (&headspritesect) |*h| h.* = -1;

    // Reset YAX state
    for (&yax_bunchnum) |*b| b.* = [_]i16{ -1, -1 };
    for (&yax_nextwall) |*n| n.* = [_]i16{ -1, -1 };
    numyaxbunches = 0;
}

/// Initialize the sine table
pub fn initSinTable() void {
    for (0..constants.SINTABLE_SIZE) |i| {
        const angle = @as(f64, @floatFromInt(i)) * std.math.pi / 1024.0;
        sintable[i] = @intFromFloat(@sin(angle) * 16383.0);
    }
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Get sine value from table
pub inline fn getSin(ang: i32) i16 {
    return sintable[@as(usize, @intCast(ang & 2047))];
}

/// Get cosine value from table (sin offset by 512)
pub inline fn getCos(ang: i32) i16 {
    return sintable[@as(usize, @intCast((ang + 512) & 2047))];
}

/// Check if a sector index is valid
pub inline fn isValidSector(sectnum: i16) bool {
    return sectnum >= 0 and sectnum < numsectors;
}

/// Check if a wall index is valid
pub inline fn isValidWall(wallnum: i16) bool {
    return wallnum >= 0 and wallnum < numwalls;
}

/// Check if a sprite index is valid
pub inline fn isValidSprite(spritenum: i16) bool {
    return spritenum >= 0 and spritenum < Numsprites and sprite[@intCast(spritenum)].statnum != constants.MAXSTATUS;
}

// =============================================================================
// Tests
// =============================================================================

test "global array sizes" {
    try std.testing.expectEqual(@as(usize, constants.MAXSECTORS + constants.M32_FIXME_SECTORS), sector.len);
    try std.testing.expectEqual(@as(usize, constants.MAXWALLS + constants.M32_FIXME_WALLS), wall.len);
    try std.testing.expectEqual(@as(usize, constants.MAXSPRITES), sprite.len);
    try std.testing.expectEqual(@as(usize, constants.MAXSPRITESONSCREEN), tsprite.len);
}

test "init globals" {
    initGlobals();
    try std.testing.expectEqual(@as(i32, 0), numsectors);
    try std.testing.expectEqual(@as(i32, 0), numwalls);
    try std.testing.expectEqual(@as(i32, 0), Numsprites);
}

test "sin table" {
    initSinTable();
    // sin(0) should be 0
    try std.testing.expectEqual(@as(i16, 0), sintable[0]);
    // sin(512) = sin(pi/2) should be ~16383
    try std.testing.expect(sintable[512] > 16380);
    // sin(1024) = sin(pi) should be ~0
    try std.testing.expect(@abs(sintable[1024]) < 10);
}
