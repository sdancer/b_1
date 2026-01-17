//! 2D Drawing Primitives
//! Port from: NBlood/source/build/src/2d.cpp
//!
//! This module provides basic 2D drawing functions for lines, pixels,
//! and text rendering used by the BUILD engine.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");

// =============================================================================
// Drawing State
// =============================================================================

/// Current drawing color
var drawColor: types.Palette = .{ .r = 255, .g = 255, .b = 255, .f = 255 };

// =============================================================================
// Pixel Operations
// =============================================================================

/// Plot a single pixel at (x, y) with the given color index
pub fn plotpixel(x: i32, y: i32, col: u8) void {
    if (x < 0 or y < 0) return;
    if (x >= globals.xdim or y >= globals.ydim) return;

    if (globals.frameplace != 0) {
        const offset = @as(usize, @intCast(y)) * @as(usize, @intCast(globals.bytesperline)) + @as(usize, @intCast(x));
        const ptr: [*]u8 = @ptrFromInt(@as(usize, @intCast(globals.frameplace)));
        ptr[offset] = col;
    }
}

/// Get the pixel value at (x, y)
pub fn getpixel(x: i32, y: i32) u8 {
    if (x < 0 or y < 0) return 0;
    if (x >= globals.xdim or y >= globals.ydim) return 0;

    if (globals.frameplace != 0) {
        const offset = @as(usize, @intCast(y)) * @as(usize, @intCast(globals.bytesperline)) + @as(usize, @intCast(x));
        const ptr: [*]const u8 = @ptrFromInt(@as(usize, @intCast(globals.frameplace)));
        return ptr[offset];
    }
    return 0;
}

// =============================================================================
// Line Drawing
// =============================================================================

/// Draw a line from (x1, y1) to (x2, y2) with a palette color index
pub fn renderDrawLine(x1: i32, y1: i32, x2: i32, y2: i32, col: u8) void {
    // Use Bresenham's line algorithm
    var px1 = x1;
    var py1 = y1;
    const px2 = x2;
    const py2 = y2;

    const dx = if (px2 > px1) px2 - px1 else px1 - px2;
    const dy = if (py2 > py1) py2 - py1 else py1 - py2;

    const sx: i32 = if (px1 < px2) 1 else -1;
    const sy: i32 = if (py1 < py2) 1 else -1;

    var err = dx - dy;

    while (true) {
        plotpixel(px1, py1, col);

        if (px1 == px2 and py1 == py2) break;

        const e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            px1 += sx;
        }
        if (e2 < dx) {
            err += dx;
            py1 += sy;
        }
    }
}

/// Draw a line with RGB color
pub fn drawlinergb(x1: i32, y1: i32, x2: i32, y2: i32, p: types.Palette) void {
    // For GL rendering, we draw directly with the color
    if (globals.rendmode >= @intFromEnum(@import("../enums.zig").RendMode.polymost)) {
        drawlinegl(x1, y1, x2, y2, p);
    } else {
        // Software mode: find closest palette color
        const col = findClosestColor(p.r, p.g, p.b);
        renderDrawLine(x1, y1, x2, y2, col);
    }
}

/// Draw a line using OpenGL
fn drawlinegl(x1: i32, y1: i32, x2: i32, y2: i32, p: types.Palette) void {
    const fx1 = @as(f32, @floatFromInt(x1));
    const fy1 = @as(f32, @floatFromInt(y1));
    const fx2 = @as(f32, @floatFromInt(x2));
    const fy2 = @as(f32, @floatFromInt(y2));

    gl_state.setDisabled(gl_state.GL_TEXTURE_2D);
    gl_state.setDisabled(gl_state.GL_BLEND);

    gl.glColor4ub(p.r, p.g, p.b, 255);
    gl.glBegin(gl.GL_LINES);
    gl.glVertex2f(fx1, fy1);
    gl.glVertex2f(fx2, fy2);
    gl.glEnd();
}

/// Draw multiple connected lines (polygon outline)
pub fn plotlines2d(xx: []const i32, yy: []const i32, col: u8) void {
    if (xx.len < 2) return;

    for (0..xx.len - 1) |i| {
        renderDrawLine(xx[i], yy[i], xx[i + 1], yy[i + 1], col);
    }
    // Close the polygon
    renderDrawLine(xx[xx.len - 1], yy[yy.len - 1], xx[0], yy[0], col);
}

// =============================================================================
// Screen Clearing
// =============================================================================

