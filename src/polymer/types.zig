//! Polymer Type Definitions
//! Port from: NBlood/source/build/include/polymer.h
//!
//! Contains all polymer-specific data structures for the advanced
//! OpenGL renderer with dynamic lighting.

const std = @import("std");
const types = @import("../types.zig");

// =============================================================================
// Polymer Constants
// =============================================================================

/// Maximum lights per plane
pub const PR_MAXPLANELIGHTS = 8;

/// Maximum total lights
pub const PR_MAXLIGHTS = 128;

/// Maximum shadow maps
pub const PR_MAXSHADOWMAPS = 4;

// =============================================================================
// Material Definition
// =============================================================================

/// Polymer material structure
pub const PrMaterial = struct {
    /// Animation frame progress (0.0 - 1.0)
    frameprogress: f32 = 0.0,

    /// Pointer to next frame vertex data (for morphing)
    nextframedata: ?[*]f32 = null,

    /// Normal map texture ID
    normalmap: u32 = 0,

    /// Normal bias for normal mapping
    normalbias: [2]f32 = .{ 0.0, 0.0 },

    /// TBN matrix pointer
    tbn: ?[*]f32 = null,

    /// ART tile map (palette-indexed)
    artmap: u32 = 0,

    /// Base palette map
    basepalmap: u32 = 0,

    /// Palette lookup map
    lookupmap: u32 = 0,

    /// Shade offset
    shadeoffset: i32 = 0,

    /// Visibility
    visibility: f32 = 0.0,

    /// Diffuse map texture ID
    diffusemap: u32 = 0,

    /// Diffuse scale
    diffusescale: [2]f32 = .{ 1.0, 1.0 },

    /// Specular map texture ID
    specularmap: u32 = 0,

    /// Specular material properties (power, factor)
    specmaterial: [2]f32 = .{ 15.0, 1.0 },

    /// Mirror mode
    mirrormap: u32 = 0,

    /// Glow map texture ID
    glowmap: u32 = 0,

    /// Detail map texture ID
    detailmap: u32 = 0,

    /// Detail scale
    detailscale: [2]f32 = .{ 1.0, 1.0 },

    /// Tint color
    tintcolor: [3]f32 = .{ 1.0, 1.0, 1.0 },

    /// Flags
    flags: u32 = 0,
};

// =============================================================================
// Vertex Definition
// =============================================================================

