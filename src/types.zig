//! Core BUILD engine data types
//! Port from: NBlood/source/build/include/buildtypes.h
//! These structures must match the C layout exactly for binary compatibility.

const std = @import("std");

// =============================================================================
// Vector Types
// =============================================================================

pub const Vec2 = extern struct {
    x: i32,
    y: i32,
};

pub const Vec3 = extern struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const Vec2_16 = extern struct {
    x: i16,
    y: i16,
};

pub const Vec3_16 = extern struct {
    x: i16,
    y: i16,
    z: i16,
};

pub const Vec2f = extern struct {
    x: f32,
    y: f32,
};

pub const Vec3f = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Vec4f = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

// =============================================================================
// Hit Data
// =============================================================================

pub const HitData = extern struct {
    x: i32,
    y: i32,
    z: i32,
    sprite: i16,
    wall: i16,
    sect: i16,
};

// =============================================================================
// Sector Type (40 bytes - v7 format)
// =============================================================================
// ceilingstat/floorstat bits:
//   bit 0: 1 = parallaxing, 0 = not                                 "P"
//   bit 1: 1 = groudraw, 0 = not
//   bit 2: 1 = swap x&y, 0 = not                                    "F"
//   bit 3: 1 = double smooshiness                                   "E"
//   bit 4: 1 = x-flip                                               "F"
//   bit 5: 1 = y-flip                                               "F"
//   bit 6: 1 = Align texture to first wall of sector                "R"
//   bits 8-7:                                                       "T"
//          00 = normal floors
//          01 = masked floors
//          10 = transluscent masked floors
//          11 = reverse transluscent masked floors
//   bit 9: 1 = blocking ceiling/floor
//   bit 10: 1 = YAX'ed ceiling/floor
//   bit 11: 1 = hitscan-sensitive ceiling/floor
//   bits 12-15: reserved

pub const SectorType = extern struct {
    wallptr: i16,
    wallnum: i16,
    ceilingz: i32,
    floorz: i32,
    ceilingstat: u16,
    floorstat: u16,
    ceilingpicnum: i16,
    ceilingheinum: i16,
    ceilingshade: i8,
    ceilingpal: u8,
    ceilingxpanning: u8,
    ceilingypanning: u8,
    floorpicnum: i16,
    floorheinum: i16,
    floorshade: i8,
    floorpal: u8,
    floorxpanning: u8,
    floorypanning: u8,
    visibility: u8,
    fogpal: u8,
    lotag: i16,
    hitag: i16,
    extra: i16,
};

// Compile-time verification of struct size
comptime {
    if (@sizeOf(SectorType) != 40) {
        @compileError("SectorType size mismatch: expected 40 bytes");
    }
}

// =============================================================================
// Wall Type (32 bytes - v7 format)
// =============================================================================
// cstat bits:
//   bit 0: 1 = Blocking wall (use with clipmove, getzrange)         "B"
//   bit 1: 1 = bottoms of invisible walls swapped, 0 = not          "2"
//   bit 2: 1 = align picture on bottom (for doors), 0 = top         "O"
//   bit 3: 1 = x-flipped, 0 = normal                                "F"
//   bit 4: 1 = masking wall, 0 = not                                "M"
//   bit 5: 1 = 1-way wall, 0 = not                                  "1"
//   bit 6: 1 = Blocking wall (use with hitscan / cliptype 1)        "H"
//   bit 7: 1 = Transluscence, 0 = not                               "T"
//   bit 8: 1 = y-flipped, 0 = normal                                "F"
//   bit 9: 1 = Transluscence reversing, 0 = normal                  "T"
//   bits 10 and 11: reserved (in use by YAX)
//   bits 12-15: reserved  (14: temp use by editor)

pub const WallType = extern struct {
    x: i32,
    y: i32,
    point2: i16,
    nextwall: i16,
    nextsector: i16,
    cstat: u16,
    picnum: i16,
    overpicnum: i16,
    shade: i8,
    pal: u8,
    xrepeat: u8,
    yrepeat: u8,
    xpanning: u8,
    ypanning: u8,
    lotag: i16,
    hitag: i16,
    extra: i16,
};

// Compile-time verification of struct size
comptime {
    if (@sizeOf(WallType) != 32) {
        @compileError("WallType size mismatch: expected 32 bytes");
    }
}

