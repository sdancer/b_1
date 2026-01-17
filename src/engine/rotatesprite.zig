//! Rotatesprite - 2D Sprite Drawing
//! Port from: NBlood/source/build/src/engine.cpp (rotatesprite functions)
//!
//! This module handles 2D sprite rendering for HUD elements, menus,
//! and other screen-space graphics.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");

// =============================================================================
// Rotatesprite State
// =============================================================================

/// Current unique HUD ID for model tracking
pub var guniqhudid: i32 = 0;

// =============================================================================
// Main Rotatesprite Function
// =============================================================================

/// Draw a 2D sprite with rotation, scaling, and various effects
///
/// Parameters:
/// - sx, sy: Screen position (in 16.16 fixed point)
/// - z: Zoom level (65536 = normal)
/// - a: Angle in BUILD units (0-2047)
/// - picnum: Tile number to draw
/// - dashade: Shade level
/// - dapalnum: Palette number
/// - dastat: Status/orientation flags (RSFlags)
/// - daalpha: Alpha value (0-255)
/// - dablend: Blend mode
/// - cx1, cy1, cx2, cy2: Clipping rectangle
pub fn rotatesprite_(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
    daalpha: u8,
    dablend: u8,
    cx1: i32,
    cy1: i32,
    cx2: i32,
    cy2: i32,
) void {
    // Dispatch to appropriate renderer
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        dorotatesprite_gl(sx, sy, z, a, picnum, dashade, dapalnum, dastat, daalpha, dablend, cx1, cy1, cx2, cy2);
    } else {
        dorotatesprite_software(sx, sy, z, a, picnum, dashade, dapalnum, dastat, daalpha, dablend, cx1, cy1, cx2, cy2);
    }
}

// =============================================================================
// Convenience Wrappers
// =============================================================================

/// Standard rotatesprite without alpha/blend
pub fn rotatesprite(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
    cx1: i32,
    cy1: i32,
    cx2: i32,
    cy2: i32,
) void {
    rotatesprite_(sx, sy, z, a, picnum, dashade, dapalnum, dastat, 0, 0, cx1, cy1, cx2, cy2);
}

/// Full-screen rotatesprite (no clipping)
pub fn rotatesprite_fs(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
) void {
    rotatesprite_(sx, sy, z, a, picnum, dashade, dapalnum, dastat, 0, 0, 0, 0, globals.xdim - 1, globals.ydim - 1);
}

/// Full-screen rotatesprite with unique HUD ID
pub fn rotatesprite_fs_id(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
    uniqid: i16,
) void {
    const restore = guniqhudid;
    if (uniqid != 0) guniqhudid = uniqid;
    rotatesprite_(sx, sy, z, a, picnum, dashade, dapalnum, dastat, 0, 0, 0, 0, globals.xdim - 1, globals.ydim - 1);
    guniqhudid = restore;
}

/// Full-screen rotatesprite with alpha
pub fn rotatesprite_fs_alpha(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
    alpha: u8,
) void {
    rotatesprite_(sx, sy, z, a, picnum, dashade, dapalnum, dastat, alpha, 0, 0, 0, globals.xdim - 1, globals.ydim - 1);
}

/// Window-clipped rotatesprite
pub fn rotatesprite_win(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
) void {
    rotatesprite_(sx, sy, z, a, picnum, dashade, dapalnum, dastat, 0, 0, globals.windowxy1.x, globals.windowxy1.y, globals.windowxy2.x, globals.windowxy2.y);
}

// =============================================================================
// OpenGL Implementation
// =============================================================================

