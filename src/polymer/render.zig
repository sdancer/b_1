//! Polymer Renderer - Advanced OpenGL Rendering
//! Port from: NBlood/source/build/src/polymer.cpp
//!
//! Polymer is the advanced renderer for the BUILD engine featuring:
//! - Dynamic lighting with multiple light sources
//! - Shadow mapping
//! - Normal mapping
//! - Specular highlights
//! - Per-pixel shading

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");
const polymer_types = @import("types.zig");

const PrLight = polymer_types.PrLight;
const PrSector = polymer_types.PrSector;
const PrWall = polymer_types.PrWall;
const PrSprite = polymer_types.PrSprite;
const PrMaterial = polymer_types.PrMaterial;
const PrPlane = polymer_types.PrPlane;

// =============================================================================
// Polymer State
// =============================================================================

/// Polymer initialization state
pub var polymer_inited: bool = false;

/// Global sector array
var prsectors: [constants.MAXSECTORS]PrSector = undefined;

/// Global wall array
var prwalls: [constants.MAXWALLS]PrWall = undefined;

/// Lights array
var prlights: [polymer_types.PR_MAXLIGHTS]PrLight = undefined;

/// Number of active lights
var lightcount: i32 = 0;

/// Current view position
var viewx: f32 = 0.0;
var viewy: f32 = 0.0;
var viewz: f32 = 0.0;

/// Current view angles
var viewang: f32 = 0.0;
var viewhoriz: f32 = 0.0;

/// Current render depth (for recursion)
var renderdepth: i32 = 0;

/// Maximum light passes per frame
pub var pr_maxlightpasses: i32 = 5;

/// Shadow quality settings
pub var pr_shadows: i32 = 1;
pub var pr_shadowcount: i32 = 4;
pub var pr_shadowdetail: i32 = 4;
pub var pr_shadowfiltering: i32 = 1;

/// Lighting settings
pub var pr_lighting: i32 = 1;
pub var pr_normalmapping: i32 = 1;
pub var pr_specularmapping: i32 = 1;

/// Other settings
pub var pr_fov: i32 = 90;
pub var pr_billboardingmode: i32 = 1;
pub var pr_wireframe: i32 = 0;
pub var pr_gpusmoothing: i32 = 1;
pub var pr_artmapping: i32 = 1;

// =============================================================================
// Initialization
// =============================================================================

/// Initialize the polymer renderer
pub fn polymer_init() i32 {
    if (polymer_inited) return 0;

    // Initialize sector and wall arrays
    for (&prsectors) |*s| {
        s.* = .{};
    }

    for (&prwalls) |*w| {
        w.* = .{};
    }

    // Initialize lights
    for (&prlights) |*l| {
        l.* = .{};
    }

    lightcount = 0;

    polymer_inited = true;
    return 0;
}

/// Uninitialize the polymer renderer
pub fn polymer_uninit() void {
    if (!polymer_inited) return;

    // Free resources
    for (&prsectors) |*s| {
        if (s.verts != null) {
            // Would free the vertex buffer
            s.verts = null;
        }
    }

    polymer_inited = false;
}

/// Initialize GL-specific polymer state
pub fn polymer_glinit() void {
    // Set up GL state for polymer rendering
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);

    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

    gl.glEnable(gl.GL_CULL_FACE);
    gl.glCullFace(gl.GL_BACK);
}

/// Set the aspect ratio
pub fn polymer_setaspect(ang: i32) void {
    _ = ang;
    // Would set up the projection matrix based on aspect ratio
}

/// Load/reload the board geometry
pub fn polymer_loadboard() void {
    // Convert BUILD geometry to polymer structures
    const numsectors = globals.numsectors;
    const numwalls = globals.numwalls;

    for (0..@as(usize, @intCast(numsectors))) |i| {
        initSector(@intCast(i));
    }

    for (0..@as(usize, @intCast(numwalls))) |i| {
        initWall(@intCast(i));
    }
}

// =============================================================================
// Sector/Wall Initialization
// =============================================================================

/// Initialize a polymer sector from BUILD data
fn initSector(sectnum: i16) void {
    if (sectnum < 0 or sectnum >= globals.numsectors) return;

    const sidx: usize = @intCast(sectnum);
    const sec = &globals.sector[sidx];
    const prsec = &prsectors[sidx];

    prsec.wallptr = sec.wallptr;
    prsec.wallnum = sec.wallnum;
    prsec.ceilingz = sec.ceilingz;
    prsec.floorz = sec.floorz;

    // Mark as needing update
    prsec.flags = polymer_types.PrSectorFlags{};
}

/// Initialize a polymer wall from BUILD data
fn initWall(wallnum: i16) void {
    if (wallnum < 0 or wallnum >= globals.numwalls) return;

    const widx: usize = @intCast(wallnum);
    const wal = &globals.wall[widx];
    const prwal = &prwalls[widx];

    prwal.x = wal.x;
    prwal.y = wal.y;
    prwal.point2 = wal.point2;
    prwal.nextsector = wal.nextsector;
    prwal.nextwall = wal.nextwall;

    // Mark as needing update
    prwal.flags = polymer_types.PrWallFlags{};
}

