//! View and Render Target Management
//! Port from: NBlood/source/build/src/engine.cpp (view-related functions)
//!
//! This module handles viewport setup, aspect ratio, render targets,
//! and mirror rendering functionality.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");

// =============================================================================
// View State
// =============================================================================

/// Current viewable area
pub var viewingRange: i32 = 65536;
pub var yxAspect: i32 = 65536;

/// Roll angle for view tilting
pub var rollAngle: i32 = 0;

/// Render target stack for rendering to textures
const MAX_RENDER_TARGETS = 4;
var renderTargetStack: [MAX_RENDER_TARGETS]RenderTarget = undefined;
var renderTargetDepth: usize = 0;

const RenderTarget = struct {
    tilenume: i16 = 0,
    xsiz: i32 = 0,
    ysiz: i32 = 0,
    bakxdim: i32 = 0,
    bakydim: i32 = 0,
    bakwindowxy1: types.Vec2 = .{ .x = 0, .y = 0 },
    bakwindowxy2: types.Vec2 = .{ .x = 0, .y = 0 },
    bakframeplace: isize = 0,
};

/// Mirror state
var mirrorsx1: i32 = 0;
var mirrorsy1: i32 = 0;
var mirrorsx2: i32 = 0;
var mirrorsy2: i32 = 0;
var mirrorang: types.Fix16 = 0;
var mirrorhoriz: types.Fix16 = 0;

// =============================================================================
// Aspect Ratio
// =============================================================================

/// Set the aspect ratio for rendering
/// daxrange: horizontal viewing range (65536 = normal)
/// daaspect: y/x aspect ratio (65536 = normal)
pub fn renderSetAspect(daxrange: i32, daaspect: i32) void {
    viewingRange = daxrange;
    yxAspect = daaspect;

    globals.viewingrange = daxrange;
    globals.yxaspect = daaspect;
}

/// Calculate corrected aspect ratio based on screen dimensions
pub fn videoSetCorrectedAspect() void {
    const xdim = globals.xdim;
    const ydim = globals.ydim;

    if (xdim > 0 and ydim > 0) {
        // Standard 4:3 reference
        const ratio = @as(f32, @floatFromInt(ydim)) / @as(f32, @floatFromInt(xdim));
        const refRatio: f32 = 3.0 / 4.0;

        if (ratio > refRatio) {
            // Taller than 4:3
            yxAspect = @intFromFloat(65536.0 * ratio / refRatio);
        } else {
            yxAspect = 65536;
        }
    }
}

// =============================================================================
// Viewable Area
// =============================================================================

/// Set the viewable area (clipping rectangle)
pub fn videoSetViewableArea(x1: i32, y1: i32, x2: i32, y2: i32) void {
    globals.windowxy1.x = @max(0, x1);
    globals.windowxy1.y = @max(0, y1);
    globals.windowxy2.x = @min(globals.xdim - 1, x2);
    globals.windowxy2.y = @min(globals.ydim - 1, y2);

    // Update GL viewport if in GL mode
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        const vx = globals.windowxy1.x;
        const vy = globals.ydim - 1 - globals.windowxy2.y; // Flip Y for GL
        const vw = globals.windowxy2.x - globals.windowxy1.x + 1;
        const vh = globals.windowxy2.y - globals.windowxy1.y + 1;

        gl_state.setViewport(vx, vy, vw, vh);
    }
}

// =============================================================================
// Render Targets
// =============================================================================

/// Set up rendering to a tile (texture)
pub fn renderSetTarget(tilenume: i16, xsiz: i32, ysiz: i32) void {
    if (renderTargetDepth >= MAX_RENDER_TARGETS) {
        return; // Stack overflow protection
    }

    // Save current state
    var target = &renderTargetStack[renderTargetDepth];
    target.tilenume = tilenume;
    target.xsiz = xsiz;
    target.ysiz = ysiz;
    target.bakxdim = globals.xdim;
    target.bakydim = globals.ydim;
    target.bakwindowxy1 = globals.windowxy1;
    target.bakwindowxy2 = globals.windowxy2;
    target.bakframeplace = globals.frameplace;

    renderTargetDepth += 1;

    // Set new dimensions for rendering to tile
    globals.xdim = xsiz;
    globals.ydim = ysiz;
    globals.windowxy1 = .{ .x = 0, .y = 0 };
    globals.windowxy2 = .{ .x = xsiz - 1, .y = ysiz - 1 };

    // In GL mode, we would set up an FBO here
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        gl_state.setViewport(0, 0, xsiz, ysiz);
    }
}

/// Restore previous render target
pub fn renderRestoreTarget() void {
    if (renderTargetDepth == 0) {
        return; // Stack underflow protection
    }

    renderTargetDepth -= 1;
    const target = &renderTargetStack[renderTargetDepth];

    // Restore previous state
    globals.xdim = target.bakxdim;
    globals.ydim = target.bakydim;
    globals.windowxy1 = target.bakwindowxy1;
    globals.windowxy2 = target.bakwindowxy2;
    globals.frameplace = target.bakframeplace;

    // Restore GL viewport
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        const vx = globals.windowxy1.x;
        const vy = globals.ydim - 1 - globals.windowxy2.y;
        const vw = globals.windowxy2.x - globals.windowxy1.x + 1;
        const vh = globals.windowxy2.y - globals.windowxy1.y + 1;

        gl_state.setViewport(vx, vy, vw, vh);
    }
}

// =============================================================================
// Roll Angle
// =============================================================================

/// Set the roll angle for tilted view
pub fn renderSetRollAngle(rolla: i32) void {
    rollAngle = rolla;
}

/// Get the current roll angle
pub fn getRollAngle() i32 {
    return rollAngle;
}