/// Clear the viewable area with a color
pub fn videoClearViewableArea(dacol: i32) void {
    const col: u8 = @truncate(@as(u32, @intCast(dacol)));

    if (globals.rendmode >= @intFromEnum(@import("../enums.zig").RendMode.polymost)) {
        // GL mode: use glClear
        const r = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 0])) / 63.0;
        const g = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 1])) / 63.0;
        const b = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 2])) / 63.0;

        gl.glClearColor(r, g, b, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
    } else {
        // Software mode: fill framebuffer
        clearSoftware(globals.windowxy1.x, globals.windowxy1.y, globals.windowxy2.x, globals.windowxy2.y, col);
    }
}

/// Clear the entire screen with a color
pub fn videoClearScreen(dacol: i32) void {
    const col: u8 = @truncate(@as(u32, @intCast(dacol)));

    if (globals.rendmode >= @intFromEnum(@import("../enums.zig").RendMode.polymost)) {
        const r = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 0])) / 63.0;
        const g = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 1])) / 63.0;
        const b = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 2])) / 63.0;

        gl.glClearColor(r, g, b, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
    } else {
        clearSoftware(0, 0, globals.xdim - 1, globals.ydim - 1, col);
    }
}

/// Software mode screen clear
fn clearSoftware(x1: i32, y1: i32, x2: i32, y2: i32, col: u8) void {
    if (globals.frameplace == 0) return;

    const ptr: [*]u8 = @ptrFromInt(@as(usize, @intCast(globals.frameplace)));
    const bpl = @as(usize, @intCast(globals.bytesperline));

    const sy = @as(usize, @intCast(@max(0, y1)));
    const ey = @as(usize, @intCast(@min(globals.ydim - 1, y2)));
    const sx = @as(usize, @intCast(@max(0, x1)));
    const ex = @as(usize, @intCast(@min(globals.xdim - 1, x2)));

    for (sy..ey + 1) |y| {
        const row_start = y * bpl + sx;
        const row_end = y * bpl + ex + 1;
        @memset(ptr[row_start..row_end], col);
    }
}

// =============================================================================
// Rectangle Drawing
// =============================================================================

/// Fill a rectangle with a color
pub fn fillrect(x1: i32, y1: i32, x2: i32, y2: i32, col: u8) void {
    if (globals.rendmode >= @intFromEnum(@import("../enums.zig").RendMode.polymost)) {
        fillrectgl(x1, y1, x2, y2, col);
    } else {
        clearSoftware(x1, y1, x2, y2, col);
    }
}

fn fillrectgl(x1: i32, y1: i32, x2: i32, y2: i32, col: u8) void {
    const r = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 0])) / 63.0;
    const g = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 1])) / 63.0;
    const b = @as(f32, @floatFromInt(globals.palette[@as(usize, col) * 3 + 2])) / 63.0;

    const fx1 = @as(f32, @floatFromInt(x1));
    const fy1 = @as(f32, @floatFromInt(y1));
    const fx2 = @as(f32, @floatFromInt(x2));
    const fy2 = @as(f32, @floatFromInt(y2));

    gl_state.setDisabled(gl_state.GL_TEXTURE_2D);
    gl_state.setDisabled(gl_state.GL_BLEND);

    gl.glColor3f(r, g, b);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx1, fy1);
    gl.glVertex2f(fx2, fy1);
    gl.glVertex2f(fx2, fy2);
    gl.glVertex2f(fx1, fy2);
    gl.glEnd();
}

// =============================================================================
// Text Rendering
// =============================================================================

// 8x8 font data (simplified - first 128 chars)
// This would normally be loaded from the game's font tiles
var fontLoaded: bool = false;

/// Print text at position using 8x8 font
pub fn printext256(xpos: i32, ypos: i32, col: i16, backcol: i16, name: []const u8, fontsize: u8) void {
    _ = fontsize;
    var x = xpos;

    for (name) |char| {
        if (char == '\n') {
            // Newline not handled in basic version
            continue;
        }

        // Draw character background if backcol >= 0
        if (backcol >= 0) {
            fillrect(x, ypos, x + 7, ypos + 7, @truncate(@as(u16, @intCast(backcol))));
        }

        // For now, just draw a placeholder box for each character
        if (col >= 0) {
            const c: u8 = @truncate(@as(u16, @intCast(col)));
            // Simple character representation - draw outline
            renderDrawLine(x, ypos, x + 6, ypos, c);
            renderDrawLine(x, ypos + 7, x + 6, ypos + 7, c);
            renderDrawLine(x, ypos, x, ypos + 7, c);
            renderDrawLine(x + 6, ypos, x + 6, ypos + 7, c);
        }

        x += 8;
    }
}

