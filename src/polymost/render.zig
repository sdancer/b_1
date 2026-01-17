//! Polymost Renderer - OpenGL 1.x/2.0 Rendering
//! Port from: NBlood/source/build/src/polymost.cpp
//!
//! This is the primary hardware-accelerated renderer for the BUILD engine.
//! It uses OpenGL for rendering walls, floors, ceilings, and sprites.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");

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
pub var gvisibility2: f32 = 0.0;
pub var gtaession: f32 = 0.0;

/// Texture coordinates for current operation
pub var gux: f32 = 0.0;
pub var guy: f32 = 0.0;
pub var guo: f32 = 0.0;
pub var gvx: f32 = 0.0;
pub var gvy: f32 = 0.0;
pub var gvo: f32 = 0.0;

/// Current transformation state
pub var ghalfx: f32 = 0.0;
pub var ghalfy: f32 = 0.0;
pub var ghoriz: f32 = 0.0;
pub var ghoriz2: f32 = 0.0;
pub var ghorizycenter: f32 = 0.0;
pub var gvrcorrection: f32 = 1.0;
pub var gshang: f32 = 0.0;
pub var gchang: f32 = 1.0;
pub var gshang2: f32 = 0.0;
pub var gchang2: f32 = 1.0;

/// View parameters
pub var gviewxrange: f32 = 0.0;
pub var gyxscale: f32 = 0.0;
pub var gxyaspect: f32 = 0.0;

/// Cosine/sine of view angle
pub var gcosang: f32 = 0.0;
pub var gsinang: f32 = 0.0;
pub var gcosang2: f32 = 0.0;
pub var gsinang2: f32 = 0.0;

/// Global position in floating point
pub var globalposx: f64 = 0.0;
pub var globalposy: f64 = 0.0;
pub var globalposz: f64 = 0.0;

/// Global render flags
pub var globalorientation: i32 = 0;

/// Drawing clipping arrays
const SCISDIST: f32 = 1.0;
const MAXYS_BUFFER = 2048;
var dxb1: [MAXYS_BUFFER]f32 = undefined;
var dxb2: [MAXYS_BUFFER]f32 = undefined;

/// Most array for depth processing
var domost_rejectcount: i32 = 0;

// =============================================================================
// Initialization
// =============================================================================

/// Initialize the polymost renderer
pub fn polymost_init() i32 {
    if (polymost_inited) return 0;

    // Initialize default state
    ghalfx = @as(f32, @floatFromInt(globals.xdim)) / 2.0;
    ghalfy = @as(f32, @floatFromInt(globals.ydim)) / 2.0;
    ghoriz = ghalfy;
    ghorizycenter = ghoriz;

    // Initialize GL state
    polymost_glinit();

    polymost_inited = true;
    return 0;
}

/// Initialize GL-specific polymost state
pub fn polymost_glinit() void {
    // Set up default GL state for polymost rendering
    gl.glEnable(gl.GL_TEXTURE_2D);
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);

    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

    // Set up texture environment
    gl.glTexEnvf(gl.GL_TEXTURE_ENV, gl.GL_TEXTURE_ENV_MODE, @floatFromInt(gl.GL_MODULATE));

    // Enable alpha testing for transparent textures
    gl.glEnable(gl.GL_ALPHA_TEST);
    gl.glAlphaFunc(gl.GL_GREATER, 0.32);

    // Initialize matrices
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();
}

/// Reset polymost GL state
pub fn polymost_glreset() void {
    polymost_inited = false;
}

// =============================================================================
// Main Drawing Functions
// =============================================================================

/// Main polymost draw rooms function
/// This is the entry point for rendering the 3D view
pub fn polymost_drawrooms() void {
    if (!polymost_inited) {
        _ = polymost_init();
    }

    // Set up view transformation
    setupViewTransform();

    // Clear depth buffer
    gl.glClear(gl.GL_DEPTH_BUFFER_BIT);

    // Set up projection matrix
    setupProjection();

    // Set up modelview matrix for the view
    setupModelView();

    // Render the scene
    // This would process sectors and walls via polymost_drawalls
    renderScene();
}

