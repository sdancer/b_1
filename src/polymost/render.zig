//! Polymost Renderer - OpenGL 1.x/2.0 Rendering
//! Port from: NBlood/source/build/src/polymost.cpp
//!
//! This is the primary hardware-accelerated renderer for the BUILD engine.
//! It uses OpenGL for rendering walls, floors, ceilings, and sprites.
//!
//! Coordinate Systems:
//! - BUILD: X=east, Y=north, Z=height (negative=higher)
//! - OpenGL: X=right, Y=up, Z=out of screen
//! - Conversion: gl_x=build_x, gl_y=-build_z, gl_z=build_y

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");

const pm_globals = @import("globals.zig");
const texcoord = @import("texcoord.zig");
const texture = @import("texture.zig");
const draw = @import("draw.zig");
const polymost_types = @import("types.zig");
const art = @import("../fs/art.zig");

// =============================================================================
// Constants
// =============================================================================

/// Scale factor for BUILD units to GL units
const BUILD_TO_GL_SCALE: f32 = 1.0 / 16.0;

/// Z scale factor (BUILD Z is 256 units per BUILD unit height)
const Z_SCALE: f32 = BUILD_TO_GL_SCALE / 16.0;

/// Maximum sectors to render (for BFS traversal)
const MAX_VISIBLE_SECTORS: usize = 256;

// =============================================================================
// Polymost State
// =============================================================================

/// Polymost initialization state
pub var polymost_inited: bool = false;

/// Current drawing mode
pub var drawmode: i32 = 0;

/// Global shade offset
pub var globalshade: i32 = 0;
pub var globalpal: i32 = 0;
pub var globalfloorpal: i32 = 0;

/// Visibility/fog parameters
pub var gvisibility: f32 = 0.0;

/// Current transformation state
pub var ghalfx: f32 = 0.0;
pub var ghalfy: f32 = 0.0;

/// Cosine/sine of view angle
pub var gcosang: f32 = 0.0;
pub var gsinang: f32 = 0.0;

/// Sectors already drawn (to avoid redrawing)
var drawn_sectors: [constants.MAXSECTORS]bool = [_]bool{false} ** constants.MAXSECTORS;

// =============================================================================
// Initialization
// =============================================================================

/// Initialize the polymost renderer
pub fn polymost_init() i32 {
    if (polymost_inited) return 0;

    // Initialize default state
    ghalfx = @as(f32, @floatFromInt(globals.xdim)) / 2.0;
    ghalfy = @as(f32, @floatFromInt(globals.ydim)) / 2.0;

    // Initialize GL state
    polymost_glinit();

    polymost_inited = true;
    return 0;
}

/// Initialize GL-specific polymost state
pub fn polymost_glinit() void {
    // Enable texturing
    gl.glEnable(gl.GL_TEXTURE_2D);

    // Enable depth testing
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);

    // Enable backface culling
    gl.glEnable(gl.GL_CULL_FACE);
    gl.glCullFace(gl.GL_BACK);
    gl.glFrontFace(gl.GL_CCW);

    // Enable blending for transparency
    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

    // Enable alpha testing for masked textures
    gl.glEnable(gl.GL_ALPHA_TEST);
    gl.glAlphaFunc(gl.GL_GREATER, 0.01);

    // Initialize matrices
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    // Initialize polymost globals
    pm_globals.initFromEngine();
}

/// Reset polymost GL state
pub fn polymost_glreset() void {
    polymost_inited = false;
}

// =============================================================================
// Main Drawing Functions
// =============================================================================

/// Frame counter for debug output
var frame_count: u32 = 0;

/// Main polymost draw rooms function
/// This is the entry point for rendering the 3D view
pub fn polymost_drawrooms() void {
    if (!polymost_inited) {
        _ = polymost_init();
    }

    // Sync render state from engine globals
    pm_globals.initFromEngine();
    pm_globals.updateAngleState();
    pm_globals.syncRenderParams();

    // Clear depth buffer
    gl.glClear(gl.GL_DEPTH_BUFFER_BIT);

    // Set up projection matrix
    setupProjection();

    // Set up modelview matrix for the view
    setupModelView();

    // Reset drawn sectors
    @memset(&drawn_sectors, false);

    // Enable texturing if configured
    if (use_textures) {
        gl.glEnable(gl.GL_TEXTURE_2D);
    } else {
        gl.glDisable(gl.GL_TEXTURE_2D);
    }

    // Render visible sectors using BFS from current sector
    renderVisibleSectors();

    // Print texture stats after first frame
    frame_count += 1;
    if (frame_count == 2) {
        texture.debugPrintStats();
    }
}