/// Print text for editor (16-pixel font)
pub fn printext16(xpos: i32, ypos: i32, col: i16, backcol: i16, name: []const u8, fontsize: u8) i32 {
    _ = fontsize;
    var x = xpos;

    for (name) |char| {
        if (char == '\n') continue;

        if (backcol >= 0) {
            fillrect(x, ypos, x + 7, ypos + 15, @truncate(@as(u16, @intCast(backcol))));
        }

        if (col >= 0) {
            const c: u8 = @truncate(@as(u16, @intCast(col)));
            renderDrawLine(x, ypos, x + 6, ypos, c);
            renderDrawLine(x, ypos + 15, x + 6, ypos + 15, c);
            renderDrawLine(x, ypos, x, ypos + 15, c);
            renderDrawLine(x + 6, ypos, x + 6, ypos + 15, c);
        }

        x += 8;
    }

    return x - xpos;
}

// =============================================================================
// Circle Drawing (for editor)
// =============================================================================

/// Draw a circle (ellipse) for the editor
pub fn editorDraw2dCircle(x1: i32, y1: i32, r: i32, eccen: i32, col: u8) void {
    _ = eccen; // eccentricity for ellipse, ignored for now

    // Simple circle using midpoint algorithm
    var x: i32 = r;
    var y: i32 = 0;
    var err: i32 = 0;

    while (x >= y) {
        plotpixel(x1 + x, y1 + y, col);
        plotpixel(x1 + y, y1 + x, col);
        plotpixel(x1 - y, y1 + x, col);
        plotpixel(x1 - x, y1 + y, col);
        plotpixel(x1 - x, y1 - y, col);
        plotpixel(x1 - y, y1 - x, col);
        plotpixel(x1 + y, y1 - x, col);
        plotpixel(x1 + x, y1 - y, col);

        y += 1;
        err += 1 + 2 * y;
        if (2 * (err - x) + 1 > 0) {
            x -= 1;
            err += 1 - 2 * x;
        }
    }
}

/// Draw a line for the editor (same as renderDrawLine but returns status)
pub fn editorDraw2dLine(x1: i32, y1: i32, x2: i32, y2: i32, col: i32) i32 {
    renderDrawLine(x1, y1, x2, y2, @truncate(@as(u32, @intCast(col))));
    return 0;
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Find the closest palette color to an RGB value
fn findClosestColor(r: u8, g: u8, b: u8) u8 {
    var bestMatch: u8 = 0;
    var bestDist: i32 = std.math.maxInt(i32);

    for (0..256) |i| {
        const pr = globals.palette[i * 3 + 0];
        const pg = globals.palette[i * 3 + 1];
        const pb = globals.palette[i * 3 + 2];

        const dr = @as(i32, r) - @as(i32, pr);
        const dg = @as(i32, g) - @as(i32, pg);
        const db = @as(i32, b) - @as(i32, pb);

        const dist = dr * dr + dg * dg + db * db;
        if (dist < bestDist) {
            bestDist = dist;
            bestMatch = @truncate(i);
        }
    }

    return bestMatch;
}

/// Set the drawing color
pub fn setDrawColor(p: types.Palette) void {
    drawColor = p;
}

/// Get the current drawing color
pub fn getDrawColor() types.Palette {
    return drawColor;
}

// =============================================================================
// 2D View Setup for GL
// =============================================================================

/// Set up OpenGL for 2D drawing
pub fn polymostSet2dView() void {
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();
    gl.glOrtho(0.0, @floatFromInt(globals.xdim), @floatFromInt(globals.ydim), 0.0, -1.0, 1.0);

    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    gl_state.setDisabled(gl_state.GL_DEPTH_TEST);
    gl_state.setDisabled(gl_state.GL_BLEND);
    gl_state.setDisabled(gl_state.GL_CULL_FACE);
}

// =============================================================================
// Tests
// =============================================================================

test "find closest color" {
    // Initialize palette with some test colors
    globals.palette[0] = 0;
    globals.palette[1] = 0;
    globals.palette[2] = 0; // Black at index 0

    globals.palette[3] = 63;
    globals.palette[4] = 63;
    globals.palette[5] = 63; // White at index 1

    globals.palette[6] = 63;
    globals.palette[7] = 0;
    globals.palette[8] = 0; // Red at index 2

    // Black should match index 0
    try std.testing.expectEqual(@as(u8, 0), findClosestColor(0, 0, 0));
}
