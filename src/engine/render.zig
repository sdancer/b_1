//! Main Rendering Entry Points
//! Port from: NBlood/source/build/src/engine.cpp (render functions)
//!
//! This module contains the primary rendering functions that dispatch
//! to the appropriate renderer (Classic, Polymost, or Polymer).

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");
const view = @import("view.zig");
const sprite = @import("sprite.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");

// =============================================================================
// Rendering State
// =============================================================================

/// Current camera position
pub var globalposx: i32 = 0;
pub var globalposy: i32 = 0;
pub var globalposz: i32 = 0;

/// Current camera angle (Q16 fixed point)
pub var globalang: types.Fix16 = 0;

/// Current camera horizon (Q16 fixed point)
pub var globalhoriz: types.Fix16 = 0;

/// Current sector being rendered
pub var globalcursectnum: i16 = 0;

/// Visibility value for current frame
pub var globalvisibility: i32 = 0;

/// Mirror rendering state
pub var inpreparemirror: bool = false;

// =============================================================================
// Main Rendering Functions
// =============================================================================

/// Main room rendering function (Q16 fixed-point angles)
///
/// Parameters:
/// - daposx, daposy, daposz: Camera position
/// - daang: Camera angle (16.16 fixed point)
/// - dahoriz: Camera horizon (16.16 fixed point)
/// - dacursectnum: Current sector number
///
/// Returns: Number of bunches rendered (or 0 on error)
pub fn renderDrawRoomsQ16(
    daposx: i32,
    daposy: i32,
    daposz: i32,
    daang: types.Fix16,
    dahoriz: types.Fix16,
    dacursectnum: i16,
) i32 {
    // Validate sector
    if (dacursectnum < 0 or dacursectnum >= globals.numsectors) {
        return 0;
    }

    // Store global camera state
    globalposx = daposx;
    globalposy = daposy;
    globalposz = daposz;
    globalang = daang;
    globalhoriz = dahoriz;
    globalcursectnum = dacursectnum;

    // Update global rendering parameters
    globals.globalpicnum = 0;
    globals.globalpal = 0;
    globals.globalshade = 0;

    // Clear temporary sprites for this frame
    sprite.clearTSprites();

    // Dispatch to appropriate renderer
    const rendmode = globals.rendmode;

    if (rendmode == @intFromEnum(enums.RendMode.polymer)) {
        return renderDrawRoomsPolymer(daposx, daposy, daposz, daang, dahoriz, dacursectnum);
    } else if (rendmode == @intFromEnum(enums.RendMode.polymost)) {
        return renderDrawRoomsPolymost(daposx, daposy, daposz, daang, dahoriz, dacursectnum);
    } else {
        return renderDrawRoomsClassic(daposx, daposy, daposz, daang, dahoriz, dacursectnum);
    }
}

/// Convenience wrapper with integer angles (for backwards compatibility)
pub fn drawrooms(
    daposx: i32,
    daposy: i32,
    daposz: i32,
    daang: i16,
    dahoriz: i16,
    dacursectnum: i16,
) i32 {
    return renderDrawRoomsQ16(
        daposx,
        daposy,
        daposz,
        types.fix16FromInt(daang),
        types.fix16FromInt(dahoriz),
        dacursectnum,
    );
}

// =============================================================================
// Mask Rendering (transparent surfaces)
// =============================================================================

/// Render all masked (transparent) walls and sprites
pub fn renderDrawMasks() void {
    // Sort masked walls and sprites by depth
    sortMaskedElements();

    // Dispatch to renderer
    if (globals.rendmode >= @intFromEnum(enums.RendMode.polymost)) {
        renderDrawMasksGL();
    } else {
        renderDrawMasksSoftware();
    }
}

