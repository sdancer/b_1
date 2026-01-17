//! Polymost State Management
//! Port from: NBlood/source/build/src/polymost.cpp (state functions)
//!
//! Manages rendering state for the polymost renderer including
//! shader uniforms, texture binding, and fog settings.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");
const polymost_types = @import("types.zig");

// =============================================================================
// State Variables
// =============================================================================

/// Current clamp mode
var currentClamp: u8 = 0;

/// Fog enabled state
var fogEnabled: bool = false;

/// Current fog range
var fogRange: [2]f32 = .{ 0.0, 1000.0 };

/// Current fog color
var fogColor: [4]f32 = .{ 0.0, 0.0, 0.0, 1.0 };

/// Visibility value
var currentVisibility: f32 = 1.0;

/// Half texel size for texture coordinate precision
var halfTexelSize: types.Vec2f = .{ .x = 0.0, .y = 0.0 };

/// Texture position and size
var texturePosSize: types.Vec4f = .{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 1.0 };

/// Color correction (brightness, contrast, saturation, gamma)
var colorCorrection: types.Vec4f = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 };

/// Use palette indexing
var usePaletteIndexing: bool = false;

/// Use color only (no texture)
var useColorOnly: bool = false;

/// Use detail mapping
var useDetailMapping: bool = false;

/// Use glow mapping
var useGlowMapping: bool = false;

/// Current shader program
var currentProgram: u32 = 0;

// =============================================================================
// State Functions
// =============================================================================

/// Set the texture clamp mode
pub fn polymost_setClamp(clamp: u8) void {
    if (currentClamp != clamp) {
        currentClamp = clamp;
        // Update texture parameters based on clamp mode
    }
}

/// Enable or disable fog
pub fn polymost_setFogEnabled(enabled: bool) void {
    if (fogEnabled != enabled) {
        fogEnabled = enabled;
        if (enabled) {
            gl_state.setEnabled(gl_state.GL_FOG);
        } else {
            gl_state.setDisabled(gl_state.GL_FOG);
        }
    }
}

/// Set the fog range
pub fn polymost_setFogRange(start: f32, end: f32) void {
    fogRange[0] = start;
    fogRange[1] = end;
    // Would update shader uniform here
}

/// Set the fog color
pub fn polymost_setFogColor(r: f32, g: f32, b: f32, a: f32) void {
    fogColor[0] = r;
    fogColor[1] = g;
    fogColor[2] = b;
    fogColor[3] = a;
    // Would update shader uniform here
}

/// Set the half texel size for texture coordinate precision
pub fn polymost_setHalfTexelSize(size: types.Vec2f) void {
    halfTexelSize = size;
    // Would update shader uniform here
}

/// Set the texture position and size
pub fn polymost_setTexturePosSize(posSize: types.Vec4f) void {
    texturePosSize = posSize;
    // Would update shader uniform here
}

/// Set the visibility (fog distance)
pub fn polymost_setVisibility(visibility: f32) void {
    currentVisibility = visibility;
    // Would update shader uniform here
}

/// Update the palette (after palette change)
pub fn polymost_updatePalette() void {
    // Re-upload palette texture if needed
}

/// Enable or disable color-only mode (no texture)
pub fn polymost_useColorOnly(enabled: bool) void {
    useColorOnly = enabled;
    // Would update shader uniform here
}

/// Enable or disable detail mapping
pub fn polymost_useDetailMapping(use: bool) void {
    useDetailMapping = use;
    // Would update shader uniform here
}

/// Enable or disable glow mapping
pub fn polymost_useGlowMapping(use: bool) void {
    useGlowMapping = use;
    // Would update shader uniform here
}

/// Enable or disable palette indexing
pub fn polymost_usePaletteIndexing(use: bool) void {
    usePaletteIndexing = use;
    // Would update shader uniform here
}

/// Set color correction values
pub fn polymost_setColorCorrection(correction: types.Vec4f) void {
    colorCorrection = correction;
    // Would update shader uniform here
}

/// Disable the shader program
pub fn polymost_disableProgram() void {
    if (currentProgram != 0) {
        gl_state.useShaderProgram(0);
        currentProgram = 0;
    }
}