/// Set up the view transformation parameters
fn setupViewTransform() void {
    const xdim = @as(f32, @floatFromInt(globals.xdim));
    const ydim = @as(f32, @floatFromInt(globals.ydim));

    ghalfx = xdim / 2.0;
    ghalfy = ydim / 2.0;

    // Calculate view range
    gviewxrange = @as(f32, @floatFromInt(globals.viewingrange)) / 65536.0;

    // Calculate aspect ratio
    gxyaspect = @as(f32, @floatFromInt(globals.yxaspect)) / 65536.0;
    gyxscale = xdim * gxyaspect / ydim;

    // Get view angle components
    const ang = globals.globalang;
    const angf = @as(f32, @floatFromInt(ang)) * std.math.pi * 2.0 / 2048.0;
    gcosang = @cos(angf);
    gsinang = @sin(angf);
    gcosang2 = gcosang;
    gsinang2 = gsinang;

    // Get horizon
    ghoriz = ghalfy + @as(f32, @floatFromInt(types.fix16ToInt(globals.globalhoriz))) * gxyaspect;
    ghorizycenter = ghalfy;
}

/// Set up the projection matrix
fn setupProjection() void {
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    const xdim = @as(f32, @floatFromInt(globals.xdim));
    const ydim = @as(f32, @floatFromInt(globals.ydim));

    // Calculate field of view
    const fov = 90.0 * std.math.pi / 180.0;
    const aspect = xdim / ydim;
    const znear: f32 = 1.0;
    const zfar: f32 = 1000000.0;

    const f = 1.0 / @tan(fov / 2.0);

    // Build perspective matrix manually (OpenGL 1.x style)
    var proj: [16]f32 = .{
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (zfar + znear) / (znear - zfar), -1,
        0, 0, (2 * zfar * znear) / (znear - zfar), 0,
    };

    gl.glLoadMatrixf(&proj);
}

/// Set up the modelview matrix
fn setupModelView() void {
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    // Apply view rotation
    gl.glRotatef(-@as(f32, @floatFromInt(types.fix16ToInt(globals.globalhoriz))) * 0.087890625, 1.0, 0.0, 0.0);
    gl.glRotatef(-@as(f32, @floatFromInt(globals.globalang)) * 0.087890625, 0.0, 1.0, 0.0);

    // Apply view translation (convert from BUILD units)
    const scale: f32 = 1.0 / 16.0;
    gl.glTranslatef(
        -@as(f32, @floatFromInt(globals.globalposx)) * scale,
        -@as(f32, @floatFromInt(globals.globalposz)) * scale / 16.0,
        -@as(f32, @floatFromInt(globals.globalposy)) * scale,
    );
}

/// Render the scene (sectors and walls)
fn renderScene() void {
    // Process all visible sectors
    const numsectors = globals.numsectors;
    if (numsectors <= 0) return;

    // Start from the current sector
    var sectnum = globals.globalcursectnum;
    if (sectnum < 0 or sectnum >= numsectors) {
        sectnum = 0;
    }

    // Render the starting sector
    drawSector(@intCast(sectnum));
}

/// Draw a single sector
fn drawSector(sectnum: usize) void {
    if (sectnum >= @as(usize, @intCast(globals.numsectors))) return;

    const sec = &globals.sector[sectnum];

    // Draw floor and ceiling
    drawFloor(sectnum, sec);
    drawCeiling(sectnum, sec);

    // Draw all walls in the sector
    const wallptr = @as(usize, @intCast(sec.wallptr));
    const wallnum = @as(usize, @intCast(sec.wallnum));

    for (wallptr..wallptr + wallnum) |i| {
        drawWall(i);
    }
}