fn dorotatesprite_gl(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
    daalpha: u8,
    dablend: u8,
    cx1: i32,
    cy1: i32,
    cx2: i32,
    cy2: i32,
) void {
    _ = dablend;

    // Convert from 16.16 fixed point to float
    const fsx = @as(f32, @floatFromInt(sx)) / 65536.0;
    const fsy = @as(f32, @floatFromInt(sy)) / 65536.0;
    const fz = @as(f32, @floatFromInt(z)) / 65536.0;
    const fang = @as(f32, @floatFromInt(a)) * std.math.pi * 2.0 / 2048.0;

    // Calculate shade factor
    const shadeFactor = 1.0 - @as(f32, @floatFromInt(dashade)) / 64.0;
    const shade = std.math.clamp(shadeFactor, 0.0, 1.0);

    // Calculate alpha
    const alpha = if ((dastat & enums.RSFlags.TRANS1) != 0)
        if ((dastat & enums.RSFlags.TRANS2) != 0)
            0.33 // 33% opacity
        else
            0.66 // 66% opacity
    else
        1.0 - @as(f32, @floatFromInt(daalpha)) / 255.0;

    // Get tile dimensions (placeholder - would look up from tile data)
    var tilesizx: f32 = 64.0;
    var tilesizy: f32 = 64.0;
    _ = picnum;
    _ = dapalnum;

    // Apply zoom
    tilesizx *= fz;
    tilesizy *= fz;

    // Calculate corners based on orientation
    const centerX = if ((dastat & enums.RSFlags.TOPLEFT) != 0) fsx else fsx;
    const centerY = if ((dastat & enums.RSFlags.TOPLEFT) != 0) fsy else fsy;

    // Calculate rotated corners
    const cos_a = @cos(fang);
    const sin_a = @sin(fang);

    const hw = tilesizx / 2.0;
    const hh = tilesizy / 2.0;

    var corners: [4][2]f32 = undefined;

    if ((dastat & enums.RSFlags.TOPLEFT) != 0) {
        // Top-left origin
        corners[0] = .{ centerX, centerY };
        corners[1] = .{ centerX + tilesizx, centerY };
        corners[2] = .{ centerX + tilesizx, centerY + tilesizy };
        corners[3] = .{ centerX, centerY + tilesizy };
    } else {
        // Center origin with rotation
        const pts = [4][2]f32{
            .{ -hw, -hh },
            .{ hw, -hh },
            .{ hw, hh },
            .{ -hw, hh },
        };

        for (0..4) |i| {
            const rx = pts[i][0] * cos_a - pts[i][1] * sin_a;
            const ry = pts[i][0] * sin_a + pts[i][1] * cos_a;
            corners[i] = .{ centerX + rx, centerY + ry };
        }
    }

    // Apply flips
    const tex_u0: f32 = 0.0;
    const tex_u1: f32 = 1.0;
    const tex_v0: f32 = if ((dastat & enums.RSFlags.YFLIP) != 0) 1.0 else 0.0;
    const tex_v1: f32 = if ((dastat & enums.RSFlags.YFLIP) != 0) 0.0 else 1.0;

    // Set up clipping
    gl.glEnable(gl.GL_SCISSOR_TEST);
    gl.glScissor(cx1, globals.ydim - 1 - cy2, cx2 - cx1 + 1, cy2 - cy1 + 1);

    // Set up blending
    if ((dastat & enums.RSFlags.TRANS_MASK) != 0 or daalpha > 0) {
        gl_state.setEnabled(gl_state.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    } else {
        gl_state.setDisabled(gl_state.GL_BLEND);
    }

    // Disable depth test for 2D
    gl_state.setDisabled(gl_state.GL_DEPTH_TEST);

    // Draw the quad
    gl.glColor4f(shade, shade, shade, alpha);
    gl.glBegin(gl.GL_QUADS);

    gl.glTexCoord2f(tex_u0, tex_v0);
    gl.glVertex2f(corners[0][0], corners[0][1]);

    gl.glTexCoord2f(tex_u1, tex_v0);
    gl.glVertex2f(corners[1][0], corners[1][1]);

    gl.glTexCoord2f(tex_u1, tex_v1);
    gl.glVertex2f(corners[2][0], corners[2][1]);

    gl.glTexCoord2f(tex_u0, tex_v1);
    gl.glVertex2f(corners[3][0], corners[3][1]);

    gl.glEnd();

    // Restore state
    gl.glDisable(gl.GL_SCISSOR_TEST);
}

// =============================================================================
// Software Implementation (placeholder)
// =============================================================================

fn dorotatesprite_software(
    sx: i32,
    sy: i32,
    z: i32,
    a: i16,
    picnum: i16,
    dashade: i8,
    dapalnum: u8,
    dastat: i32,
    daalpha: u8,
    dablend: u8,
    cx1: i32,
    cy1: i32,
    cx2: i32,
    cy2: i32,
) void {
    // Software rendering would go here
    // For now, this is a placeholder that draws a simple rectangle
    _ = picnum;
    _ = dashade;
    _ = dapalnum;
    _ = dastat;
    _ = daalpha;
    _ = dablend;
    _ = a;

    const x = sx >> 16;
    const y = sy >> 16;
    const size = @as(i32, @intCast(z >> 10)); // Approximate size

    // Clamp to clipping rectangle
    const x1 = @max(cx1, x - size / 2);
    const y1 = @max(cy1, y - size / 2);
    const x2 = @min(cx2, x + size / 2);
    const y2 = @min(cy2, y + size / 2);

    // Draw a simple rectangle (placeholder)
    if (globals.frameplace != 0 and x1 < x2 and y1 < y2) {
        const ptr: [*]u8 = @ptrFromInt(@as(usize, @intCast(globals.frameplace)));
        const bpl = @as(usize, @intCast(globals.bytesperline));

        for (@as(usize, @intCast(y1))..@as(usize, @intCast(y2))) |py| {
            for (@as(usize, @intCast(x1))..@as(usize, @intCast(x2))) |px| {
                ptr[py * bpl + px] = 31; // White in standard palette
            }
        }
    }
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Calculate screen position from world coordinates (simplified)
pub fn calcScreenPos(x: i32, y: i32, z: i32, viewx: i32, viewy: i32, viewz: i32, viewang: i16) types.Vec2 {
    _ = z;
    _ = viewz;

    const dx = x - viewx;
    const dy = y - viewy;

    const cos_a = globals.getCos(viewang);
    const sin_a = globals.getSin(viewang);

    const rx = @divTrunc(dx * cos_a - dy * sin_a, 16384);
    const ry = @divTrunc(dx * sin_a + dy * cos_a, 16384);

    // Project to screen (simplified)
    const sx = globals.xdim / 2 + @divTrunc(rx * globals.xdim, ry + 1);
    const sy = globals.ydim / 2;

    return .{ .x = sx, .y = sy };
}

/// Check if a point is within the clipping rectangle
pub fn isPointInClip(x: i32, y: i32, cx1: i32, cy1: i32, cx2: i32, cy2: i32) bool {
    return x >= cx1 and x <= cx2 and y >= cy1 and y <= cy2;
}

/// Interpolate between two screen positions
pub fn lerpScreenPos(p1: types.Vec2, p2: types.Vec2, t: f32) types.Vec2 {
    return .{
        .x = p1.x + @as(i32, @intFromFloat(@as(f32, @floatFromInt(p2.x - p1.x)) * t)),
        .y = p1.y + @as(i32, @intFromFloat(@as(f32, @floatFromInt(p2.y - p1.y)) * t)),
    };
}

// =============================================================================
// Tests
// =============================================================================

test "rotatesprite flag constants" {
    try std.testing.expectEqual(@as(u32, 1), enums.RSFlags.TRANS1);
    try std.testing.expectEqual(@as(u32, 32), enums.RSFlags.TRANS2);
    try std.testing.expectEqual(@as(u32, 33), enums.RSFlags.TRANS_MASK);
}

test "point in clip" {
    try std.testing.expect(isPointInClip(50, 50, 0, 0, 100, 100));
    try std.testing.expect(!isPointInClip(150, 50, 0, 0, 100, 100));
    try std.testing.expect(!isPointInClip(50, 150, 0, 0, 100, 100));
}

test "lerp screen pos" {
    const p1: types.Vec2 = .{ .x = 0, .y = 0 };
    const p2: types.Vec2 = .{ .x = 100, .y = 200 };

    const mid = lerpScreenPos(p1, p2, 0.5);
    try std.testing.expectEqual(@as(i32, 50), mid.x);
    try std.testing.expectEqual(@as(i32, 100), mid.y);
}