// =============================================================================
// Sprite Type (44 bytes - v7 format)
// =============================================================================
// cstat bits:
//   bit 0: 1 = Blocking sprite (use with clipmove, getzrange)       "B"
//   bit 1: 1 = transluscence, 0 = normal                            "T"
//   bit 2: 1 = x-flipped, 0 = normal                                "F"
//   bit 3: 1 = y-flipped, 0 = normal                                "F"
//   bits 5-4: 00 = FACE sprite (default)                            "R"
//             01 = WALL sprite (like masked walls)
//             10 = FLOOR sprite (parallel to ceilings&floors)
//   bit 6: 1 = 1-sided sprite, 0 = normal                           "1"
//   bit 7: 1 = Real centered centering, 0 = foot center             "C"
//   bit 8: 1 = Blocking sprite (use with hitscan / cliptype 1)      "H"
//   bit 9: 1 = Transluscence reversing, 0 = normal                  "T"
//   bit 10: reserved (in use by a renderer hack)
//   bit 11: 1 = determine shade based only on its own shade member
//   bit 12: reserved
//   bit 13: 1 = does not cast shadow
//   bit 14: 1 = invisible but casts shadow
//   bit 15: 1 = Invisible sprite, 0 = not invisible

pub const SpriteType = extern struct {
    x: i32,
    y: i32,
    z: i32,
    cstat: u16,
    picnum: i16,
    shade: i8,
    pal: u8,
    clipdist: u8,
    blend: u8,
    xrepeat: u8,
    yrepeat: u8,
    xoffset: i8,
    yoffset: i8,
    sectnum: i16,
    statnum: i16,
    ang: i16,
    owner: i16,
    xvel: i16,
    yvel: i16,
    zvel: i16,
    lotag: i16,
    hitag: i16,
    extra: i16,
};

// Compile-time verification of struct size
comptime {
    if (@sizeOf(SpriteType) != 44) {
        @compileError("SpriteType size mismatch: expected 44 bytes");
    }
}

// =============================================================================
// TSprite Type (44 bytes - temporary sprite for rendering)
// =============================================================================
// Same layout as SpriteType but without trackers (used only during rendering)

pub const TSpriteType = extern struct {
    x: i32,
    y: i32,
    z: i32,
    cstat: u16,
    picnum: i16,
    shade: i8,
    pal: u8,
    clipdist: u8,
    blend: u8,
    xrepeat: u8,
    yrepeat: u8,
    xoffset: i8,
    yoffset: i8,
    sectnum: i16,
    statnum: i16,
    ang: i16,
    owner: i16,
    xvel: i16,
    yvel: i16,
    zvel: i16,
    lotag: i16,
    hitag: i16,
    extra: i16,
};

// Compile-time verification of struct size
comptime {
    if (@sizeOf(TSpriteType) != 44) {
        @compileError("TSpriteType size mismatch: expected 44 bytes");
    }
}

// =============================================================================
// Sprite Extension Data
// =============================================================================

pub const SpriteExt = extern struct {
    mdanimtims: i32,
    mdanimcur: i16,
    angoff: i16,
    pitch: i16,
    roll: i16,
    pivot_offset: Vec3,
    position_offset: Vec3,
    flags: u8,
    xpanning: u8,
    ypanning: u8,
    alpha: u8,
};

pub const SpriteSmooth = extern struct {
    smoothduration: f32,
    mdcurframe: i16,
    mdoldframe: i16,
    mdsmooth: i16,
    _pad: i16,
};

pub const WallExt = extern struct {
    alpha: u8,
    _pad: [3]u8,
};

// =============================================================================
// Color Types
// =============================================================================

pub const ColType = extern struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
};

pub const Palette = extern struct {
    r: u8,
    g: u8,
    b: u8,
    f: u8,
};

// =============================================================================
// Fixed-point type (16.16 format)
// =============================================================================

pub const Fix16 = i32;

pub fn fix16FromInt(val: i32) Fix16 {
    return val << 16;
}

pub fn fix16ToInt(val: Fix16) i32 {
    return val >> 16;
}

pub fn fix16ToFloat(val: Fix16) f32 {
    return @as(f32, @floatFromInt(val)) / 65536.0;
}

pub fn fix16FromFloat(val: f32) Fix16 {
    return @intFromFloat(val * 65536.0);
}

// =============================================================================
// Tests
// =============================================================================

test "struct sizes match C" {
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(SectorType));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(WallType));
    try std.testing.expectEqual(@as(usize, 44), @sizeOf(SpriteType));
    try std.testing.expectEqual(@as(usize, 44), @sizeOf(TSpriteType));
}

test "vector sizes" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Vec2));
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Vec3));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Vec2f));
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Vec3f));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Vec4f));
}

test "fix16 conversions" {
    try std.testing.expectEqual(@as(Fix16, 65536), fix16FromInt(1));
    try std.testing.expectEqual(@as(Fix16, 131072), fix16FromInt(2));
    try std.testing.expectEqual(@as(i32, 1), fix16ToInt(fix16FromInt(1)));
    try std.testing.expectEqual(@as(i32, 100), fix16ToInt(fix16FromInt(100)));
}