// =============================================================================
// Main Drawing Functions
// =============================================================================

/// Main polymer draw rooms function
pub fn polymer_drawrooms(
    daposx: i32,
    daposy: i32,
    daposz: i32,
    daang: types.Fix16,
    dahoriz: i32,
    dacursectnum: i16,
) void {
    if (!polymer_inited) {
        _ = polymer_init();
    }

    // Store view parameters
    viewx = @as(f32, @floatFromInt(daposx)) / 16.0;
    viewy = @as(f32, @floatFromInt(daposz)) / 256.0;
    viewz = @as(f32, @floatFromInt(daposy)) / 16.0;
    viewang = @as(f32, @floatFromInt(types.fix16ToInt(daang))) * std.math.pi * 2.0 / 2048.0;
    viewhoriz = @as(f32, @floatFromInt(dahoriz));

    // Clear depth buffer
    gl.glClear(gl.GL_DEPTH_BUFFER_BIT);

    // Set up view matrix
    setupViewMatrix();

    // Set up projection matrix
    setupProjectionMatrix();

    // Render the scene
    displayRooms(dacursectnum);

    // Render lights
    if (pr_lighting != 0) {
        renderLights();
    }
}

/// Set up the view matrix
fn setupViewMatrix() void {
    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    // Apply view rotation
    gl.glRotatef(-viewhoriz * 0.087890625, 1.0, 0.0, 0.0);
    gl.glRotatef(-viewang * 180.0 / std.math.pi, 0.0, 1.0, 0.0);

    // Apply view translation
    gl.glTranslatef(-viewx, -viewy, -viewz);
}

/// Set up the projection matrix
fn setupProjectionMatrix() void {
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    const fov = @as(f32, @floatFromInt(pr_fov)) * std.math.pi / 180.0;
    const aspect = @as(f32, @floatFromInt(globals.xdim)) / @as(f32, @floatFromInt(globals.ydim));
    const znear: f32 = 1.0;
    const zfar: f32 = 1000000.0;

    const f = 1.0 / @tan(fov / 2.0);
    const nf = 1.0 / (znear - zfar);

    var proj: [16]f32 = .{
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (zfar + znear) * nf, -1,
        0, 0, 2 * zfar * znear * nf, 0,
    };

    gl.glLoadMatrixf(&proj);
}

/// Display rooms starting from the given sector
fn displayRooms(sectnum: i16) void {
    if (sectnum < 0 or sectnum >= globals.numsectors) return;

    renderdepth = 0;

    // Render the starting sector
    drawSector(sectnum);

    // Would do visibility processing and render connected sectors
}

/// Draw a single sector
fn drawSector(sectnum: i16) void {
    if (sectnum < 0 or sectnum >= globals.numsectors) return;

    const sidx: usize = @intCast(sectnum);
    const sec = &globals.sector[sidx];
    _ = &prsectors[sidx];

    // Draw floor
    drawFloor(sidx, sec);

    // Draw ceiling
    drawCeiling(sidx, sec);

    // Draw walls
    const wallptr: usize = @intCast(sec.wallptr);
    const wallnum: usize = @intCast(sec.wallnum);

    for (wallptr..wallptr + wallnum) |i| {
        drawWall(@intCast(i));
    }
}

