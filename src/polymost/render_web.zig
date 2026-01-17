//! Polymost Renderer for WebGL/WASM
//! This is the WebGL version of the polymost renderer for running in browsers.

const std = @import("std");
const types = @import("types");
const constants = @import("constants");
const globals = @import("globals");
const gl = @import("webgl");

// =============================================================================
// Constants
// =============================================================================

const BUILD_TO_GL_SCALE: f32 = 1.0 / 16.0;
const Z_SCALE: f32 = BUILD_TO_GL_SCALE / 16.0;
const MAX_VISIBLE_SECTORS: usize = 256;

// =============================================================================
// State
// =============================================================================

pub var polymost_inited: bool = false;
var drawn_sectors: [constants.MAXSECTORS]bool = [_]bool{false} ** constants.MAXSECTORS;

// =============================================================================
// Initialization
// =============================================================================

pub fn polymost_init() void {
    if (polymost_inited) return;
    polymost_glinit();
    polymost_inited = true;
}

pub fn polymost_glinit() void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);
    gl.glEnable(gl.GL_CULL_FACE);
    gl.glCullFace(gl.GL_BACK);
    gl.glFrontFace(gl.GL_CCW);
    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();
}

// =============================================================================
// Main Drawing
// =============================================================================

pub fn polymost_drawrooms() void {
    if (!polymost_inited) {
        polymost_init();
    }

    gl.glClear(gl.GL_DEPTH_BUFFER_BIT);
    setupProjection();
    setupModelView();
    @memset(&drawn_sectors, false);
    renderVisibleSectors();
}

fn setupProjection() void {
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    const xdim: f32 = @floatFromInt(globals.xdim);
    const ydim: f32 = @floatFromInt(globals.ydim);
    const fov = 90.0 * std.math.pi / 180.0;
    const aspect = xdim / ydim;
    const znear: f32 = 4.0;
    const zfar: f32 = 100000.0;
    const f = 1.0 / @tan(fov / 2.0);

    const proj: [16]f32 = .{
        f / aspect, 0.0,  0.0,                                   0.0,
        0.0,        f,    0.0,                                   0.0,
        0.0,        0.0,  (zfar + znear) / (znear - zfar),      -1.0,
        0.0,        0.0,  (2.0 * zfar * znear) / (znear - zfar), 0.0,
    };

    gl.glLoadMatrixf(&proj);
}

fn setupModelView() void {
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    const horiz: f32 = @floatFromInt(types.fix16ToInt(globals.globalhoriz));
    const ang: f32 = @floatFromInt(globals.globalang);
    const pitch = (horiz - 100.0) * 0.35;
    const yaw = ang * (360.0 / 2048.0);

    gl.glRotatef(-pitch, 1.0, 0.0, 0.0);
    gl.glRotatef(-(yaw - 90.0), 0.0, 1.0, 0.0);

    const cam_x: f32 = @as(f32, @floatFromInt(globals.globalposx)) * BUILD_TO_GL_SCALE;
    const cam_y: f32 = @as(f32, @floatFromInt(-globals.globalposz)) * Z_SCALE;
    const cam_z: f32 = @as(f32, @floatFromInt(globals.globalposy)) * BUILD_TO_GL_SCALE;

    gl.glTranslatef(-cam_x, -cam_y, -cam_z);
}

fn renderVisibleSectors() void {
    const numsectors: i32 = globals.numsectors;
    if (numsectors <= 0) return;

    var start_sect = globals.globalcursectnum;
    if (start_sect < 0 or start_sect >= numsectors) {
        start_sect = 0;
    }

    var queue: [MAX_VISIBLE_SECTORS]i16 = undefined;
    var queue_head: usize = 0;
    var queue_tail: usize = 0;

    queue[queue_tail] = start_sect;
    queue_tail += 1;
    drawn_sectors[@intCast(start_sect)] = true;

    while (queue_head < queue_tail) {
        const sectnum = queue[queue_head];
        queue_head += 1;

        drawSectorGeometry(@intCast(sectnum));

        const sec = &globals.sector[@intCast(sectnum)];
        const startwall: usize = @intCast(sec.wallptr);
        const wallcount: usize = @intCast(sec.wallnum);

        for (startwall..startwall + wallcount) |i| {
            const wall = &globals.wall[i];
            if (wall.nextsector >= 0 and wall.nextsector < numsectors) {
                const nextsect: usize = @intCast(wall.nextsector);
                if (!drawn_sectors[nextsect] and queue_tail < MAX_VISIBLE_SECTORS) {
                    queue[queue_tail] = wall.nextsector;
                    queue_tail += 1;
                    drawn_sectors[nextsect] = true;
                }
            }
        }
    }
}

// =============================================================================
// Sector Rendering
// =============================================================================

fn drawSectorGeometry(sectnum: usize) void {
    if (sectnum >= @as(usize, @intCast(globals.numsectors))) return;

    const sec = &globals.sector[sectnum];

    drawFlat(sec, false);
    drawFlat(sec, true);

    const startwall: usize = @intCast(sec.wallptr);
    const wallcount: usize = @intCast(sec.wallnum);

    for (startwall..startwall + wallcount) |i| {
        drawWallWithSector(i, sectnum);
    }
}

