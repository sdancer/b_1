//! Polymost Drawing Functions
//! Port from: NBlood/source/build/src/polymost.cpp polymost_drawpoly() lines 2600-2900
//!
//! Contains the core polygon rendering functions that draw textured geometry
//! using the texture coordinate plane equations from texcoord.zig.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const engine_globals = @import("../globals.zig");
const gl = @import("../gl/bindings.zig");
const gl_state = @import("../gl/state.zig");

const polymost_types = @import("types.zig");
const pm_globals = @import("globals.zig");
const texcoord = @import("texcoord.zig");
const texture = @import("texture.zig");

const PthType = polymost_types.PthType;
const ColType = polymost_types.ColType;
const Dameth = polymost_types.Dameth;
const Vec2f = types.Vec2f;

// =============================================================================
// Constants
// =============================================================================

/// Maximum vertices in a polygon
const MAX_DRAWPOLY_VERTS: usize = 8;

/// Near clipping distance
const SCISDIST: f32 = 0.1;

// =============================================================================
// Drawing State
// =============================================================================

/// Current drawing method
var drawpoly_alpha: f32 = 1.0;

/// S-repeat for texture
var drawpoly_srepeat: bool = false;

/// T-repeat for texture
var drawpoly_trepeat: bool = false;

// =============================================================================
// Core Drawing Functions
// =============================================================================

/// Draw a textured polygon.
/// Port from: polymost.cpp polymost_drawpoly() lines 2600-2900
///
/// This is the main function for drawing textured geometry. It:
/// 1. Gets/loads the texture for the current globalpicnum
/// 2. Calculates texture coordinates for each vertex using plane equations
/// 3. Transforms screen coords to 3D and submits to OpenGL
///
/// Parameters:
///   dpxy: Array of screen-space polygon vertices
///   npoints: Number of vertices in the polygon
///   method: Drawing method flags (Dameth)
pub fn polymost_drawpoly(dpxy: []const Vec2f, npoints: i32, method: i32) void {
    if (npoints < 3) return;

    const n: usize = @intCast(npoints);
    if (n > MAX_DRAWPOLY_VERTS) return;

    // Get texture
    const pth = texture.gltex(pm_globals.globalpicnum, pm_globals.globalpal, method);

    // Set up blending based on method
    if (Dameth.hasTranslucency(method)) {
        gl.glEnable(gl.GL_BLEND);
        if ((method & Dameth.MASKPROPS) == Dameth.TRANS1) {
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
            drawpoly_alpha = 0.66;
        } else {
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
            drawpoly_alpha = 0.33;
        }
    } else if (Dameth.hasMask(method)) {
        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        drawpoly_alpha = 1.0;
    } else {
        gl.glDisable(gl.GL_BLEND);
        drawpoly_alpha = 1.0;
    }

    // Bind texture if available
    if (pth) |p| {
        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, p.glpic);
    } else {
        gl.glDisable(gl.GL_TEXTURE_2D);
    }

    // Calculate shade factor
    const shade_factor = pm_globals.getShadeFactor(pm_globals.globalshade, pm_globals.globalpal);
    gl.glColor4f(shade_factor, shade_factor, shade_factor, drawpoly_alpha);

    // Draw the polygon
    gl.glBegin(gl.GL_TRIANGLE_FAN);

    for (dpxy[0..n]) |v| {
        const px: f64 = v.x;
        const py: f64 = v.y;

        // Evaluate texture coordinates from plane equations
        const dd = texcoord.evalDepth(px, py);
        if (dd <= 0.00001) continue; // Behind camera

        const uv = texcoord.evalTexCoord(px, py);

        // Apply texture scale if we have a texture
        var u: f32 = @floatCast(uv.u);
        var t: f32 = @floatCast(uv.v);

        if (pth) |p| {
            u *= p.scale.x;
            t *= p.scale.y;
        }

        gl.glTexCoord2f(u, t);

        // Transform screen coordinates to 3D view space
        // Screen (px, py) -> normalized device coords -> view space
        const ndc_x = (px - pm_globals.ghalfx) / pm_globals.ghalfx;
        const ndc_y = (pm_globals.ghoriz - py) / pm_globals.ghalfy;

        // Apply perspective
        const depth: f32 = @floatCast(1.0 / dd);
        const world_x: f32 = @floatCast(ndc_x * depth * pm_globals.ghalfx / pm_globals.gvrcorrection);
        const world_y: f32 = @floatCast(ndc_y * depth * pm_globals.ghalfy / pm_globals.gvrcorrection);
        const world_z: f32 = depth;

        gl.glVertex3f(world_x, world_y, world_z);
    }

    gl.glEnd();
}