/// Polymer vertex with position, UV, and color
pub const PrVert = extern struct {
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
// Plane Definition
// =============================================================================

/// Bucket for batched rendering
pub const PrBucket = struct {
    material: PrMaterial = .{},
    count: i32 = 0,
};

/// Polymer plane (floor, ceiling, or wall segment)
pub const PrPlane = struct {
    /// Vertex buffer
    buffer: ?[*]PrVert = null,

    /// Number of vertices
    vertcount: i32 = 0,

    /// VBO handle
    vbo: u32 = 0,

    /// Render bucket
    bucket: ?*PrBucket = null,

    /// TBN matrix (tangent, bitangent, normal)
    tbn: [3][3]f32 = .{
        .{ 1.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 1.0 },
    },

    /// Plane equation (ax + by + cz + d = 0)
    plane: [4]f32 = .{ 0.0, 1.0, 0.0, 0.0 },

    /// Material for this plane
    material: PrMaterial = .{},

    /// Index buffer
    indices: ?[*]u16 = null,

    /// Number of indices
    indicescount: i32 = 0,

    /// Lights affecting this plane
    lights: [PR_MAXPLANELIGHTS]i16 = .{-1} ** PR_MAXPLANELIGHTS,

    /// Number of lights
    lightcount: u16 = 0,
};

// =============================================================================
// Sector Definition
// =============================================================================

/// Polymer sector flags
pub const PrSectorFlags = struct {
    pub const EMPTY: u32 = 0;
    pub const UPTODATE: u32 = 1;
    pub const INVALIDTEX: u32 = 2;
};

/// Polymer sector
pub const PrSector = struct {
    /// Vertex positions
    verts: ?[*]f32 = null,

    /// Floor plane
    floor: PrPlane = .{},

    /// Ceiling plane
    ceil: PrPlane = .{},

    /// Cached sector data from BUILD
    wallptr: i16 = 0,
    wallnum: i16 = 0,
    ceilingz: i32 = 0,
    floorz: i32 = 0,

    /// Flags
    flags: PrSectorFlags = .{},
};

// =============================================================================
// Wall Definition
// =============================================================================

/// Polymer wall flags
pub const PrWallFlags = struct {
    pub const EMPTY: u32 = 0;
    pub const UPTODATE: u32 = 1;
    pub const INVALIDTEX: u32 = 2;
};

/// Polymer wall
pub const PrWall = struct {
    /// Main wall plane
    wall: PrPlane = .{},

    /// Over (upper) plane for portal walls
    over: PrPlane = .{},

    /// Mask (middle/transparent) plane
    mask: PrPlane = .{},

    /// Big portal vertices
    bigportal: ?[*]f32 = null,

    /// Extra VBO for wall components
    stuffvbo: u32 = 0,

    /// Cached wall data from BUILD
    x: i32 = 0,
    y: i32 = 0,
    point2: i16 = 0,
    nextsector: i16 = -1,
    nextwall: i16 = -1,

    /// Flags
    flags: PrWallFlags = .{},
};

// =============================================================================
// Sprite Definition
// =============================================================================

/// Polymer sprite
pub const PrSprite = struct {
    /// Sprite plane
    plane: PrPlane = .{},

    /// Hash for caching
    hash: u32 = 0,

    /// Cached sprite data
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    ang: i16 = 0,
    picnum: i16 = 0,
};

// =============================================================================
// Light Definition
// =============================================================================

/// Polymer light flags
pub const PrLightFlags = struct {
    pub const ACTIVE: u16 = 1;
    pub const INVALIDATE: u16 = 2;
    pub const NOSPECULAR: u16 = 4;
    pub const NOSHADOW: u16 = 8;
    pub const SPOTLIGHT: u16 = 16;
};

/// Polymer light
pub const PrLight = struct {
    /// Position in BUILD coordinates
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,

    /// Horiz (for spotlights)
    horiz: i16 = 0,

    /// Light range
    range: i16 = 0,

    /// Spotlight angle
    angle: i16 = 0,

    /// Fade radius
    faderadius: i16 = 0,

    /// Inner radius
    radius: i16 = 0,

    /// Light color (RGB)
    color: [3]u8 = .{ 255, 255, 255 },

    /// Render priority
    priority: u8 = 0,

    /// Tile number (for projected textures)
    tilenum: i16 = -1,

    /// Public flags
    publicflags: u16 = 0,

    /// Internal flags
    flags: u16 = 0,

    /// Projection matrix (for shadow mapping)
    projection: [16]f32 = undefined,

    /// Render target index
    rtindex: u32 = 0,

    /// Sector containing this light
    sector: i16 = -1,

    /// Cached position in float
    fx: f32 = 0.0,
    fy: f32 = 0.0,
    fz: f32 = 0.0,

    /// Cached color in float
    fr: f32 = 1.0,
    fg: f32 = 1.0,
    fb: f32 = 1.0,
};

// =============================================================================
// Program Info
// =============================================================================

/// Polymer shader program info
pub const PrProgramInfo = struct {
    /// Shader program handle
    handle: u32 = 0,

    /// Program bits (feature flags)
    bits: u32 = 0,

    /// Uniform locations
    uniform_texturePosSize: i32 = -1,
    uniform_halfTexelSize: i32 = -1,
    uniform_tintOverlay: i32 = -1,
    uniform_tintColor: i32 = -1,
    uniform_brightness: i32 = -1,
    uniform_contrast: i32 = -1,
    uniform_saturation: i32 = -1,
    uniform_visibility: i32 = -1,
    uniform_fogRange: i32 = -1,
    uniform_fogColor: i32 = -1,

    // Light uniforms
    uniform_lightPos: i32 = -1,
    uniform_lightColor: i32 = -1,
    uniform_lightRange: i32 = -1,

    // Shadow uniforms
    uniform_shadowMatrix: i32 = -1,
    uniform_shadowMap: i32 = -1,
};

// =============================================================================
// Tests
// =============================================================================

test "PrVert size" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(PrVert));
}

test "PrLight initialization" {
    const light = PrLight{};
    try std.testing.expectEqual(@as(i32, 0), light.x);
    try std.testing.expectEqual(@as(i16, 0), light.range);
    try std.testing.expectEqual(@as(u8, 255), light.color[0]);
}

test "PrMaterial initialization" {
    const mat = PrMaterial{};
    try std.testing.expectEqual(@as(f32, 0.0), mat.frameprogress);
    try std.testing.expectEqual(@as(f32, 1.0), mat.diffusescale[0]);
}
