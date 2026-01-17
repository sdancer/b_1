//! WASM Globals Wrapper
//! Provides BUILD engine global state for WASM using module imports.

const std = @import("std");
const types = @import("types");
const constants = @import("constants");

// =============================================================================
// Core Entity Arrays
// =============================================================================

/// All sectors in the map
pub var sector: [constants.MAXSECTORS + constants.M32_FIXME_SECTORS]types.SectorType = undefined;

/// All walls in the map
pub var wall: [constants.MAXWALLS + constants.M32_FIXME_WALLS]types.WallType = undefined;

/// All sprites in the map
pub var sprite: [constants.MAXSPRITES]types.SpriteType = undefined;

// =============================================================================
// Map Counts
// =============================================================================

/// Number of sectors in current map
pub var numsectors: i16 = 0;

/// Number of walls in current map
pub var numwalls: i16 = 0;

/// Number of sprites in current map
pub var numsprites: i16 = 0;

// =============================================================================
// Display Settings
// =============================================================================

/// Screen/window width
pub var xdim: i32 = 800;

/// Screen/window height
pub var ydim: i32 = 600;

/// Viewing range (for aspect ratio)
pub var viewingrange: i32 = 65536;

/// Y/X aspect ratio
pub var yxaspect: i32 = 65536;

// =============================================================================
// Camera/View Position
// =============================================================================

/// Camera X position
pub var globalposx: i32 = 0;

/// Camera Y position
pub var globalposy: i32 = 0;

/// Camera Z position (height)
pub var globalposz: i32 = 0;

/// Camera angle (0-2047)
pub var globalang: i16 = 0;

/// Camera horizon (look up/down)
pub var globalhoriz: types.Fix16 = types.fix16FromInt(100);

/// Current sector the camera is in
pub var globalcursectnum: i16 = 0;

// =============================================================================
// Trigonometry Tables
// =============================================================================

/// Sine table (0-2047, 2048 entries, 16.16 fixed point)
pub var sintable: [2048]i32 = undefined;

// =============================================================================
// Initialization
// =============================================================================

/// Initialize sine/cosine table
pub fn initSinTable() void {
    for (0..2048) |i| {
        const angle = @as(f64, @floatFromInt(i)) * std.math.pi * 2.0 / 2048.0;
        sintable[i] = @intFromFloat(@sin(angle) * 65536.0);
    }
}

/// Initialize global state
pub fn initGlobals() void {
    numsectors = 0;
    numwalls = 0;
    numsprites = 0;
    globalposx = 0;
    globalposy = 0;
    globalposz = 0;
    globalang = 0;
    globalhoriz = types.fix16FromInt(100);
    globalcursectnum = 0;
}