/// Draw a polygon with explicit color (no texture)
/// Used for colored geometry rendering (floors, ceilings, walls without textures)
pub fn polymost_drawpoly_color(dpxy: []const Vec2f, npoints: i32, color: ColType) void {
    if (npoints < 3) return;

    const n: usize = @intCast(npoints);
    if (n > MAX_DRAWPOLY_VERTS) return;

    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4ub(color.r, color.g, color.b, color.a);

    gl.glBegin(gl.GL_TRIANGLE_FAN);

    for (dpxy[0..n]) |v| {
        const px: f64 = v.x;
        const py: f64 = v.y;

        const dd = texcoord.evalDepth(px, py);
        if (dd <= 0.00001) continue;

        const ndc_x = (px - pm_globals.ghalfx) / pm_globals.ghalfx;
        const ndc_y = (pm_globals.ghoriz - py) / pm_globals.ghalfy;

        const depth: f32 = @floatCast(1.0 / dd);
        const world_x: f32 = @floatCast(ndc_x * depth * pm_globals.ghalfx / pm_globals.gvrcorrection);
        const world_y: f32 = @floatCast(ndc_y * depth * pm_globals.ghalfy / pm_globals.gvrcorrection);
        const world_z: f32 = depth;

        gl.glVertex3f(world_x, world_y, world_z);
    }

    gl.glEnd();
}

/// Draw a wall segment with texture coordinates already set up
/// This is a simplified version for when texture coords are pre-calculated
pub fn drawWallQuadTextured(
    x0: f32,
    z0: f32,
    x1: f32,
    z1: f32,
    y_bottom: f32,
    y_top: f32,
    tex_u0: f32,
    tex_u1: f32,
    v_bottom: f32,
    v_top: f32,
) void {
    gl.glBegin(gl.GL_QUADS);

    // Bottom-left
    gl.glTexCoord2f(tex_u0, v_bottom);
    gl.glVertex3f(x0, y_bottom, z0);

    // Bottom-right
    gl.glTexCoord2f(tex_u1, v_bottom);
    gl.glVertex3f(x1, y_bottom, z1);

    // Top-right
    gl.glTexCoord2f(tex_u1, v_top);
    gl.glVertex3f(x1, y_top, z1);

    // Top-left
    gl.glTexCoord2f(tex_u0, v_top);
    gl.glVertex3f(x0, y_top, z0);

    gl.glEnd();
}

/// Draw floor/ceiling flat with texture
pub fn drawFlatTextured(
    verts_x: []const f32,
    verts_z: []const f32,
    vertex_count: usize,
    y: f32,
    is_ceiling: bool,
    picnum: i32,
    method: i32,
) void {
    if (vertex_count < 3) return;

    // Get texture
    const pth = texture.gltex(picnum, pm_globals.globalpal, method);

    if (pth) |p| {
        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, p.glpic);
    } else {
        gl.glDisable(gl.GL_TEXTURE_2D);
    }

    // Calculate shade
    const shade_factor = pm_globals.getShadeFactor(pm_globals.globalshade, pm_globals.globalpal);
    gl.glColor4f(shade_factor, shade_factor, shade_factor, 1.0);

    // Calculate centroid for fan triangulation
    var cx: f32 = 0;
    var cz: f32 = 0;
    for (0..vertex_count) |i| {
        cx += verts_x[i];
        cz += verts_z[i];
    }
    cx /= @floatFromInt(vertex_count);
    cz /= @floatFromInt(vertex_count);

    // Texture scale factor (in BUILD units)
    const tex_scale: f32 = 1.0 / 64.0;

    gl.glBegin(gl.GL_TRIANGLE_FAN);

    // Center vertex
    gl.glTexCoord2f(cx * tex_scale, cz * tex_scale);
    gl.glVertex3f(cx, y, cz);

    // Perimeter vertices
    if (is_ceiling) {
        var i: usize = vertex_count;
        while (i > 0) {
            i -= 1;
            gl.glTexCoord2f(verts_x[i] * tex_scale, verts_z[i] * tex_scale);
            gl.glVertex3f(verts_x[i], y, verts_z[i]);
        }
        gl.glTexCoord2f(verts_x[vertex_count - 1] * tex_scale, verts_z[vertex_count - 1] * tex_scale);
        gl.glVertex3f(verts_x[vertex_count - 1], y, verts_z[vertex_count - 1]);
    } else {
        for (0..vertex_count) |i| {
            gl.glTexCoord2f(verts_x[i] * tex_scale, verts_z[i] * tex_scale);
            gl.glVertex3f(verts_x[i], y, verts_z[i]);
        }
        gl.glTexCoord2f(verts_x[0] * tex_scale, verts_z[0] * tex_scale);
        gl.glVertex3f(verts_x[0], y, verts_z[0]);
    }

    gl.glEnd();
}