fn drawFlat(sec: *const types.SectorType, is_ceiling: bool) void {
    const startwall: usize = @intCast(sec.wallptr);
    const wallcount: usize = @intCast(sec.wallnum);

    if (wallcount < 3) return;

    const z: f32 = if (is_ceiling)
        @as(f32, @floatFromInt(-sec.ceilingz)) * Z_SCALE
    else
        @as(f32, @floatFromInt(-sec.floorz)) * Z_SCALE;

    const shade_val: i8 = if (is_ceiling) sec.ceilingshade else sec.floorshade;
    const shade: f32 = @as(f32, @floatFromInt(shade_val)) / 64.0;
    const brightness = std.math.clamp(1.0 - shade, 0.1, 1.0);

    if (is_ceiling) {
        gl.glColor3f(brightness * 0.3, brightness * 0.3, brightness * 0.5);
    } else {
        gl.glColor3f(brightness * 0.5, brightness * 0.4, brightness * 0.3);
    }

    var verts_x: [256]f32 = undefined;
    var verts_z: [256]f32 = undefined;
    var vertex_count: usize = 0;

    for (startwall..startwall + wallcount) |i| {
        if (vertex_count >= 256) break;
        const wall = &globals.wall[i];
        verts_x[vertex_count] = @as(f32, @floatFromInt(wall.x)) * BUILD_TO_GL_SCALE;
        verts_z[vertex_count] = @as(f32, @floatFromInt(wall.y)) * BUILD_TO_GL_SCALE;
        vertex_count += 1;
    }

    if (vertex_count < 3) return;

    var cx: f32 = 0;
    var cz: f32 = 0;
    for (0..vertex_count) |i| {
        cx += verts_x[i];
        cz += verts_z[i];
    }
    cx /= @floatFromInt(vertex_count);
    cz /= @floatFromInt(vertex_count);

    gl.glBegin(gl.GL_TRIANGLE_FAN);
    gl.glVertex3f(cx, z, cz);

    if (is_ceiling) {
        var i: usize = vertex_count;
        while (i > 0) {
            i -= 1;
            gl.glVertex3f(verts_x[i], z, verts_z[i]);
        }
        gl.glVertex3f(verts_x[vertex_count - 1], z, verts_z[vertex_count - 1]);
    } else {
        for (0..vertex_count) |i| {
            gl.glVertex3f(verts_x[i], z, verts_z[i]);
        }
        gl.glVertex3f(verts_x[0], z, verts_z[0]);
    }

    gl.glEnd();
}

fn drawWallWithSector(wallnum: usize, sectnum: usize) void {
    if (wallnum >= @as(usize, @intCast(globals.numwalls))) return;

    const wall = &globals.wall[wallnum];
    const wall2 = &globals.wall[@intCast(wall.point2)];
    const sec = &globals.sector[sectnum];

    const x1: f32 = @as(f32, @floatFromInt(wall.x)) * BUILD_TO_GL_SCALE;
    const z1: f32 = @as(f32, @floatFromInt(wall.y)) * BUILD_TO_GL_SCALE;
    const x2: f32 = @as(f32, @floatFromInt(wall2.x)) * BUILD_TO_GL_SCALE;
    const z2: f32 = @as(f32, @floatFromInt(wall2.y)) * BUILD_TO_GL_SCALE;

    const floor_y: f32 = @as(f32, @floatFromInt(-sec.floorz)) * Z_SCALE;
    const ceil_y: f32 = @as(f32, @floatFromInt(-sec.ceilingz)) * Z_SCALE;

    const shade: f32 = @as(f32, @floatFromInt(wall.shade)) / 64.0;
    const brightness = std.math.clamp(1.0 - shade, 0.1, 1.0);

    if (wall.nextsector < 0) {
        gl.glColor3f(brightness, brightness, brightness);
        drawWallQuad(x1, z1, x2, z2, floor_y, ceil_y);
    } else {
        const nextsect: usize = @intCast(wall.nextsector);
        const next_sec = &globals.sector[nextsect];
        const next_floor_y: f32 = @as(f32, @floatFromInt(-next_sec.floorz)) * Z_SCALE;
        const next_ceil_y: f32 = @as(f32, @floatFromInt(-next_sec.ceilingz)) * Z_SCALE;

        if (ceil_y > next_ceil_y) {
            gl.glColor3f(brightness * 0.9, brightness * 0.9, brightness * 0.95);
            drawWallQuad(x1, z1, x2, z2, next_ceil_y, ceil_y);
        }

        if (next_floor_y > floor_y) {
            gl.glColor3f(brightness * 0.85, brightness * 0.8, brightness * 0.75);
            drawWallQuad(x1, z1, x2, z2, floor_y, next_floor_y);
        }

        gl.glColor4f(0.2, 0.4, 0.8, 0.3);
        const portal_bottom = @max(floor_y, next_floor_y);
        const portal_top = @min(ceil_y, next_ceil_y);
        if (portal_top > portal_bottom) {
            gl.glBegin(gl.GL_LINE_LOOP);
            gl.glVertex3f(x1, portal_bottom, z1);
            gl.glVertex3f(x2, portal_bottom, z2);
            gl.glVertex3f(x2, portal_top, z2);
            gl.glVertex3f(x1, portal_top, z1);
            gl.glEnd();
        }
    }
}

fn drawWallQuad(x1: f32, z1: f32, x2: f32, z2: f32, y_bottom: f32, y_top: f32) void {
    // WebGL doesn't support GL_QUADS, so we use two triangles
    gl.glBegin(gl.GL_TRIANGLES);

    // First triangle
    gl.glVertex3f(x1, y_bottom, z1);
    gl.glVertex3f(x2, y_bottom, z2);
    gl.glVertex3f(x2, y_top, z2);

    // Second triangle
    gl.glVertex3f(x1, y_bottom, z1);
    gl.glVertex3f(x2, y_top, z2);
    gl.glVertex3f(x1, y_top, z1);

    gl.glEnd();
}
