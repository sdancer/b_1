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
    pub const player = @import("engine/player.zig");
};

/// Polymost renderer (OpenGL 1.x/2.0)
pub const polymost = struct {
    pub const render = @import("polymost/render.zig");
    pub const texture = @import("polymost/texture.zig");
    pub const ptypes = @import("polymost/types.zig");
    pub const state = @import("polymost/state.zig");
    pub const buffer = @import("polymost/buffer.zig");
    pub const pm_globals = @import("polymost/globals.zig");
    pub const texcoord = @import("polymost/texcoord.zig");
    pub const draw = @import("polymost/draw.zig");
};

/// Polymer renderer (Advanced OpenGL with dynamic lighting)
pub const polymer = struct {
    pub const render = @import("polymer/render.zig");
    pub const lights = @import("polymer/lights.zig");
    pub const ptypes = @import("polymer/types.zig");
};

/// File system / resource loading
pub const fs = struct {
    pub const reader = @import("fs/reader.zig");
    pub const map = @import("fs/map.zig");
    pub const art = @import("fs/art.zig");
    pub const rff = @import("fs/rff.zig");
};

/// Platform layer (SDL2, input)
pub const platform = struct {
    pub const sdl = @import("platform/sdl.zig");
    pub const input = @import("platform/input.zig");
};

/// Math utilities (fixed-point arithmetic)
pub const math = struct {
    pub const mulscale = @import("math/mulscale.zig");
};

/// Game systems (physics, posture, etc.)
pub const game = struct {
    pub const physics = @import("game/physics.zig");
    pub const posture = @import("game/posture.zig");
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
// Physics System Re-exports
// =============================================================================

/// Physics module for movement and velocity
pub const physics = @import("game/physics.zig");

/// Posture definitions for player movement
pub const posture = @import("game/posture.zig");

/// Fixed-point math functions (mulscale, etc.)
pub const mulscale = @import("math/mulscale.zig");

// =============================================================================
// File Loading
// =============================================================================

pub const loadMap = @import("fs/map.zig").loadMap;
pub const loadMapFromFile = @import("fs/map.zig").loadMapFromFile;
pub const loadBloodMap = @import("fs/map.zig").loadBloodMap;
pub const loadBuildMap = @import("fs/map.zig").loadBuildMap;
pub const MapData = @import("fs/map.zig").MapData;

pub const loadArt = @import("fs/art.zig").loadArt;
pub const loadArtFromFile = @import("fs/art.zig").loadArtFromFile;
pub const ArtData = @import("fs/art.zig").ArtData;
pub const getTileSizeX = @import("fs/art.zig").getTileSizeX;
pub const getTileSizeY = @import("fs/art.zig").getTileSizeY;
pub const isTileValid = @import("fs/art.zig").isTileValid;
pub const loadPalette = @import("fs/art.zig").loadPalette;
pub const loadPaletteFromFile = @import("fs/art.zig").loadPaletteFromFile;

pub const BinaryReader = @import("fs/reader.zig").BinaryReader;
pub const loadFile = @import("fs/reader.zig").loadFile;

pub const loadRFF = @import("fs/rff.zig").loadRFF;
pub const loadRFFFromFile = @import("fs/rff.zig").loadRFFFromFile;
pub const RFFArchive = @import("fs/rff.zig").RFFArchive;

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
    // File system / resource loading
    _ = @import("fs/reader.zig");
    _ = @import("fs/map.zig");
    _ = @import("fs/art.zig");
    _ = @import("fs/rff.zig");
    // Math utilities
    _ = @import("math/mulscale.zig");
    // Game systems (physics, posture)
    _ = @import("game/physics.zig");
    _ = @import("game/posture.zig");
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