/// Set up the projection matrix (perspective)
fn setupProjection() void {
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    const xdim: f32 = @floatFromInt(globals.xdim);
    const ydim: f32 = @floatFromInt(globals.ydim);

    // Field of view (90 degrees)
    const fov = 90.0 * std.math.pi / 180.0;
    const aspect = xdim / ydim;
    const znear: f32 = 4.0;
    const zfar: f32 = 100000.0;

    const f = 1.0 / @tan(fov / 2.0);

    // Build perspective matrix (column-major for OpenGL)
    const proj: [16]f32 = .{
        f / aspect, 0.0,  0.0,                                   0.0,
        0.0,        f,    0.0,                                   0.0,
        0.0,        0.0,  (zfar + znear) / (znear - zfar),      -1.0,
        0.0,        0.0,  (2.0 * zfar * znear) / (znear - zfar), 0.0,
    };

    gl.glLoadMatrixf(&proj);
}

/// Set up the modelview matrix (camera transformation)
fn setupModelView() void {
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    // Get camera parameters
    const horiz: f32 = @floatFromInt(types.fix16ToInt(globals.globalhoriz));
    const ang: f32 = @floatFromInt(globals.globalang);

    // Look up/down: horiz 100 = level, <100 = look down, >100 = look up
    // Convert to pitch angle (horiz-100 maps to degrees)
    const pitch = (horiz - 100.0) * 0.35;

    // Yaw angle: BUILD uses 2048 units = 360 degrees
    // 0 = east, 512 = north, 1024 = west, 1536 = south
    const yaw = ang * (360.0 / 2048.0);

    // Apply rotations (order matters!)
    // First pitch (look up/down around X axis)
    gl.glRotatef(-pitch, 1.0, 0.0, 0.0);

    // Then yaw (rotate around Y axis)
    // Subtract 90 because BUILD 0 is east, but we want to look down +Z
    gl.glRotatef(-(yaw - 90.0), 0.0, 1.0, 0.0);

    // Camera position
    // BUILD: X=east, Y=north, Z=height (negative=higher)
    // GL: X=right, Y=up, Z=out
    // Mapping: gl_x = build_x, gl_y = -build_z, gl_z = build_y
    const cam_x: f32 = @as(f32, @floatFromInt(globals.globalposx)) * BUILD_TO_GL_SCALE;
    const cam_y: f32 = @as(f32, @floatFromInt(-globals.globalposz)) * Z_SCALE;
    const cam_z: f32 = @as(f32, @floatFromInt(globals.globalposy)) * BUILD_TO_GL_SCALE;

    gl.glTranslatef(-cam_x, -cam_y, -cam_z);
}