/// Reset all polymost state
pub fn polymost_resetState() void {
    currentClamp = 0;
    fogEnabled = false;
    currentVisibility = 1.0;
    usePaletteIndexing = false;
    useColorOnly = false;
    useDetailMapping = false;
    useGlowMapping = false;
    halfTexelSize = .{ .x = 0.0, .y = 0.0 };
    texturePosSize = .{ .x = 0.0, .y = 0.0, .z = 1.0, .w = 1.0 };
    colorCorrection = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 };
}

/// Reset the shader program
pub fn polymost_resetProgram() void {
    polymost_disableProgram();
}

/// Reset vertex pointers to default
pub fn polymost_resetVertexPointers() void {
    // Reset VBO bindings
    gl_state.bindBuffer(gl.GL_ARRAY_BUFFER, 0);
    gl_state.bindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
}

// =============================================================================
// Tint Management
// =============================================================================

/// Global tints for palette modification
var globalTints: [constants.MAXPALOOKUPS]polymost_types.PolyTint = undefined;
var tintsInitialized: bool = false;

/// Initialize tint table
pub fn initTints() void {
    if (tintsInitialized) return;

    for (&globalTints) |*tint| {
        tint.* = .{ .r = 255, .g = 255, .b = 255, .flags = 0 };
    }

    tintsInitialized = true;
}

/// Set a tint for a palette
pub fn setTint(palnum: u8, r: u8, g: u8, b: u8, flags: u8) void {
    if (!tintsInitialized) initTints();

    globalTints[palnum] = .{ .r = r, .g = g, .b = b, .flags = flags };
}

/// Get a tint for a palette
pub fn getTint(palnum: u8) polymost_types.PolyTint {
    if (!tintsInitialized) initTints();

    return globalTints[palnum];
}

/// Apply tint to a color
pub fn applyTint(tint: polymost_types.PolyTint, r: *u8, g: *u8, b: *u8) void {
    if (tint.flags & polymost_types.PolyTintFlags.BLEND_MULTIPLY != 0) {
        r.* = @intCast((@as(u16, r.*) * @as(u16, tint.r)) / 255);
        g.* = @intCast((@as(u16, g.*) * @as(u16, tint.g)) / 255);
        b.* = @intCast((@as(u16, b.*) * @as(u16, tint.b)) / 255);
    }
}

// =============================================================================
// Getters for State
// =============================================================================

/// Get current visibility
pub fn getVisibility() f32 {
    return currentVisibility;
}

/// Get fog enabled state
pub fn isFogEnabled() bool {
    return fogEnabled;
}

/// Get current clamp mode
pub fn getClampMode() u8 {
    return currentClamp;
}

/// Check if palette indexing is enabled
pub fn isPaletteIndexingEnabled() bool {
    return usePaletteIndexing;
}

/// Check if color-only mode is enabled
pub fn isColorOnlyEnabled() bool {
    return useColorOnly;
}

// =============================================================================
// Tests
// =============================================================================

test "state reset" {
    polymost_setVisibility(0.5);
    polymost_setFogEnabled(true);
    polymost_useColorOnly(true);

    polymost_resetState();

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getVisibility(), 0.01);
    try std.testing.expect(!isFogEnabled());
    try std.testing.expect(!isColorOnlyEnabled());
}

test "clamp mode" {
    polymost_setClamp(1);
    try std.testing.expectEqual(@as(u8, 1), getClampMode());

    polymost_setClamp(0);
    try std.testing.expectEqual(@as(u8, 0), getClampMode());
}

test "tint initialization" {
    initTints();

    const tint = getTint(0);
    try std.testing.expectEqual(@as(u8, 255), tint.r);
    try std.testing.expectEqual(@as(u8, 255), tint.g);
    try std.testing.expectEqual(@as(u8, 255), tint.b);
}

test "tint application" {
    var r: u8 = 200;
    var g: u8 = 100;
    var b: u8 = 50;

    const tint = polymost_types.PolyTint{
        .r = 128,
        .g = 255,
        .b = 255,
        .flags = polymost_types.PolyTintFlags.BLEND_MULTIPLY,
    };

    applyTint(tint, &r, &g, &b);

    // 200 * 128 / 255 ≈ 100
    try std.testing.expect(r < 110 and r > 90);
    // 100 * 255 / 255 = 100
    try std.testing.expectEqual(@as(u8, 100), g);
    // 50 * 255 / 255 = 50
    try std.testing.expectEqual(@as(u8, 50), b);
}
