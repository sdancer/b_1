//! Polymost Type Definitions
//! Port from: NBlood/source/build/include/polymost.h
//!
//! Contains all polymost-specific data structures

const std = @import("std");
const types = @import("../types.zig");

// =============================================================================
// Texture Cache Entry (PTH)
// =============================================================================

/// Texture hash flags
pub const PthFlags = struct {
    pub const CLAMPED: u16 = 1;
    pub const HIGHTILE: u16 = 2;
    pub const SKYBOX: u16 = 4;
    pub const HASALPHA: u16 = 8;
    pub const HASFULLBRIGHT: u16 = 16;
    pub const NPOT: u16 = 32;
    pub const FORCEFILTER: u16 = 64;
    pub const NOTINDEXED: u16 = 128;
    pub const INDEXED: u16 = 256;
    pub const ONEBITALPHA: u16 = 512;
};

/// Texture cache entry (Polymost Texture Handle)
pub const PthType = struct {
    next: ?*PthType = null,
    ofb: ?*PthType = null, // fullbright copy
    hicr: ?*anyopaque = null, // HicReplcType pointer

    glpic: u32 = 0, // OpenGL texture ID
    scale: types.Vec2f = .{ .x = 1.0, .y = 1.0 },
    siz: types.Vec2 = .{ .x = 0, .y = 0 },

    picnum: i16 = 0,
    palnum: u8 = 0,
    shade: i8 = 0,
    effects: u8 = 0,
    flags: u16 = 0,
    skyface: u8 = 0,
};

// =============================================================================
// Color Type
// =============================================================================

/// RGBA color type (matches BUILD engine ColType)
pub const ColType = extern struct {
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,
    a: u8 = 255,

    pub fn init(r: u8, g: u8, b: u8, a: u8) ColType {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromU32(c: u32) ColType {
        return .{
            .b = @intCast(c & 0xFF),
            .g = @intCast((c >> 8) & 0xFF),
            .r = @intCast((c >> 16) & 0xFF),
            .a = @intCast((c >> 24) & 0xFF),
        };
    }

    pub fn toU32(self: ColType) u32 {
        return @as(u32, self.b) |
            (@as(u32, self.g) << 8) |
            (@as(u32, self.r) << 16) |
            (@as(u32, self.a) << 24);
    }
};

// =============================================================================
// Tint Flags
// =============================================================================

/// Polymost tint flags
pub const PolyTintFlags = struct {
    pub const NONE: u8 = 0;
    pub const USEONART: u8 = 1;
    pub const APPLYOVERPALSWAP: u8 = 2;
    pub const APPLYOVERALTPAL: u8 = 4;
    pub const BLEND_MULTIPLY: u8 = 8;
    pub const BLEND_SCREEN: u8 = 16;
    pub const BLEND_OVERLAY: u8 = 32;
    pub const BLEND_HARDLIGHT: u8 = 64;
};

/// Tint definition
pub const PolyTint = struct {
    r: u8 = 255,
    g: u8 = 255,
    b: u8 = 255,
    flags: u8 = 0,
};

// =============================================================================
// Drawing Parameters
// =============================================================================

/// Draw parameters for polymost rendering
pub const DrawParm = struct {
    /// Screen coordinates
    fsx: f32 = 0.0,
    fsy: f32 = 0.0,

    /// Size
    z: f32 = 1.0,

    /// Angle (in radians)
    a: f32 = 0.0,

    /// Tile/palette
    picnum: i16 = 0,
    shade: i8 = 0,
    pal: u8 = 0,

    /// Status flags
    dastat: i32 = 0,

    /// Alpha and blend
    alpha: u8 = 0,
    blend: u8 = 0,

    /// Clipping rectangle
    cx1: i32 = 0,
    cy1: i32 = 0,
    cx2: i32 = 0,
    cy2: i32 = 0,
};

// =============================================================================
// Vertex Buffer Types
// =============================================================================

/// Simple vertex for polymost
pub const PolymostVertex = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    u: f32 = 0.0,
    v: f32 = 0.0,
};

/// Extended vertex with color
pub const PolymostVertexCol = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    u: f32 = 0.0,
    v: f32 = 0.0,
    r: u8 = 255,
    g: u8 = 255,
    b: u8 = 255,
    a: u8 = 255,
};

