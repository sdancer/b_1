//! BUILD Engine Constants and Limits
//! Port from: NBlood/source/build/include/build.h (lines 48-114)

const std = @import("std");

// =============================================================================
// Core Limits (V8 format - default)
// =============================================================================

pub const MAXSECTORS_V8: usize = 4096;
pub const MAXWALLS_V8: usize = 16384;
pub const MAXSPRITES_V8: usize = 16384;

// V7 format (legacy)
pub const MAXSECTORS_V7: usize = 1024;
pub const MAXWALLS_V7: usize = 8192;
pub const MAXSPRITES_V7: usize = 4096;

// Use V8 limits by default
pub const MAXSECTORS: usize = MAXSECTORS_V8;
pub const MAXWALLS: usize = MAXWALLS_V8;
pub const MAXSPRITES: usize = MAXSPRITES_V8;

// Derived limits
pub const MAXWALLSB: usize = MAXWALLS >> 1;

// =============================================================================
// Display Limits
// =============================================================================

pub const MAXXDIM: i32 = 10240;
pub const MAXYDIM: i32 = 4320;
pub const MINXDIM: i32 = 640;
pub const MINYDIM: i32 = 480;

// =============================================================================
// Tile/Texture Limits
// =============================================================================

pub const MAXTILES: usize = 30720;
pub const MAXUSERTILES: usize = MAXTILES - 256; // reserve 256 tiles at the end

// =============================================================================
// Entity Limits
// =============================================================================

pub const MAXVOXELS: usize = 2048;
pub const MAXVOXMIPS: usize = 5;
pub const MAXSTATUS: usize = 1024;
pub const MAXPLAYERS: usize = 16;
pub const MAXSPRITESONSCREEN: usize = 4096;
pub const MAXUNIQHUDID: usize = 256; // Extra slots for HUD models

// =============================================================================
// Palette Limits
// =============================================================================

pub const MAXPALOOKUPS: usize = 256;
pub const MAXBLENDTABS: usize = 256;

// =============================================================================
// Sky Limits
// =============================================================================

pub const MAXPSKYTILES: usize = 16; // Maximum tiles in a multi-psky

// =============================================================================
// YAX (True Room Over Room) Limits
// =============================================================================

pub const YAX_MAXBUNCHES: usize = 256;
pub const YAX_CEILING: i16 = 0;
pub const YAX_FLOOR: i16 = 1;
pub const YAX_BIT: u16 = 1024;

// =============================================================================
// Editor Limits
// =============================================================================

pub const M32_FIXME_WALLS: usize = 512;
pub const M32_FIXME_SECTORS: usize = 2;

// =============================================================================
// Light Priority Levels
// =============================================================================

pub const PR_LIGHT_PRIO_MAX: i32 = 0;
pub const PR_LIGHT_PRIO_MAX_GAME: i32 = 1;
pub const PR_LIGHT_PRIO_HIGH: i32 = 2;
pub const PR_LIGHT_PRIO_HIGH_GAME: i32 = 3;
pub const PR_LIGHT_PRIO_LOW: i32 = 4;
pub const PR_LIGHT_PRIO_LOW_GAME: i32 = 5;

// =============================================================================
// Timing
// =============================================================================

pub const CLOCKTICKSPERSECOND: i32 = 120;

// =============================================================================
// Math Constants
// =============================================================================

pub const PI: f64 = 3.14159265358979323846;
pub const fPI: f32 = 3.14159265358979323846;
pub const BANG2RAD: f32 = fPI * (1.0 / 1024.0);

// =============================================================================
// Coordinate Limits
// =============================================================================

pub const BXY_MAX: i32 = 524288; // max x/y val (= max editorgridextent)

// =============================================================================
// Clip Masks
// =============================================================================

pub const CLIPMASK0: u32 = ((1 << 16) + 1);
pub const CLIPMASK1: u32 = ((256 << 16) + 64);

// =============================================================================
// Update Sector Distances
// =============================================================================

pub const MAXUPDATESECTORDIST: i32 = 1536;
pub const INITIALUPDATESECTORDIST: i32 = 256;

// =============================================================================
// Status 2D Sizes
// =============================================================================

pub const STATUS2DSIZ: i32 = 144;
pub const STATUS2DSIZ2: i32 = 26;

// =============================================================================
// Special Values
// =============================================================================

pub const TSPR_TEMP: i16 = 99;

// =============================================================================
// Sintable Size
// =============================================================================

pub const SINTABLE_SIZE: usize = 2048;

// =============================================================================
// Polymer Limits
// =============================================================================

pub const PR_MAXPLANELIGHTS: usize = 8;
pub const PR_HIGHPALOOKUP_BIT_DEPTH: usize = 6;
pub const PR_HIGHPALOOKUP_DIM: usize = 1 << PR_HIGHPALOOKUP_BIT_DEPTH;
pub const PR_HIGHPALOOKUP_DATA_SIZE: usize = 4 * PR_HIGHPALOOKUP_DIM * PR_HIGHPALOOKUP_DIM * PR_HIGHPALOOKUP_DIM;
pub const PR_INFO_LOG_BUFFER_SIZE: usize = 8192;

// =============================================================================
// OpenGL Limits
// =============================================================================

pub const MAXTEXUNIT: usize = 16;
pub const NUM_SAMPLERS: usize = 13;

// =============================================================================
// Tests
// =============================================================================

test "constant values" {
    try std.testing.expectEqual(@as(usize, 4096), MAXSECTORS);
    try std.testing.expectEqual(@as(usize, 16384), MAXWALLS);
    try std.testing.expectEqual(@as(usize, 16384), MAXSPRITES);
    try std.testing.expectEqual(@as(usize, 8192), MAXWALLSB);
    try std.testing.expectEqual(@as(usize, 30720), MAXTILES);
}