// =============================================================================
// Clipping Functions
// =============================================================================

/// Clip a polygon against a line (for wall clipping)
pub fn clipPoly(
    inpts: []const Vec2f,
    n_in: usize,
    outpts: []Vec2f,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
) usize {
    if (n_in < 3 or outpts.len < n_in + 1) return 0;

    var n_out: usize = 0;
    const dx = x1 - x0;
    const dy = y1 - y0;

    for (0..n_in) |i| {
        const j = (i + 1) % n_in;
        const p0 = inpts[i];
        const p1 = inpts[j];

        // Calculate which side of the line each point is on
        const d0 = dx * (p0.y - y0) - dy * (p0.x - x0);
        const d1 = dx * (p1.y - y0) - dy * (p1.x - x0);

        if (d0 >= 0) {
            // p0 is inside
            if (n_out < outpts.len) {
                outpts[n_out] = p0;
                n_out += 1;
            }
        }

        if ((d0 >= 0) != (d1 >= 0)) {
            // Edge crosses the line, compute intersection
            const t = d0 / (d0 - d1);
            if (n_out < outpts.len) {
                outpts[n_out] = .{
                    .x = p0.x + t * (p1.x - p0.x),
                    .y = p0.y + t * (p1.y - p0.y),
                };
                n_out += 1;
            }
        }
    }

    return n_out;
}

/// Clip polygon to screen bounds
pub fn clipPolyToScreen(
    inpts: []const Vec2f,
    n_in: usize,
    outpts: []Vec2f,
    xdim: i32,
    ydim: i32,
) usize {
    if (n_in < 3) return 0;

    const fxdim: f32 = @floatFromInt(xdim);
    const fydim: f32 = @floatFromInt(ydim);

    var temp1: [MAX_DRAWPOLY_VERTS * 2]Vec2f = undefined;
    var temp2: [MAX_DRAWPOLY_VERTS * 2]Vec2f = undefined;

    // Left edge
    var n = clipPoly(inpts, n_in, &temp1, 0, 0, 0, fydim);
    if (n < 3) return 0;

    // Right edge
    n = clipPoly(temp1[0..n], n, &temp2, fxdim, 0, fxdim, fydim);
    if (n < 3) return 0;

    // Top edge
    n = clipPoly(temp2[0..n], n, &temp1, 0, 0, fxdim, 0);
    if (n < 3) return 0;

    // Bottom edge
    n = clipPoly(temp1[0..n], n, outpts, 0, fydim, fxdim, fydim);

    return n;
}

// =============================================================================
// State Management
// =============================================================================

/// Set up GL state for textured rendering
pub fn beginTexturedRendering() void {
    gl.glEnable(gl.GL_TEXTURE_2D);
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);
    gl.glEnable(gl.GL_BLEND);
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
}

/// Set up GL state for color-only rendering
pub fn beginColorRendering() void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);
}

/// Reset drawing state
pub fn resetDrawState() void {
    drawpoly_alpha = 1.0;
    drawpoly_srepeat = false;
    drawpoly_trepeat = false;
}

// =============================================================================
// Tests
// =============================================================================

test "clipPoly simple" {
    const inpts = [_]Vec2f{
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 0, .y = 1 },
    };
    var outpts: [8]Vec2f = undefined;

    // Clip against line x = 0 (vertical line at origin, keeping right side)
    const n = clipPoly(&inpts, 3, &outpts, 0, -1, 0, 1);

    // Should produce triangle with clipped left corner
    try std.testing.expect(n >= 3);
}