/// Draw sector floor
fn drawFloor(sectnum: usize, sec: *const types.SectorType) void {
    _ = sectnum;

    const floorz = @as(f32, @floatFromInt(sec.floorz)) / 16.0;

    // Calculate floor shade
    const shade = @as(f32, @floatFromInt(sec.floorshade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    gl.glColor3f(shadeFactor * 0.5, shadeFactor * 0.5, shadeFactor * 0.5);

    // Draw floor polygon (simplified - full implementation would use actual geometry)
    _ = floorz;
}

/// Draw sector ceiling
fn drawCeiling(sectnum: usize, sec: *const types.SectorType) void {
    _ = sectnum;

    const ceilingz = @as(f32, @floatFromInt(sec.ceilingz)) / 16.0;

    // Calculate ceiling shade
    const shade = @as(f32, @floatFromInt(sec.ceilingshade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    gl.glColor3f(shadeFactor * 0.4, shadeFactor * 0.4, shadeFactor * 0.6);

    // Draw ceiling polygon (simplified)
    _ = ceilingz;
}

/// Draw a single wall
fn drawWall(wallnum: usize) void {
    if (wallnum >= @as(usize, @intCast(globals.numwalls))) return;

    const wal = &globals.wall[wallnum];
    const wal2 = &globals.wall[@intCast(wal.point2)];

    // Wall endpoints in world space
    const x1 = @as(f32, @floatFromInt(wal.x));
    const y1 = @as(f32, @floatFromInt(wal.y));
    const x2 = @as(f32, @floatFromInt(wal2.x));
    const y2 = @as(f32, @floatFromInt(wal2.y));

    // Get the sectors on each side of the wall
    const sectnum = wal.nextsector;

    // Calculate wall shade
    const shade = @as(f32, @floatFromInt(wal.shade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    gl.glColor3f(shadeFactor, shadeFactor, shadeFactor);

    // Draw wall (simplified - full implementation would handle all wall types)
    if (sectnum < 0) {
        // Solid wall (one-sided)
        drawSolidWall(x1, y1, x2, y2, wal);
    } else {
        // Portal wall (two-sided)
        drawPortalWall(x1, y1, x2, y2, wal, @intCast(sectnum));
    }
}

/// Draw a solid (one-sided) wall
fn drawSolidWall(x1: f32, y1: f32, x2: f32, y2: f32, wal: *const types.WallType) void {
    _ = wal;

    // This is a simplified version - real implementation would use proper Z coordinates
    const z1: f32 = 0.0;
    const z2: f32 = 256.0;
    const scale: f32 = 1.0 / 16.0;

    gl.glBegin(gl.GL_QUADS);

    gl.glTexCoord2f(0.0, 0.0);
    gl.glVertex3f(x1 * scale, z1 * scale, y1 * scale);

    gl.glTexCoord2f(1.0, 0.0);
    gl.glVertex3f(x2 * scale, z1 * scale, y2 * scale);

    gl.glTexCoord2f(1.0, 1.0);
    gl.glVertex3f(x2 * scale, z2 * scale, y2 * scale);

    gl.glTexCoord2f(0.0, 1.0);
    gl.glVertex3f(x1 * scale, z2 * scale, y1 * scale);

    gl.glEnd();
}

/// Draw a portal (two-sided) wall
fn drawPortalWall(x1: f32, y1: f32, x2: f32, y2: f32, wal: *const types.WallType, nextsector: usize) void {
    _ = wal;
    _ = nextsector;

    // Portal walls have upper and lower portions
    // This is simplified - full implementation would handle all cases
    const scale: f32 = 1.0 / 16.0;

    // Draw upper wall portion
    gl.glBegin(gl.GL_QUADS);

    gl.glTexCoord2f(0.0, 0.0);
    gl.glVertex3f(x1 * scale, 200.0 * scale, y1 * scale);

    gl.glTexCoord2f(1.0, 0.0);
    gl.glVertex3f(x2 * scale, 200.0 * scale, y2 * scale);

    gl.glTexCoord2f(1.0, 1.0);
    gl.glVertex3f(x2 * scale, 256.0 * scale, y2 * scale);

    gl.glTexCoord2f(0.0, 1.0);
    gl.glVertex3f(x1 * scale, 256.0 * scale, y1 * scale);

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

    // Get sprite position
    const sx = @as(f32, @floatFromInt(spr.x)) / 16.0;
    const sy = @as(f32, @floatFromInt(spr.z)) / 256.0;
    const sz = @as(f32, @floatFromInt(spr.y)) / 16.0;

    // Calculate sprite size
    const xrepeat = @as(f32, @floatFromInt(spr.xrepeat));
    const yrepeat = @as(f32, @floatFromInt(spr.yrepeat));
    const sizx = xrepeat * 2.0;
    const sizy = yrepeat * 2.0;

    // Get sprite type (face, wall, floor)
    const cstat = spr.cstat;
    const spriteType = cstat & enums.CstatSprite.ALIGNMENT_MASK;

    // Calculate shade
    const shade = @as(f32, @floatFromInt(spr.shade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    // Handle translucency
    var alpha: f32 = 1.0;
    if ((cstat & enums.CstatSprite.TRANSLUCENT) != 0) {
        alpha = if ((cstat & enums.CstatSprite.TRANSLUCENT_INVERT) != 0) 0.33 else 0.66;
    }

    gl.glColor4f(shadeFactor, shadeFactor, shadeFactor, alpha);

    // Draw based on sprite type
    if (spriteType == enums.CstatSprite.ALIGNMENT_WALL) {
        drawWallSprite(sx, sy, sz, sizx, sizy, spr.ang);
    } else if (spriteType == enums.CstatSprite.ALIGNMENT_FLOOR) {
        drawFloorSprite(sx, sy, sz, sizx, sizy, spr.ang);
    } else {
        // Face sprite (always faces camera)
        drawFaceSprite(sx, sy, sz, sizx, sizy);
    }
}

/// Draw a face sprite (billboard)
fn drawFaceSprite(x: f32, y: f32, z: f32, sizx: f32, sizy: f32) void {
    // Get the inverse modelview matrix for billboarding
    // Simplified - proper implementation would extract camera right/up vectors

    gl.glPushMatrix();
    gl.glTranslatef(x, y, z);

    // Apply billboarding by zeroing rotation
    // This is simplified - real implementation would use proper billboard matrix

    gl.glBegin(gl.GL_QUADS);

    gl.glTexCoord2f(0.0, 0.0);
    gl.glVertex3f(-sizx / 2.0, 0.0, 0.0);

    gl.glTexCoord2f(1.0, 0.0);
    gl.glVertex3f(sizx / 2.0, 0.0, 0.0);

    gl.glTexCoord2f(1.0, 1.0);
    gl.glVertex3f(sizx / 2.0, sizy, 0.0);

    gl.glTexCoord2f(0.0, 1.0);
    gl.glVertex3f(-sizx / 2.0, sizy, 0.0);

    gl.glEnd();

    gl.glPopMatrix();
}

/// Draw a wall-aligned sprite
fn drawWallSprite(x: f32, y: f32, z: f32, sizx: f32, sizy: f32, ang: i16) void {
    const angf = @as(f32, @floatFromInt(ang)) * std.math.pi * 2.0 / 2048.0;
    const cos_a = @cos(angf);
    const sin_a = @sin(angf);

    const hx = sizx / 2.0;

    gl.glBegin(gl.GL_QUADS);

    gl.glTexCoord2f(0.0, 0.0);
    gl.glVertex3f(x - hx * cos_a, y, z - hx * sin_a);

    gl.glTexCoord2f(1.0, 0.0);
    gl.glVertex3f(x + hx * cos_a, y, z + hx * sin_a);

    gl.glTexCoord2f(1.0, 1.0);
    gl.glVertex3f(x + hx * cos_a, y + sizy, z + hx * sin_a);

    gl.glTexCoord2f(0.0, 1.0);
    gl.glVertex3f(x - hx * cos_a, y + sizy, z - hx * sin_a);

    gl.glEnd();
}

/// Draw a floor-aligned sprite
fn drawFloorSprite(x: f32, y: f32, z: f32, sizx: f32, sizy: f32, ang: i16) void {
    const angf = @as(f32, @floatFromInt(ang)) * std.math.pi * 2.0 / 2048.0;
    const cos_a = @cos(angf);
    const sin_a = @sin(angf);

    const hx = sizx / 2.0;
    const hy = sizy / 2.0;

    gl.glBegin(gl.GL_QUADS);

    gl.glTexCoord2f(0.0, 0.0);
    gl.glVertex3f(x - hx * cos_a + hy * sin_a, y, z - hx * sin_a - hy * cos_a);

    gl.glTexCoord2f(1.0, 0.0);
    gl.glVertex3f(x + hx * cos_a + hy * sin_a, y, z + hx * sin_a - hy * cos_a);

    gl.glTexCoord2f(1.0, 1.0);
    gl.glVertex3f(x + hx * cos_a - hy * sin_a, y, z + hx * sin_a + hy * cos_a);

    gl.glTexCoord2f(0.0, 1.0);
    gl.glVertex3f(x - hx * cos_a - hy * sin_a, y, z - hx * sin_a + hy * cos_a);

    gl.glEnd();
}

// =============================================================================
// Masked Wall Rendering
// =============================================================================

/// Draw a masked wall
pub fn polymost_drawmaskwall(damaskwallcnt: i32) void {
    if (damaskwallcnt < 0 or damaskwallcnt >= constants.MAXWALLSB) return;

    // Get the masked wall index from the list
    const wallnum = globals.maskwall[@intCast(damaskwallcnt)];
    if (wallnum < 0 or wallnum >= globals.numwalls) return;

    const wal = &globals.wall[@intCast(wallnum)];

    // Enable alpha blending for masked walls
    gl_state.setEnabled(gl_state.GL_BLEND);

    // Check if wall has translucency
    if ((wal.cstat & enums.CstatWall.TRANSLUCENT) != 0) {
        if ((wal.cstat & enums.CstatWall.TRANS_FLIP) != 0) {
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        } else {
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        }
    }

    // Draw the masked wall
    drawWall(@intCast(wallnum));
}

// =============================================================================
// Polygon Filling
// =============================================================================

/// Fill a polygon (used for floors and ceilings)
pub fn polymost_fillpolygon(npoints: i32) void {
    if (npoints < 3) return;

    // This would use the rx1/ry1 arrays for polygon vertices
    // Simplified for now

    gl.glBegin(gl.GL_POLYGON);

    for (0..@as(usize, @intCast(npoints))) |_| {
        // Would use actual vertex data from rx1/ry1 arrays
        gl.glVertex3f(0.0, 0.0, 0.0);
    }

    gl.glEnd();
}

// =============================================================================
// Domost Algorithm (Core Rendering)
// =============================================================================

/// Core polygon rendering with depth processing
/// This is the heart of the polymost renderer
pub fn polymost_domost(x0: f32, y0: f32, x1: f32, y1: f32) void {
    // The domost algorithm processes horizontal spans for rendering
    // It maintains a list of visible spans and clips geometry against them

    if (x0 >= x1) return;

    // Clamp to screen bounds
    const fx0 = @max(0.0, x0);
    const fx1 = @min(@as(f32, @floatFromInt(globals.xdim)), x1);
    const fy0 = @max(0.0, y0);
    const fy1 = @min(@as(f32, @floatFromInt(globals.ydim)), y1);

    if (fx0 >= fx1) return;

    // Store in domost buffer for later processing
    _ = fy0;
    _ = fy1;

    domost_rejectcount += 1;
}

/// Draw all walls in a bunch (group of connected walls)
pub fn polymost_drawalls(bunch: i32) void {
    // Process the bunch of walls
    // A bunch is a group of walls that should be drawn together
    // for correct visibility ordering

    if (bunch < 0) return;

    // TODO: Implement bunch processing
    // This would iterate through walls in the bunch and draw them
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
    // Would check against voxel and model definitions
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

// Note: polymost_init test is skipped because it requires a GL context

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