/// Draw sector floor
fn drawFloor(sectnum: usize, sec: *const types.SectorType) void {
    _ = sectnum;

    const shade = @as(f32, @floatFromInt(sec.floorshade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    gl.glColor3f(shadeFactor * 0.5, shadeFactor * 0.5, shadeFactor * 0.4);

    // Would draw the floor polygon
}

/// Draw sector ceiling
fn drawCeiling(sectnum: usize, sec: *const types.SectorType) void {
    _ = sectnum;

    const shade = @as(f32, @floatFromInt(sec.ceilingshade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    gl.glColor3f(shadeFactor * 0.4, shadeFactor * 0.4, shadeFactor * 0.5);

    // Would draw the ceiling polygon
}

/// Draw a wall
fn drawWall(wallnum: i16) void {
    if (wallnum < 0 or wallnum >= globals.numwalls) return;

    const widx: usize = @intCast(wallnum);
    const wal = &globals.wall[widx];
    _ = &prwalls[widx];

    const shade = @as(f32, @floatFromInt(wal.shade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    gl.glColor3f(shadeFactor, shadeFactor, shadeFactor);

    // Would draw the wall quad
}

// =============================================================================
// Light Rendering
// =============================================================================

/// Render lights for the scene
fn renderLights() void {
    if (lightcount == 0) return;

    // For each light, render its contribution
    var passcount: i32 = 0;
    for (0..@as(usize, @intCast(lightcount))) |i| {
        if (passcount >= pr_maxlightpasses) break;

        const light = &prlights[i];
        if ((light.flags & polymer_types.PrLightFlags.ACTIVE) != 0) {
            renderLight(light);
            passcount += 1;
        }
    }
}

/// Render a single light's contribution
fn renderLight(light: *const PrLight) void {
    // Would set up additive blending
    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_ONE, gl.GL_ONE);

    // Would render lit geometry
    _ = light;

    // Restore blending
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
}

/// Draw masks (transparent surfaces)
pub fn polymer_drawmasks() void {
    // Draw masked walls and sprites
    // This is called after the main scene
}

/// Draw a sprite
pub fn polymer_drawsprite(snum: i32) void {
    if (snum < 0 or snum >= globals.spritesortcnt) return;

    const tspr = globals.tspriteptr[@intCast(snum)];
    if (tspr == null) return;

    const spr = tspr.?;

    // Calculate sprite position
    const sx = @as(f32, @floatFromInt(spr.x)) / 16.0;
    const sy = @as(f32, @floatFromInt(spr.z)) / 256.0;
    const sz = @as(f32, @floatFromInt(spr.y)) / 16.0;

    // Calculate shade
    const shade = @as(f32, @floatFromInt(spr.shade)) / 64.0;
    const shadeFactor = std.math.clamp(1.0 - shade, 0.0, 1.0);

    gl.glColor3f(shadeFactor, shadeFactor, shadeFactor);

    // Would draw the sprite quad
    _ = sx;
    _ = sy;
    _ = sz;
}

/// Draw a masked wall
pub fn polymer_drawmaskwall(damaskwallcnt: i32) void {
    if (damaskwallcnt < 0) return;

    // Would draw the masked wall
}

/// Fill a polygon
pub fn polymer_fillpolygon(npoints: i32) void {
    if (npoints < 3) return;

    // Would fill the polygon
}

/// Editor pick function
pub fn polymer_editorpick() void {
    // For map editor - pick sector/wall/sprite
}

/// Prepare for rotatesprite
pub fn polymer_inb4rotatesprite(tilenum: i16, pal: u8, shade: i8, method: i32) void {
    _ = tilenum;
    _ = pal;
    _ = shade;
    _ = method;
    // Set up 2D rendering state
}

/// Cleanup after rotatesprite
pub fn polymer_postrotatesprite() void {
    // Restore 3D rendering state
}

// =============================================================================
// Light Management
// =============================================================================

/// Add a light to the scene
pub fn polymer_addlight(light: *const PrLight) i16 {
    if (lightcount >= polymer_types.PR_MAXLIGHTS) return -1;

    const idx = lightcount;
    prlights[@intCast(idx)] = light.*;
    prlights[@intCast(idx)].flags |= polymer_types.PrLightFlags.ACTIVE;
    lightcount += 1;

    return @intCast(idx);
}

/// Delete a light
pub fn polymer_deletelight(lighti: i16) void {
    if (lighti < 0 or lighti >= lightcount) return;

    prlights[@intCast(lighti)].flags &= ~polymer_types.PrLightFlags.ACTIVE;

    // Would compact the array
}

/// Reset all lights
pub fn polymer_resetlights() void {
    for (&prlights) |*l| {
        l.flags = 0;
    }
    lightcount = 0;
}

/// Invalidate light data
pub fn polymer_invalidatelights() void {
    for (0..@as(usize, @intCast(lightcount))) |i| {
        prlights[i].flags |= polymer_types.PrLightFlags.INVALIDATE;
    }
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Invalidate texture cache
pub fn polymer_texinvalidate() void {
    // Mark all textures as needing reload
    for (&prsectors) |*s| {
        s.flags = polymer_types.PrSectorFlags{};
    }
    for (&prwalls) |*w| {
        w.flags = polymer_types.PrWallFlags{};
    }
}

/// Define a high palette lookup
pub fn polymer_definehighpalookup(basepalnum: u8, palnum: u8, data: [*]u8) void {
    _ = basepalnum;
    _ = palnum;
    _ = data;
    // Would create a palette lookup texture
}

/// Check if high palette exists
pub fn polymer_havehighpalookup(basepalnum: u8, palnum: u8) bool {
    _ = basepalnum;
    _ = palnum;
    return false;
}

/// Invalidate a sprite
pub fn polymer_invalidatesprite(i: i32) void {
    _ = i;
    // Mark sprite as needing update
}

/// Invalidate an art tile
pub fn polymer_invalidateartmap(tilenum: i32) void {
    _ = tilenum;
    // Mark tile as needing reload
}

/// Check if tile is eligible for art mapping
pub fn polymer_eligible_for_artmap(tilenum: i32, pth: ?*const anyopaque) bool {
    _ = tilenum;
    _ = pth;
    return pr_artmapping != 0;
}

/// Check if using art mapping
pub fn polymer_useartmapping() bool {
    return pr_artmapping != 0;
}

// =============================================================================
// Tests
// =============================================================================

// Note: Polymer tests require GL context and are tested separately