// =============================================================================
// Shader Uniforms
// =============================================================================

/// Polymost shader uniform locations
pub const PolymostUniforms = struct {
    u_texturePosSize: i32 = -1,
    u_halfTexelSize: i32 = -1,
    u_palswap: i32 = -1,
    u_palette: i32 = -1,
    u_shade: i32 = -1,
    u_fogRange: i32 = -1,
    u_fogColor: i32 = -1,
    u_usePalette: i32 = -1,
    u_useColorOnly: i32 = -1,
    u_useDetailMapping: i32 = -1,
    u_useGlowMapping: i32 = -1,
    u_tintOverlay: i32 = -1,
    u_tintColor: i32 = -1,
    u_brightness: i32 = -1,
    u_contrast: i32 = -1,
    u_saturation: i32 = -1,
    u_visibility: i32 = -1,
};

// =============================================================================
// Dameth Flags (Method Flags for Texture Rendering)
// =============================================================================

/// Texture method flags
pub const Dameth = struct {
    pub const NOMASK: i32 = 0;
    pub const MASK: i32 = 1;
    pub const TRANS1: i32 = 2;
    pub const TRANS2: i32 = 3;
    pub const MASKPROPS: i32 = 3;

    pub const CLAMPED: i32 = 4;
    pub const WALL: i32 = 32;
    pub const INDEXED: i32 = 512;
    pub const N64: i32 = 1024;
    pub const ARTIMMUNITY: i32 = 2048;
    pub const INDEXED_SKY: i32 = 4096;
    pub const NOTEXCOMPRESS: i32 = 8192;

    /// Check if method has masking
    pub fn hasMask(dameth: i32) bool {
        return (dameth & MASKPROPS) != 0;
    }

    /// Check if method has translucency
    pub fn hasTranslucency(dameth: i32) bool {
        return (dameth & MASKPROPS) >= TRANS1;
    }
};

// =============================================================================
// Spriteext (Sprite Extension Data)
// =============================================================================

/// Extended sprite data for rendering
pub const SpriteExt = struct {
    mdanimtims: u32 = 0,
    mdanimcur: i16 = 0,
    angoff: i16 = 0,
    pitch: i16 = 0,
    roll: i16 = 0,
    pivot_offset: types.Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    position_offset: types.Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    flags: u8 = 0,
    alpha: f32 = 0.0,
};

/// Sprite smoothing data
pub const SpriteSmooth = struct {
    smoothduration: f32 = 0.0,
    mdcurframe: i16 = 0,
    mdoldframe: i16 = 0,
    mdsmooth: i16 = 0,
};

// =============================================================================
// Skybox Definition
// =============================================================================

/// Skybox face indices
pub const SkyboxFace = enum(u3) {
    front = 0,
    right = 1,
    back = 2,
    left = 3,
    top = 4,
    bottom = 5,
};

/// Skybox definition
pub const SkyboxDef = struct {
    faces: [6]?*PthType = .{ null, null, null, null, null, null },
    tilenum: i16 = 0,
    palnum: u8 = 0,
};

// =============================================================================
// Tests
// =============================================================================

test "ColType size and layout" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(ColType));
}

test "ColType conversion" {
    const c = ColType.init(255, 128, 64, 255);
    try std.testing.expectEqual(@as(u8, 255), c.r);
    try std.testing.expectEqual(@as(u8, 128), c.g);
    try std.testing.expectEqual(@as(u8, 64), c.b);

    const u = c.toU32();
    const c2 = ColType.fromU32(u);
    try std.testing.expectEqual(c.r, c2.r);
    try std.testing.expectEqual(c.g, c2.g);
    try std.testing.expectEqual(c.b, c2.b);
    try std.testing.expectEqual(c.a, c2.a);
}

test "PolymostVertex size" {
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(PolymostVertex));
}

test "Dameth flags" {
    try std.testing.expect(!Dameth.hasMask(Dameth.NOMASK));
    try std.testing.expect(Dameth.hasMask(Dameth.MASK));
    try std.testing.expect(Dameth.hasTranslucency(Dameth.TRANS1));
    try std.testing.expect(Dameth.hasTranslucency(Dameth.TRANS2));
}