// =============================================================================
// Permanent Sprites
// =============================================================================

/// Flush permanent (cached) sprites
pub fn renderFlushPerms() void {
    // In the original engine, this clears cached rotatesprite calls
    // For now, this is a no-op as we render immediately
}

// =============================================================================
// Mirror Rendering
// =============================================================================

/// Prepare for mirror rendering
/// Returns the mirrored position and angle
pub fn renderPrepareMirror(
    dax: i32,
    day: i32,
    daz: i32,
    daang: types.Fix16,
    dahoriz: types.Fix16,
    dawall: i16,
    tposx: *i32,
    tposy: *i32,
    tang: *types.Fix16,
) void {
    _ = daz;

    // Get the wall endpoints
    const w = &globals.wall[@intCast(dawall)];
    const w2 = &globals.wall[@intCast(w.point2)];

    const dx = w2.x - w.x;
    const dy = w2.y - w.y;

    // Calculate the mirrored position
    const px = dax - w.x;
    const py = day - w.y;

    // Project point onto wall line
    const t = @divTrunc(px * dx + py * dy, dx * dx + dy * dy + 1);

    // Mirror across the wall
    tposx.* = w.x + 2 * t * dx - px;
    tposy.* = w.y + 2 * t * dy - py;

    // Calculate mirrored angle
    const wallang = std.math.atan2(f32, @floatFromInt(dy), @floatFromInt(dx));
    const viewang = @as(f32, @floatFromInt(daang)) / 65536.0 * std.math.pi * 2.0 / 2048.0;
    const mirang = 2.0 * wallang - viewang;
    tang.* = @intFromFloat(mirang / (std.math.pi * 2.0 / 2048.0) * 65536.0);

    // Save mirror state for completion
    mirrorsx1 = globals.windowxy1.x;
    mirrorsy1 = globals.windowxy1.y;
    mirrorsx2 = globals.windowxy2.x;
    mirrorsy2 = globals.windowxy2.y;
    mirrorang = daang;
    mirrorhoriz = dahoriz;

    // In GL mode, set up stencil or clip planes
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        // Flip the culling direction
        gl.glFrontFace(gl.GL_CW); // Clockwise becomes front
    }
}

/// Complete mirror rendering
pub fn renderCompleteMirror() void {
    // Restore normal rendering state
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        // Restore normal culling
        gl.glFrontFace(gl.GL_CCW); // Counter-clockwise is front
    }
}

// =============================================================================
// Video Mode
// =============================================================================

/// Set the video/game mode
pub fn videoSetGameMode(davidoption: u8, daupscaledxdim: i32, daupscaledydim: i32, dabpp: i32, daupscalefactor: i32) i32 {
    _ = davidoption;
    _ = dabpp;
    _ = daupscalefactor;

    globals.xdim = daupscaledxdim;
    globals.ydim = daupscaledydim;

    // Set default viewable area to full screen
    globals.windowxy1.x = 0;
    globals.windowxy1.y = 0;
    globals.windowxy2.x = globals.xdim - 1;
    globals.windowxy2.y = globals.ydim - 1;

    // Calculate aspect ratio
    videoSetCorrectedAspect();

    return 0;
}

/// Set the render mode (classic, polymost, polymer)
pub fn videoSetRenderMode(renderer: i32) i32 {
    const oldMode = globals.rendmode;
    globals.rendmode = renderer;

    if (renderer >= @intFromEnum(enums.RendMode.polymost)) {
        globals.glrendmode = renderer;
    }

    return oldMode;
}

/// Display the next frame
pub fn videoNextPage() void {
    // In a real implementation, this would swap buffers
    // For now, it's handled by the platform layer
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        gl.glFlush();
    }
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Get the current render mode
pub fn videoGetRenderMode() i32 {
    return globals.rendmode;
}

/// Check if using OpenGL rendering
pub fn isGLMode() bool {
    return globals.rendmode >= @intFromEnum(enums.RendMode.polymost);
}

/// Calculate the horizontal field of view
pub fn calculateFOV(viewDist: i32) f32 {
    // viewDist is typically viewingRange
    return 2.0 * std.math.atan(@as(f32, @floatFromInt(globals.xdim)) / (2.0 * @as(f32, @floatFromInt(viewDist))));
}

// =============================================================================
// Tests
// =============================================================================

test "aspect ratio" {
    globals.xdim = 1920;
    globals.ydim = 1080;

    renderSetAspect(65536, 65536);
    try std.testing.expectEqual(@as(i32, 65536), viewingRange);
    try std.testing.expectEqual(@as(i32, 65536), yxAspect);
}

test "viewable area" {
    globals.xdim = 640;
    globals.ydim = 480;
    globals.rendmode = 0; // Software mode for testing

    videoSetViewableArea(10, 10, 630, 470);

    try std.testing.expectEqual(@as(i32, 10), globals.windowxy1.x);
    try std.testing.expectEqual(@as(i32, 10), globals.windowxy1.y);
    try std.testing.expectEqual(@as(i32, 630), globals.windowxy2.x);
    try std.testing.expectEqual(@as(i32, 470), globals.windowxy2.y);
}

test "render target stack" {
    globals.xdim = 640;
    globals.ydim = 480;
    globals.rendmode = 0;

    // Set initial viewable area
    videoSetViewableArea(0, 0, 639, 479);

    // Push render target
    renderSetTarget(100, 256, 256);

    try std.testing.expectEqual(@as(i32, 256), globals.xdim);
    try std.testing.expectEqual(@as(i32, 256), globals.ydim);

    // Pop render target
    renderRestoreTarget();

    try std.testing.expectEqual(@as(i32, 640), globals.xdim);
    try std.testing.expectEqual(@as(i32, 480), globals.ydim);
}