/// Render all visible sectors using BFS from current sector
fn renderVisibleSectors() void {
    const numsectors: i32 = globals.numsectors;
    if (numsectors <= 0) return;

    var start_sect = globals.globalcursectnum;
    if (start_sect < 0 or start_sect >= numsectors) {
        start_sect = 0;
    }

    // BFS queue for sector traversal
    var queue: [MAX_VISIBLE_SECTORS]i16 = undefined;
    var queue_head: usize = 0;
    var queue_tail: usize = 0;

    // Start with current sector
    queue[queue_tail] = start_sect;
    queue_tail += 1;
    drawn_sectors[@intCast(start_sect)] = true;

    // Process queue
    while (queue_head < queue_tail) {
        const sectnum = queue[queue_head];
        queue_head += 1;

        // Draw this sector
        drawSectorGeometry(@intCast(sectnum));

        // Add neighboring sectors through portals
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

/// Draw all geometry for a sector (floor, ceiling, walls)
fn drawSectorGeometry(sectnum: usize) void {
    if (sectnum >= @as(usize, @intCast(globals.numsectors))) return;

    const sec = &globals.sector[sectnum];

    // Draw floor
    drawFlat(sectnum, sec, false);

    // Draw ceiling
    drawFlat(sectnum, sec, true);

    // Draw walls
    const startwall: usize = @intCast(sec.wallptr);
    const wallcount: usize = @intCast(sec.wallnum);

    for (startwall..startwall + wallcount) |i| {
        drawWallWithSector(i, sectnum);
    }
}

/// Whether to use textured rendering (vs color-only)
pub var use_textures: bool = true;

/// Draw floor or ceiling flat
fn drawFlat(sectnum: usize, sec: *const types.SectorType, is_ceiling: bool) void {
    const startwall: usize = @intCast(sec.wallptr);
    const wallcount: usize = @intCast(sec.wallnum);

    if (wallcount < 3) return;

    // Get Z height
    const z: f32 = if (is_ceiling)
        @as(f32, @floatFromInt(-sec.ceilingz)) * Z_SCALE
    else
        @as(f32, @floatFromInt(-sec.floorz)) * Z_SCALE;

    // Get shade
    const shade_val: i8 = if (is_ceiling) sec.ceilingshade else sec.floorshade;
    const shade: f32 = @as(f32, @floatFromInt(shade_val)) / 64.0;
    const brightness = std.math.clamp(1.0 - shade, 0.1, 1.0);

    // Collect vertices
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

    // Calculate centroid for fan triangulation
    var cx: f32 = 0;
    var cz: f32 = 0;
    for (0..vertex_count) |i| {
        cx += verts_x[i];
        cz += verts_z[i];
    }
    cx /= @floatFromInt(vertex_count);
    cz /= @floatFromInt(vertex_count);

    // Get texture info if using textures
    const picnum: i32 = if (is_ceiling) sec.ceilingpicnum else sec.floorpicnum;
    const pal: u8 = if (is_ceiling) sec.ceilingpal else sec.floorpal;

    if (use_textures and picnum >= 0 and picnum < constants.MAXTILES) {
        // Set up global render params for texture loading
        pm_globals.globalpicnum = picnum;
        pm_globals.globalpal = pal;
        pm_globals.globalshade = shade_val;

        // Get/load texture
        const pth = texture.gltex(picnum, pal, 0);

        if (pth) |p| {
            gl.glEnable(gl.GL_TEXTURE_2D);
            gl.glBindTexture(gl.GL_TEXTURE_2D, p.glpic);
            gl.glColor4f(brightness, brightness, brightness, 1.0);
        } else {
            gl.glDisable(gl.GL_TEXTURE_2D);
            if (is_ceiling) {
                gl.glColor3f(brightness * 0.3, brightness * 0.3, brightness * 0.5);
            } else {
                gl.glColor3f(brightness * 0.5, brightness * 0.4, brightness * 0.3);
            }
        }
    } else {
        // Color-only mode
        gl.glDisable(gl.GL_TEXTURE_2D);
        if (is_ceiling) {
            gl.glColor3f(brightness * 0.3, brightness * 0.3, brightness * 0.5);
        } else {
            gl.glColor3f(brightness * 0.5, brightness * 0.4, brightness * 0.3);
        }
    }

    // Draw as triangle fan from centroid
    gl.glBegin(gl.GL_TRIANGLE_FAN);

    // Texture scale factor for BUILD units
    const tex_scale: f32 = 1.0 / 64.0;

    // Apply floor/ceiling panning
    const xpan: f32 = @as(f32, @floatFromInt(if (is_ceiling) sec.ceilingxpanning else sec.floorxpanning)) / 256.0;
    const ypan: f32 = @as(f32, @floatFromInt(if (is_ceiling) sec.ceilingypanning else sec.floorypanning)) / 256.0;
    _ = sectnum;

    // Center vertex
    gl.glTexCoord2f(cx * tex_scale + xpan, cz * tex_scale + ypan);
    gl.glVertex3f(cx, z, cz);

    // Perimeter vertices - wind correctly for ceiling vs floor
    if (is_ceiling) {
        // Ceiling: reverse winding
        var i: usize = vertex_count;
        while (i > 0) {
            i -= 1;
            gl.glTexCoord2f(verts_x[i] * tex_scale + xpan, verts_z[i] * tex_scale + ypan);
            gl.glVertex3f(verts_x[i], z, verts_z[i]);
        }
        // Close the fan
        gl.glTexCoord2f(verts_x[vertex_count - 1] * tex_scale + xpan, verts_z[vertex_count - 1] * tex_scale + ypan);
        gl.glVertex3f(verts_x[vertex_count - 1], z, verts_z[vertex_count - 1]);
    } else {
        // Floor: normal winding
        for (0..vertex_count) |i| {
            gl.glTexCoord2f(verts_x[i] * tex_scale + xpan, verts_z[i] * tex_scale + ypan);
            gl.glVertex3f(verts_x[i], z, verts_z[i]);
        }
        // Close the fan
        gl.glTexCoord2f(verts_x[0] * tex_scale + xpan, verts_z[0] * tex_scale + ypan);
        gl.glVertex3f(verts_x[0], z, verts_z[0]);
    }

    gl.glEnd();
}

/// Draw a wall with proper sector heights
fn drawWallWithSector(wallnum: usize, sectnum: usize) void {
    if (wallnum >= @as(usize, @intCast(globals.numwalls))) return;

    const wall = &globals.wall[wallnum];
    const wall2 = &globals.wall[@intCast(wall.point2)];
    const sec = &globals.sector[sectnum];

    // Wall endpoints in GL coordinates
    const x1: f32 = @as(f32, @floatFromInt(wall.x)) * BUILD_TO_GL_SCALE;
    const z1: f32 = @as(f32, @floatFromInt(wall.y)) * BUILD_TO_GL_SCALE;
    const x2: f32 = @as(f32, @floatFromInt(wall2.x)) * BUILD_TO_GL_SCALE;
    const z2: f32 = @as(f32, @floatFromInt(wall2.y)) * BUILD_TO_GL_SCALE;

    // Current sector floor and ceiling heights
    const floor_y: f32 = @as(f32, @floatFromInt(-sec.floorz)) * Z_SCALE;
    const ceil_y: f32 = @as(f32, @floatFromInt(-sec.ceilingz)) * Z_SCALE;

    // Calculate wall shade
    const shade: f32 = @as(f32, @floatFromInt(wall.shade)) / 64.0;
    const brightness = std.math.clamp(1.0 - shade, 0.1, 1.0);

    // Calculate wall length for texture coordinates
    const dx = @as(f32, @floatFromInt(wall2.x - wall.x));
    const dy = @as(f32, @floatFromInt(wall2.y - wall.y));
    const wall_len = @sqrt(dx * dx + dy * dy);

    // Texture repeat/panning
    const xrepeat: f32 = @floatFromInt(wall.xrepeat);
    const yrepeat: f32 = @floatFromInt(wall.yrepeat);
    const xpan: f32 = @as(f32, @floatFromInt(wall.xpanning)) / 256.0;
    const ypan: f32 = @as(f32, @floatFromInt(wall.ypanning)) / 256.0;

    if (wall.nextsector < 0) {
        // Solid wall (one-sided) - draw full height
        const picnum = wall.picnum;
        drawTexturedWallQuad(
            x1,
            z1,
            x2,
            z2,
            floor_y,
            ceil_y,
            picnum,
            wall.pal,
            wall.shade,
            brightness,
            wall_len,
            xrepeat,
            yrepeat,
            xpan,
            ypan,
        );
    } else {
        // Portal wall (two-sided) - draw upper and lower portions
        const nextsect: usize = @intCast(wall.nextsector);
        const next_sec = &globals.sector[nextsect];
        const next_floor_y: f32 = @as(f32, @floatFromInt(-next_sec.floorz)) * Z_SCALE;
        const next_ceil_y: f32 = @as(f32, @floatFromInt(-next_sec.ceilingz)) * Z_SCALE;

        // Upper wall (above neighbor ceiling, if any)
        if (ceil_y > next_ceil_y) {
            const picnum = wall.picnum; // Could use overpicnum in some cases
            drawTexturedWallQuad(
                x1,
                z1,
                x2,
                z2,
                next_ceil_y,
                ceil_y,
                picnum,
                wall.pal,
                wall.shade,
                brightness * 0.95,
                wall_len,
                xrepeat,
                yrepeat,
                xpan,
                ypan,
            );
        }

        // Lower wall (below neighbor floor, if any)
        if (next_floor_y > floor_y) {
            const picnum = wall.picnum;
            drawTexturedWallQuad(
                x1,
                z1,
                x2,
                z2,
                floor_y,
                next_floor_y,
                picnum,
                wall.pal,
                wall.shade,
                brightness * 0.9,
                wall_len,
                xrepeat,
                yrepeat,
                xpan,
                ypan,
            );
        }

        // Draw masked/glass wall if applicable (overpicnum)
        if (wall.overpicnum > 0 and (wall.cstat & enums.CstatWall.MASKED) != 0) {
            const portal_bottom = @max(floor_y, next_floor_y);
            const portal_top = @min(ceil_y, next_ceil_y);
            if (portal_top > portal_bottom) {
                gl.glEnable(gl.GL_BLEND);
                drawTexturedWallQuad(
                    x1,
                    z1,
                    x2,
                    z2,
                    portal_bottom,
                    portal_top,
                    wall.overpicnum,
                    wall.pal,
                    wall.shade,
                    brightness,
                    wall_len,
                    xrepeat,
                    yrepeat,
                    xpan,
                    ypan,
                );
            }
        }
    }
}

/// Draw a textured wall quad
fn drawTexturedWallQuad(
    x1: f32,
    z1: f32,
    x2: f32,
    z2: f32,
    y_bottom: f32,
    y_top: f32,
    picnum: i16,
    pal: u8,
    shade: i8,
    brightness: f32,
    wall_len: f32,
    xrepeat: f32,
    yrepeat: f32,
    xpan: f32,
    ypan: f32,
) void {
    if (use_textures and picnum >= 0 and picnum < constants.MAXTILES) {
        // Set up global render params
        pm_globals.globalpicnum = picnum;
        pm_globals.globalpal = pal;
        pm_globals.globalshade = shade;

        // Get/load texture
        const pth = texture.gltex(picnum, pal, 0);

        if (pth) |p| {
            gl.glEnable(gl.GL_TEXTURE_2D);
            gl.glBindTexture(gl.GL_TEXTURE_2D, p.glpic);
            gl.glColor4f(brightness, brightness, brightness, 1.0);

            // Calculate texture coordinates
            // U: horizontal along wall, V: vertical
            const u_scale = xrepeat * 8.0 / wall_len;
            const v_scale = yrepeat / 256.0;

            const tex_u0 = xpan;
            const tex_u1 = tex_u0 + wall_len * u_scale / 64.0;
            const height = y_top - y_bottom;
            const tex_v0 = ypan;
            const tex_v1 = tex_v0 + height * v_scale;

            gl.glBegin(gl.GL_QUADS);
            gl.glTexCoord2f(tex_u0 * p.scale.x, tex_v1 * p.scale.y);
            gl.glVertex3f(x1, y_bottom, z1);
            gl.glTexCoord2f(tex_u1 * p.scale.x, tex_v1 * p.scale.y);
            gl.glVertex3f(x2, y_bottom, z2);
            gl.glTexCoord2f(tex_u1 * p.scale.x, tex_v0 * p.scale.y);
            gl.glVertex3f(x2, y_top, z2);
            gl.glTexCoord2f(tex_u0 * p.scale.x, tex_v0 * p.scale.y);
            gl.glVertex3f(x1, y_top, z1);
            gl.glEnd();
            return;
        }
    }

    // Fallback to color-only
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor3f(brightness, brightness, brightness);
    drawWallQuad(x1, z1, x2, z2, y_bottom, y_top);
}

/// Draw a single wall quad
fn drawWallQuad(x1: f32, z1: f32, x2: f32, z2: f32, y_bottom: f32, y_top: f32) void {
    gl.glBegin(gl.GL_QUADS);

    // Bottom-left
    gl.glVertex3f(x1, y_bottom, z1);
    // Bottom-right
    gl.glVertex3f(x2, y_bottom, z2);
    // Top-right
    gl.glVertex3f(x2, y_top, z2);
    // Top-left
    gl.glVertex3f(x1, y_top, z1);

    gl.glEnd();
}

// =============================================================================
// Sprite Rendering
// =============================================================================

/// Draw a sprite using polymost
pub fn polymost_drawsprite(snum: i32) void {
    if (snum < 0 or snum >= globals.spritesortcnt) return;

    const tspr = globals.tspriteptr[@intCast(snum)];
    if (tspr == null) return;

    const spr = tspr.?;

    // Get sprite position in GL coordinates
    const sx: f32 = @as(f32, @floatFromInt(spr.x)) * BUILD_TO_GL_SCALE;
    const sy: f32 = @as(f32, @floatFromInt(-spr.z)) * Z_SCALE;
    const sz: f32 = @as(f32, @floatFromInt(spr.y)) * BUILD_TO_GL_SCALE;

    // Calculate sprite size
    const xrepeat: f32 = @floatFromInt(spr.xrepeat);
    const yrepeat: f32 = @floatFromInt(spr.yrepeat);
    const sizx = xrepeat * 0.5;
    const sizy = yrepeat * 0.5;

    // Calculate shade
    const shade: f32 = @as(f32, @floatFromInt(spr.shade)) / 64.0;
    const brightness = std.math.clamp(1.0 - shade, 0.1, 1.0);

    // Yellow color for sprites
    gl.glColor3f(brightness, brightness * 0.8, 0.2);

    // Draw simple quad marker for sprite
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex3f(sx - sizx, sy, sz - sizx);
    gl.glVertex3f(sx + sizx, sy, sz - sizx);
    gl.glVertex3f(sx + sizx, sy + sizy, sz + sizx);
    gl.glVertex3f(sx - sizx, sy + sizy, sz + sizx);
    gl.glEnd();
}

// =============================================================================
// Masked Wall Rendering
// =============================================================================

/// Draw a masked wall
pub fn polymost_drawmaskwall(damaskwallcnt: i32) void {
    if (damaskwallcnt < 0 or damaskwallcnt >= constants.MAXWALLSB) return;

    const wallnum = globals.maskwall[@intCast(damaskwallcnt)];
    if (wallnum < 0 or wallnum >= globals.numwalls) return;

    // Find the sector for this wall
    for (0..@as(usize, @intCast(globals.numsectors))) |sectnum| {
        const sec = &globals.sector[sectnum];
        const startwall: i16 = sec.wallptr;
        const endwall = startwall + sec.wallnum;

        if (wallnum >= startwall and wallnum < endwall) {
            drawWallWithSector(@intCast(wallnum), sectnum);
            break;
        }
    }
}

/// Fill a polygon (used for floors and ceilings)
pub fn polymost_fillpolygon(npoints: i32) void {
    if (npoints < 3) return;
    // Polygon filling is handled by drawFlat now
}

/// Core polygon rendering with depth processing
pub fn polymost_domost(x0: f32, y0: f32, x1: f32, y1: f32) void {
    _ = x0;
    _ = y0;
    _ = x1;
    _ = y1;
    // This is part of the full polymost BSP rendering
    // For the explorer demo, we use simpler BFS rendering
}

/// Draw all walls in a bunch
pub fn polymost_drawalls(bunch: i32) void {
    _ = bunch;
    // Bunch rendering is part of full polymost
    // For the explorer demo, we use simpler per-sector rendering
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Check if a wall has translucency
pub fn polymost_maskWallHasTranslucency(wal: *const types.WallType) bool {
    return (wal.cstat & enums.CstatWall.TRANSLUCENT) != 0;
}

/// Check if a sprite has translucency
pub fn polymost_spriteHasTranslucency(tspr: *const types.TSpriteType) bool {
    return (tspr.cstat & enums.CstatSprite.TRANSLUCENT) != 0;
}

/// Check if a sprite is a model or voxel
pub fn polymost_spriteIsModelOrVoxel(tspr: *const types.TSpriteType) bool {
    _ = tspr;
    return false;
}

/// Calculate shade factor for a given shade value
pub fn getshadefactor(shade: i32, pal: i32) f32 {
    _ = pal;
    const shadeFloat = @as(f32, @floatFromInt(shade)) / 64.0;
    return std.math.clamp(1.0 - shadeFloat, 0.0, 1.0);
}

/// Check if tile is eligible for tile shades
pub fn eligible_for_tileshades(picnum: i32, pal: i32) bool {
    _ = picnum;
    _ = pal;
    return true;
}

// =============================================================================
// Tests
// =============================================================================

test "shade factor calculation" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getshadefactor(0, 0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getshadefactor(32, 0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getshadefactor(64, 0), 0.01);
}

test "translucency checks" {
    var wal: types.WallType = std.mem.zeroes(types.WallType);
    try std.testing.expect(!polymost_maskWallHasTranslucency(&wal));

    wal.cstat = enums.CstatWall.TRANSLUCENT;
    try std.testing.expect(polymost_maskWallHasTranslucency(&wal));
}