/// Sort masked elements by depth for proper rendering order
fn sortMaskedElements() void {
    // Sort sprites by distance from camera
    const cnt = @as(usize, @intCast(globals.spritesortcnt));
    if (cnt <= 1) return;

    // Simple insertion sort (stable, good for nearly-sorted data)
    for (1..cnt) |i| {
        const tspr = globals.tspriteptr[i];
        if (tspr == null) continue;

        const dist = calculateSpriteDistance(tspr.?);
        var j = i;

        while (j > 0) {
            const prev = globals.tspriteptr[j - 1];
            if (prev == null or calculateSpriteDistance(prev.?) <= dist) break;

            globals.tspriteptr[j] = globals.tspriteptr[j - 1];
            j -= 1;
        }

        globals.tspriteptr[j] = tspr;
    }
}

/// Calculate sprite distance from camera
fn calculateSpriteDistance(tspr: *types.TSpriteType) i64 {
    const dx = @as(i64, tspr.x - globalposx);
    const dy = @as(i64, tspr.y - globalposy);
    return dx * dx + dy * dy;
}

/// Render masks using OpenGL
fn renderDrawMasksGL() void {
    // Enable alpha blending for transparent surfaces
    gl_state.setEnabled(gl_state.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

    // Disable depth writes but keep depth test
    gl.glDepthMask(gl.GL_FALSE);

    // Render masked walls
    for (0..@intCast(globals.maskwallcnt)) |i| {
        const wallnum = globals.maskwall[i];
        renderMaskedWall(wallnum);
    }

    // Render sprites (back to front)
    const cnt = @as(usize, @intCast(globals.spritesortcnt));
    for (0..cnt) |i| {
        const tspr = globals.tspriteptr[cnt - 1 - i]; // Reverse order
        if (tspr != null) {
            renderSprite(tspr.?);
        }
    }

    // Restore state
    gl.glDepthMask(gl.GL_TRUE);
}

/// Render masks using software renderer
fn renderDrawMasksSoftware() void {
    // Software mask rendering would go here
    // For now, just iterate through elements
    for (0..@intCast(globals.maskwallcnt)) |i| {
        _ = globals.maskwall[i];
        // renderMaskedWallSoftware(wallnum);
    }

    for (0..@intCast(globals.spritesortcnt)) |i| {
        _ = globals.tspriteptr[i];
        // if (tspr != null) renderSpriteSoftware(tspr.?);
    }
}

// =============================================================================
// Renderer-Specific Implementations
// =============================================================================

/// Polymost renderer (OpenGL 1.x/2.0)
fn renderDrawRoomsPolymost(
    daposx: i32,
    daposy: i32,
    daposz: i32,
    daang: types.Fix16,
    dahoriz: types.Fix16,
    dacursectnum: i16,
) i32 {
    // Set up OpenGL state
    gl.glClear(gl.GL_DEPTH_BUFFER_BIT);
    gl_state.setEnabled(gl_state.GL_DEPTH_TEST);
    gl_state.setDepthFunc(gl_state.GL_LEQUAL);

    // Set up projection matrix
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    const fov = 90.0 * std.math.pi / 180.0;
    const aspect = @as(f32, @floatFromInt(globals.xdim)) / @as(f32, @floatFromInt(globals.ydim));
    gl_state.setPerspective(fov, aspect, 0.01, 1000000.0);

    // Set up modelview matrix
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    // Convert BUILD coordinates to OpenGL
    const ang = types.fix16ToFloat(daang) / 2048.0 * 2.0 * std.math.pi;
    const horiz = types.fix16ToFloat(dahoriz);
    _ = horiz;

    // Rotate view
    gl.glRotatef(-90.0, 1.0, 0.0, 0.0); // Look down Z axis
    gl.glRotatef(ang * 180.0 / std.math.pi, 0.0, 0.0, 1.0);
    gl.glTranslatef(
        -@as(f32, @floatFromInt(daposx)) / 16.0,
        -@as(f32, @floatFromInt(daposy)) / 16.0,
        -@as(f32, @floatFromInt(daposz)) / 16.0 / 16.0,
    );

    // Render sectors (simplified - would use portal/BSP traversal)
    var bunchcnt: i32 = 0;

    // Start from current sector and traverse visible sectors
    var sectorsToRender: [constants.MAXSECTORS]bool = [_]bool{false} ** constants.MAXSECTORS;
    sectorsToRender[@intCast(dacursectnum)] = true;

    // Simple BFS traversal of connected sectors
    var queue: [constants.MAXSECTORS]i16 = undefined;
    var qhead: usize = 0;
    var qtail: usize = 0;

    queue[qtail] = dacursectnum;
    qtail += 1;

    while (qhead < qtail and qtail < constants.MAXSECTORS) {
        const sectnum = queue[qhead];
        qhead += 1;

        renderSector(sectnum);
        bunchcnt += 1;

        // Add connected sectors
        const sec = &globals.sector[@intCast(sectnum)];
        const startwall = sec.wallptr;
        const endwall = startwall + sec.wallnum;

        for (@intCast(startwall)..@intCast(endwall)) |w| {
            const wall = &globals.wall[w];
            const nextsect = wall.nextsector;

            if (nextsect >= 0 and !sectorsToRender[@intCast(nextsect)]) {
                sectorsToRender[@intCast(nextsect)] = true;
                queue[qtail] = nextsect;
                qtail += 1;
            }
        }

        // Limit traversal for performance
        if (bunchcnt > 256) break;
    }

    // Collect sprites for rendering
    collectSprites();

    return bunchcnt;
}

/// Polymer renderer (advanced lighting)
fn renderDrawRoomsPolymer(
    daposx: i32,
    daposy: i32,
    daposz: i32,
    daang: types.Fix16,
    dahoriz: types.Fix16,
    dacursectnum: i16,
) i32 {
    // Polymer would have its own implementation
    // For now, fall back to Polymost
    return renderDrawRoomsPolymost(daposx, daposy, daposz, daang, dahoriz, dacursectnum);
}

/// Classic software renderer
fn renderDrawRoomsClassic(
    daposx: i32,
    daposy: i32,
    daposz: i32,
    daang: types.Fix16,
    dahoriz: types.Fix16,
    dacursectnum: i16,
) i32 {
    _ = dahoriz;
    _ = daang;
    _ = daposz;
    _ = daposy;
    _ = daposx;

    // Classic renderer would use scanline-based BSP rendering
    // For now, just return sector count as bunches
    var bunchcnt: i32 = 0;

    // Simple sector iteration
    var sectnum = dacursectnum;
    while (sectnum >= 0 and bunchcnt < 256) : (bunchcnt += 1) {
        // In real implementation, would render sector
        sectnum = -1; // Stop after first (placeholder)
    }

    return bunchcnt;
}

// =============================================================================
// Sector Rendering
// =============================================================================

/// Render a single sector
fn renderSector(sectnum: i16) void {
    if (sectnum < 0 or sectnum >= globals.numsectors) return;

    const sec = &globals.sector[@intCast(sectnum)];

    // Render floor and ceiling
    renderFlat(sectnum, false); // Floor
    renderFlat(sectnum, true); // Ceiling

    // Render walls
    const startwall = sec.wallptr;
    const endwall = startwall + sec.wallnum;

    for (@intCast(startwall)..@intCast(endwall)) |w| {
        renderWall(@intCast(w), sectnum);
    }
}

/// Render floor or ceiling
fn renderFlat(sectnum: i16, isCeiling: bool) void {
    const sec = &globals.sector[@intCast(sectnum)];

    const z = if (isCeiling) sec.ceilingz else sec.floorz;
    const picnum = if (isCeiling) sec.ceilingpicnum else sec.floorpicnum;
    const shade = if (isCeiling) sec.ceilingshade else sec.floorshade;

    // Calculate shade factor
    const shadeFactor = 1.0 - @as(f32, @floatFromInt(shade)) / 64.0;
    const clampedShade = std.math.clamp(shadeFactor, 0.0, 1.0);

    _ = picnum;

    // Get sector vertices from walls
    const startwall = sec.wallptr;
    const wallnum = sec.wallnum;

    if (wallnum < 3) return;

    // Draw as triangle fan
    gl.glColor3f(clampedShade, clampedShade, clampedShade);
    gl.glBegin(gl.GL_TRIANGLE_FAN);

    const fz = @as(f32, @floatFromInt(z)) / 16.0 / 16.0;

    for (0..@intCast(wallnum)) |i| {
        const wall = &globals.wall[@as(usize, @intCast(startwall)) + i];
        const fx = @as(f32, @floatFromInt(wall.x)) / 16.0;
        const fy = @as(f32, @floatFromInt(wall.y)) / 16.0;
        gl.glVertex3f(fx, fy, fz);
    }

    gl.glEnd();
}

/// Render a wall
fn renderWall(wallnum: i16, sectnum: i16) void {
    _ = sectnum;

    const wall = &globals.wall[@intCast(wallnum)];
    const wall2 = &globals.wall[@intCast(wall.point2)];

    const x1 = @as(f32, @floatFromInt(wall.x)) / 16.0;
    const y1 = @as(f32, @floatFromInt(wall.y)) / 16.0;
    const x2 = @as(f32, @floatFromInt(wall2.x)) / 16.0;
    const y2 = @as(f32, @floatFromInt(wall2.y)) / 16.0;

    // Calculate shade
    const shadeFactor = 1.0 - @as(f32, @floatFromInt(wall.shade)) / 64.0;
    const clampedShade = std.math.clamp(shadeFactor, 0.0, 1.0);

    // For now, draw a simple quad
    const z1: f32 = 0.0;
    const z2: f32 = 100.0;

    gl.glColor3f(clampedShade * 0.8, clampedShade * 0.8, clampedShade);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex3f(x1, y1, z1);
    gl.glVertex3f(x2, y2, z1);
    gl.glVertex3f(x2, y2, z2);
    gl.glVertex3f(x1, y1, z2);
    gl.glEnd();
}

/// Render a masked (transparent) wall
fn renderMaskedWall(wallnum: i16) void {
    // Similar to renderWall but with alpha
    _ = wallnum;
}

/// Render a sprite
fn renderSprite(tspr: *types.TSpriteType) void {
    // Basic sprite rendering
    const x = @as(f32, @floatFromInt(tspr.x)) / 16.0;
    const y = @as(f32, @floatFromInt(tspr.y)) / 16.0;
    const z = @as(f32, @floatFromInt(tspr.z)) / 16.0 / 16.0;

    const size = @as(f32, @floatFromInt(tspr.xrepeat)) * 2.0;

    // Billboard sprite (always faces camera)
    gl.glColor3f(1.0, 1.0, 1.0);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex3f(x - size, y - size, z);
    gl.glVertex3f(x + size, y - size, z);
    gl.glVertex3f(x + size, y + size, z + size * 2);
    gl.glVertex3f(x - size, y + size, z + size * 2);
    gl.glEnd();
}

/// Collect sprites in visible sectors
fn collectSprites() void {
    // Iterate through all sprites in visible sectors
    // and add them to the tsprite array for rendering
    for (0..@intCast(globals.Numsprites)) |i| {
        const spr = &globals.sprite[i];
        if (spr.statnum < constants.MAXSTATUS and spr.sectnum >= 0) {
            if (!sprite.isSpriteVisible(spr)) continue;

            _ = sprite.renderAddTSpriteFromSprite(@intCast(i));
        }
    }
}

// =============================================================================
// Tests
// =============================================================================

test "render state initialization" {
    globalposx = 0;
    globalposy = 0;
    globalposz = 0;
    globalang = 0;
    globalhoriz = types.fix16FromInt(100);

    try std.testing.expectEqual(@as(i32, 0), globalposx);
    try std.testing.expectEqual(@as(i32, 100), types.fix16ToInt(globalhoriz));
}

test "sprite distance calculation" {
    globalposx = 0;
    globalposy = 0;

    var tspr: types.TSpriteType = undefined;
    tspr.x = 100;
    tspr.y = 100;

    const dist = calculateSpriteDistance(&tspr);
    try std.testing.expectEqual(@as(i64, 20000), dist);
}
