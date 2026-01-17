//! BUILD Engine Rendering Port to Zig
//!
//! This is a 1:1 port of the NBlood/BUILD engine rendering system.
//! The goal is to maintain exact functionality and visual output.
//!
//! Main modules:
//! - types: Core data structures (Sector, Wall, Sprite)
//! - constants: Engine limits and constants
//! - enums: Flag definitions and enumerations
//! - globals: Global state arrays and variables
//! - gl: OpenGL abstraction layer
//! - engine: Core rendering functions (to be implemented)
//! - polymost: Polymost renderer (to be implemented)
//! - polymer: Polymer renderer (to be implemented)

const std = @import("std");

// =============================================================================
// Public Module Exports
// =============================================================================

/// Core data types (Sector, Wall, Sprite, vectors)
pub const types = @import("types.zig");

/// Engine constants and limits
pub const constants = @import("constants.zig");

/// Enumerations and flags
pub const enums = @import("enums.zig");

/// Global state (sector/wall/sprite arrays, rendering state)
pub const globals = @import("globals.zig");

/// OpenGL abstraction layer
pub const gl = struct {
    pub const state = @import("gl/state.zig");
    pub const bindings = @import("gl/bindings.zig");
};

/// Engine core rendering
pub const engine = struct {
    pub const render = @import("engine/render.zig");
    pub const draw2d = @import("engine/draw2d.zig");
    pub const view = @import("engine/view.zig");
    pub const sprite = @import("engine/sprite.zig");
    pub const rotatesprite = @import("engine/rotatesprite.zig");
    pub const yax = @import("engine/yax.zig");
};

/// Polymost renderer (OpenGL 1.x/2.0)
pub const polymost = struct {
    pub const render = @import("polymost/render.zig");
    pub const texture = @import("polymost/texture.zig");
    pub const ptypes = @import("polymost/types.zig");
    pub const state = @import("polymost/state.zig");
    pub const buffer = @import("polymost/buffer.zig");
};

/// Polymer renderer (Advanced OpenGL with dynamic lighting)
pub const polymer = struct {
    pub const render = @import("polymer/render.zig");
    pub const lights = @import("polymer/lights.zig");
    pub const ptypes = @import("polymer/types.zig");
};

// =============================================================================
// Re-exported Types for Convenience
// =============================================================================

pub const SectorType = types.SectorType;
pub const WallType = types.WallType;
pub const SpriteType = types.SpriteType;
pub const TSpriteType = types.TSpriteType;
pub const Vec2 = types.Vec2;
pub const Vec3 = types.Vec3;
pub const Vec2f = types.Vec2f;
pub const Vec3f = types.Vec3f;
pub const Vec4f = types.Vec4f;
pub const HitData = types.HitData;
pub const Fix16 = types.Fix16;

// =============================================================================
// Re-exported Constants
// =============================================================================

pub const MAXSECTORS = constants.MAXSECTORS;
pub const MAXWALLS = constants.MAXWALLS;
pub const MAXSPRITES = constants.MAXSPRITES;
pub const MAXTILES = constants.MAXTILES;
pub const MAXSPRITESONSCREEN = constants.MAXSPRITESONSCREEN;

// =============================================================================
// Re-exported Enums
// =============================================================================

pub const RendMode = enums.RendMode;
pub const CstatSprite = enums.CstatSprite;
pub const CstatWall = enums.CstatWall;
pub const RSFlags = enums.RSFlags;

// =============================================================================
// Global State Accessors
// =============================================================================

/// Access to sector array
pub const sector = &globals.sector;

/// Access to wall array
pub const wall = &globals.wall;

/// Access to sprite array
pub const sprite = &globals.sprite;

/// Access to temporary sprite array (for rendering)
pub const tsprite = &globals.tsprite;

/// Number of sectors in current map
pub fn getNumSectors() i32 {
    return globals.numsectors;
}

/// Number of walls in current map
pub fn getNumWalls() i32 {
    return globals.numwalls;
}

/// Number of sprites in current map
pub fn getNumSprites() i32 {
    return globals.Numsprites;
}

// =============================================================================
// Initialization
// =============================================================================

/// Initialize the BUILD engine
pub fn init() void {
    globals.initGlobals();
    globals.initSinTable();
}

/// Shutdown the BUILD engine
pub fn deinit() void {
    // Future: cleanup GL resources, free allocations
}

// =============================================================================
// Fixed-Point Utilities
// =============================================================================

pub const fix16FromInt = types.fix16FromInt;
pub const fix16ToInt = types.fix16ToInt;
pub const fix16ToFloat = types.fix16ToFloat;
pub const fix16FromFloat = types.fix16FromFloat;

// =============================================================================
// Trigonometry
// =============================================================================

/// Get sine value (angle in BUILD units, 2048 = 360 degrees)
pub const getSin = globals.getSin;

/// Get cosine value (angle in BUILD units)
pub const getCos = globals.getCos;

// =============================================================================
// Validation
// =============================================================================

pub const isValidSector = globals.isValidSector;
pub const isValidWall = globals.isValidWall;
pub const isValidSprite = globals.isValidSprite;

// =============================================================================
// Tests
// =============================================================================

test {
    // Import test modules that don't require GL
    _ = @import("types.zig");
    _ = @import("constants.zig");
    _ = @import("enums.zig");
    _ = @import("globals.zig");
    // Engine modules without GL dependencies
    _ = @import("engine/sprite.zig");
    _ = @import("engine/yax.zig");
    // Polymost types (no GL dependencies)
    _ = @import("polymost/types.zig");
    // Polymer types and lights (minimal GL dependencies in tests)
    _ = @import("polymer/types.zig");
    _ = @import("polymer/lights.zig");
    // Note: The following modules require GL context and are tested separately:
    // - gl/state.zig
    // - engine/render.zig, view.zig, rotatesprite.zig
    // - polymost/render.zig, texture.zig, state.zig, buffer.zig
    // - polymer/render.zig
}

test "initialization" {
    init();
    try std.testing.expectEqual(@as(i32, 0), getNumSectors());
    try std.testing.expectEqual(@as(i32, 0), getNumWalls());
    try std.testing.expectEqual(@as(i32, 0), getNumSprites());
}

test "struct sizes match C ABI" {
    // These sizes must match the original C structures exactly
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(SectorType));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(WallType));
    try std.testing.expectEqual(@as(usize, 44), @sizeOf(SpriteType));
    try std.testing.expectEqual(@as(usize, 44), @sizeOf(TSpriteType));
}

test "trig functions" {
    init();
    // sin(0) = 0
    try std.testing.expectEqual(@as(i16, 0), getSin(0));
    // cos(0) = max (16383)
    try std.testing.expect(getCos(0) > 16380);
    // sin(512) = max (90 degrees)
    try std.testing.expect(getSin(512) > 16380);
    // cos(512) = 0 (90 degrees)
    try std.testing.expect(@abs(getCos(512)) < 10);
}
