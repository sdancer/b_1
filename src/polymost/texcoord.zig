//! Polymost Texture Coordinate System
//! Port from: NBlood/source/build/src/polymost.cpp (lines 104-115, vec.h)
//!
//! Implements the texture plane equations used by polymost for perspective-correct
//! texture mapping. The plane equations define gradients for depth (d), horizontal
//! texture coordinate (u), and vertical texture coordinate (v).
//!
//! For any screen point (sx, sy), the texture coordinates are calculated as:
//!   depth = xtex.d * sx + ytex.d * sy + otex.d
//!   u = (xtex.u * sx + ytex.u * sy + otex.u) / depth
//!   v = (xtex.v * sx + ytex.v * sy + otex.v) / depth

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const art = @import("../fs/art.zig");
const pmglobals = @import("globals.zig");
const engine_globals = @import("../globals.zig");

// =============================================================================
// Core Types
// =============================================================================

/// Texture plane equation coefficients.
/// For screen point (sx, sy): value = xtex.*sx + ytex.*sy + otex.*
pub const TexPlane = struct {
    /// Depth/perspective component (1/w)
    d: f64 = 0,
    /// Horizontal texture coordinate gradient
    u: f64 = 0,
    /// Vertical texture coordinate gradient
    v: f64 = 0,

    /// Add two planes
    pub fn add(self: TexPlane, other: TexPlane) TexPlane {
        return .{
            .d = self.d + other.d,
            .u = self.u + other.u,
            .v = self.v + other.v,
        };
    }

    /// Multiply plane by scalar
    pub fn scale(self: TexPlane, s: f64) TexPlane {
        return .{
            .d = self.d * s,
            .u = self.u * s,
            .v = self.v * s,
        };
    }
};

// =============================================================================
// Global Texture Coordinate State
// =============================================================================

/// X gradient plane (screen X direction)
pub var xtex: TexPlane = .{};

/// Y gradient plane (screen Y direction)
pub var ytex: TexPlane = .{};

/// Origin offset plane
pub var otex: TexPlane = .{};

/// Secondary X gradient (for masked/translucent rendering)
pub var xtex2: TexPlane = .{};

/// Secondary Y gradient
pub var ytex2: TexPlane = .{};

/// Secondary origin offset
pub var otex2: TexPlane = .{};

// =============================================================================
// Texture Coordinate Calculation Functions
// =============================================================================

/// Calculate wall texture coordinates for a horizontal wall span.
/// Port from: polymost.cpp lines 6394-6401, 7316-7340
///
/// This sets up the plane equations for texture mapping on a wall segment
/// between screen positions x0 and x1.
///
/// Parameters:
///   x0, x1: Screen X coordinates of wall endpoints
///   ryp0, ryp1: Reciprocal Y perspective (1/z) at each endpoint
///   t0, t1: Wall texture distance parameters (position along wall)
///   xrepeat: Wall xrepeat from wall struct
///   xpanning: Wall xpanning from wall struct
pub fn calcWallTexCoords(
    x0: f64,
    x1: f64,
    ryp0: f64,
    ryp1: f64,
    t0: f64,
    t1: f64,
    xrepeat: u8,
    xpanning: u8,
) void {
    const dx = x0 - x1;
    if (@abs(dx) < 0.0001) return; // Avoid division by zero

    // Depth component gradient
    xtex.d = (ryp0 - ryp1) * pmglobals.gxyaspect / dx;
    ytex.d = 0;
    otex.d = ryp0 * pmglobals.gxyaspect - xtex.d * x0;

    // U (horizontal) component - texture position along wall
    const xr8: f64 = @as(f64, @floatFromInt(xrepeat)) * 8.0;
    xtex.u = (t0 * ryp0 - t1 * ryp1) * pmglobals.gxyaspect * xr8 / dx;
    otex.u = t0 * ryp0 * pmglobals.gxyaspect * xr8 - xtex.u * x0;
    ytex.u = 0;

    // Apply xpanning offset
    const xpan: f64 = @floatFromInt(xpanning);
    otex.u += xpan * otex.d;
    xtex.u += xpan * xtex.d;
}

/// Calculate vertical panning for wall textures.
/// Port from: polymost.cpp lines 5057-5098
///
/// This calculates the V (vertical) texture coordinate gradients for walls,
/// taking into account y-repeat, y-panning, and the wall height on screen.
///
/// Parameters:
///   refposz: Reference Z position (ceiling or floor height)
///   ryp0: Reciprocal Y perspective at x0
///   ryp1: Reciprocal Y perspective at x1
///   x0, x1: Screen X endpoints
///   ypanning: Wall ypanning value
///   yrepeat: Wall yrepeat value
///   dopancor: Whether to apply panning correction
pub fn calcYPanning(
    refposz: i32,
    ryp0: f64,
    ryp1: f64,
    x0: f64,
    x1: f64,
    ypanning: u8,
    yrepeat: u8,
    dopancor: bool,
) void {
    const dx = x1 - x0;
    if (@abs(dx) < 0.0001 or @abs(ryp0) < 0.0001) return;

    // Calculate screen Y positions for top of wall
    const gposz: f64 = @floatFromInt(engine_globals.globalposz);
    const refz: f64 = @floatFromInt(refposz);
    const t0 = (refz - gposz) * ryp0 + pmglobals.ghoriz;
    const t1 = (refz - gposz) * ryp1 + pmglobals.ghoriz;

    // Calculate V gradient scaling factor
    const yr: f64 = @floatFromInt(yrepeat);
    const t = (xtex.d * x0 + otex.d) * yr / (dx * ryp0 * 2048.0);

    // Get tile size for panning calculation
    const picnum = pmglobals.globalpicnum;
    var i: i32 = undefined;
    if (picnum >= 0 and picnum < constants.MAXTILES) {
        const tiley = art.tilesizy[@intCast(picnum)];
        // Find power of 2 >= tile height
        i = 1;
        while (i < tiley) : (i <<= 1) {}
    } else {
        i = 64;
    }

    // Apply panning correction for non-power-of-2 adjustment
    var ypan: i32 = @intCast(ypanning);
    if (dopancor and picnum >= 0 and picnum < constants.MAXTILES) {
        const tiley = art.tilesizy[@intCast(picnum)];
        if (tiley > 0 and i > tiley) {
            const yoffs: i32 = @intFromFloat(@as(f32, @floatFromInt(i - tiley)) * (255.0 / @as(f32, @floatFromInt(i))));
            if (ypan > 256 - yoffs) {
                ypan -= yoffs;
            }
        }
    }

    // Calculate final panning offset in texture pixels
    const fy: f64 = @as(f64, @floatFromInt(ypan * i)) * (1.0 / 256.0);

    // Set V gradient
    xtex.v = (t0 - t1) * t;
    ytex.v = dx * t;
    otex.v = -xtex.v * x0 - ytex.v * t0 + fy * otex.d;
    xtex.v += fy * xtex.d;
    ytex.v += fy * ytex.d;
}

/// Calculate floor/ceiling texture coordinates.
/// Port from: polymost.cpp polymost_internal_nonparallaxed() lines 4895-4955
///
/// Sets up texture plane equations for a horizontal surface (floor or ceiling).
///
/// Parameters:
///   sectnum: Sector number
///   is_ceiling: True for ceiling, false for floor
pub fn calcFlatTexCoords(sectnum: i16, is_ceiling: bool) void {
    if (sectnum < 0 or sectnum >= engine_globals.numsectors) return;

    const sec = &engine_globals.sector[@intCast(sectnum)];

    // Get surface properties
    const stat: u16 = if (is_ceiling) sec.ceilingstat else sec.floorstat;
    const cf_z: i32 = if (is_ceiling) sec.ceilingz else sec.floorz;
    const gposz: f64 = @floatFromInt(engine_globals.globalposz);
    const cfz: f64 = @floatFromInt(cf_z);

    // Base depth gradient
    xtex.d = 0;
    ytex.d = pmglobals.gxyaspect;

    // For non-sloped surfaces, scale depth by height difference
    if ((stat & 2) == 0 and cf_z != engine_globals.globalposz) {
        ytex.d /= (cfz - gposz);
    }
    otex.d = -pmglobals.ghoriz * ytex.d;

    // Get position and angle factors
    var ft: [4]f64 = undefined;
    ft[0] = @floatFromInt(engine_globals.globalposx);
    ft[1] = @floatFromInt(engine_globals.globalposy);
    ft[2] = pmglobals.gcosang;
    ft[3] = pmglobals.gsinang;

    // Scale based on orientation bit 3 (8x vs 16x repeat)
    if ((stat & 8) != 0) {
        // Expanded texture (8x)
        ft[0] *= (1.0 / 8.0);
        ft[1] *= -(1.0 / 8.0);
        ft[2] *= (1.0 / 2097152.0);
        ft[3] *= (1.0 / 2097152.0);
    } else {
        // Normal texture (16x)
        ft[0] *= (1.0 / 16.0);
        ft[1] *= -(1.0 / 16.0);
        ft[2] *= (1.0 / 4194304.0);
        ft[3] *= (1.0 / 4194304.0);
    }

    // U/V gradients
    xtex.u = ft[3] * -(1.0 / 65536.0) * pmglobals.fviewingrange;
    xtex.v = ft[2] * -(1.0 / 65536.0) * pmglobals.fviewingrange;
    ytex.u = ft[0] * ytex.d;
    ytex.v = ft[1] * ytex.d;
    otex.u = ft[0] * otex.d;
    otex.v = ft[1] * otex.d;

    // Center the texture mapping
    otex.u += (ft[2] - xtex.u) * pmglobals.ghalfx;
    otex.v -= (ft[3] + xtex.v) * pmglobals.ghalfx;

    // Handle orientation flags
    if ((stat & 4) != 0) {
        // Swap U/V (rotate 90 degrees)
        std.mem.swap(f64, &xtex.u, &xtex.v);
        std.mem.swap(f64, &ytex.u, &ytex.v);
        std.mem.swap(f64, &otex.u, &otex.v);
    }
    if ((stat & 16) != 0) {
        // Flip U
        xtex.u = -xtex.u;
        ytex.u = -ytex.u;
        otex.u = -otex.u;
    }
    if ((stat & 32) != 0) {
        // Flip V
        xtex.v = -xtex.v;
        ytex.v = -ytex.v;
        otex.v = -otex.v;
    }

    // Handle relative alignment (first wall alignment)
    if ((stat & 64) != 0) {
        // Align to first wall of sector
        const wal = &engine_globals.wall[@intCast(sec.wallptr)];
        const wal2 = &engine_globals.wall[@intCast(wal.point2)];

        const dx: f64 = @floatFromInt(wal2.x - wal.x);
        const dy: f64 = @floatFromInt(wal2.y - wal.y);
        const len = @sqrt(dx * dx + dy * dy);

        if (len > 0.0001) {
            const vcos = dx / len;
            const vsin = dy / len;

            // Rotate texture coordinates to align with wall
            const ox: f64 = @floatFromInt(wal.x);
            const oy: f64 = @floatFromInt(wal.y);

            // Store old values
            const oxtu = xtex.u;
            const oxtv = xtex.v;
            const oytu = ytex.u;
            const oytv = ytex.v;
            const ootu = otex.u;
            const ootv = otex.v;

            // Rotate
            xtex.u = oxtu * vcos + oxtv * vsin;
            xtex.v = -oxtu * vsin + oxtv * vcos;
            ytex.u = oytu * vcos + oytv * vsin;
            ytex.v = -oytu * vsin + oytv * vcos;
            otex.u = ootu * vcos + ootv * vsin;
            otex.v = -ootu * vsin + ootv * vcos;

            // Translate to wall origin
            otex.u -= ox * ytex.u + oy * xtex.u;
            otex.v -= ox * ytex.v + oy * xtex.v;
        }
    }

    // Apply panning
    const xpan: f64 = @floatFromInt(if (is_ceiling) sec.ceilingxpanning else sec.floorxpanning);
    const ypan: f64 = @floatFromInt(if (is_ceiling) sec.ceilingypanning else sec.floorypanning);

    if (xpan != 0 or ypan != 0) {
        // Panning is in 1/256th of texture size units
        otex.u += xpan * otex.d * (1.0 / 256.0);
        xtex.u += xpan * xtex.d * (1.0 / 256.0);
        ytex.u += xpan * ytex.d * (1.0 / 256.0);

        otex.v += ypan * otex.d * (1.0 / 256.0);
        xtex.v += ypan * xtex.d * (1.0 / 256.0);
        ytex.v += ypan * ytex.d * (1.0 / 256.0);
    }
}

/// Calculate sprite texture coordinates.
/// Port from: polymost.cpp polymost_drawsprite() around lines 8072, 8166, 8380
///
/// Parameters:
///   ryp0: Reciprocal Y perspective for sprite
///   tsiz: Texture size (x, y)
///   xoff, yoff: Sprite offset
///   xrepeat, yrepeat: Sprite repeat values
///   flip_x, flip_y: Whether to flip the sprite
pub fn calcSpriteTexCoords(
    ryp0: f64,
    tsiz: types.Vec2,
    xoff: i8,
    yoff: i8,
    xrepeat: u8,
    yrepeat: u8,
    flip_x: bool,
    flip_y: bool,
) void {
    // Simple sprite: depth is constant
    otex.d = ryp0 * pmglobals.gviewxrange;
    xtex.d = 0;
    ytex.d = 0;

    // Texture coordinates
    const sizx: f64 = @floatFromInt(tsiz.x);
    const sizy: f64 = @floatFromInt(tsiz.y);
    const xo: f64 = @floatFromInt(xoff);
    const yo: f64 = @floatFromInt(yoff);
    const xr: f64 = @floatFromInt(xrepeat);
    const yr: f64 = @floatFromInt(yrepeat);

    _ = xo;
    _ = yo;
    _ = xr;
    _ = yr;

    // U coordinates (horizontal)
    xtex.u = if (flip_x) -sizx else sizx;
    ytex.u = 0;
    otex.u = if (flip_x) sizx else 0;

    // V coordinates (vertical)
    xtex.v = 0;
    ytex.v = if (flip_y) -sizy else sizy;
    otex.v = if (flip_y) sizy else 0;
}

/// Evaluate texture coordinates at a screen position.
/// Returns (u, v) texture coordinates.
pub fn evalTexCoord(sx: f64, sy: f64) struct { u: f64, v: f64 } {
    const dd = xtex.d * sx + ytex.d * sy + otex.d;
    if (@abs(dd) < 0.0000001) {
        return .{ .u = 0, .v = 0 };
    }
    const uu = (xtex.u * sx + ytex.u * sy + otex.u) / dd;
    const vv = (xtex.v * sx + ytex.v * sy + otex.v) / dd;
    return .{ .u = uu, .v = vv };
}

/// Evaluate depth at a screen position.
pub fn evalDepth(sx: f64, sy: f64) f64 {
    return xtex.d * sx + ytex.d * sy + otex.d;
}

/// Reset all texture coordinate state
pub fn reset() void {
    xtex = .{};
    ytex = .{};
    otex = .{};
    xtex2 = .{};
    ytex2 = .{};
    otex2 = .{};
}

/// Copy primary texture coords to secondary
pub fn copyToSecondary() void {
    xtex2 = xtex;
    ytex2 = ytex;
    otex2 = otex;
}

// =============================================================================
// Tests
// =============================================================================

test "TexPlane operations" {
    const a: TexPlane = .{ .d = 1, .u = 2, .v = 3 };
    const b: TexPlane = .{ .d = 4, .u = 5, .v = 6 };

    const sum = a.add(b);
    try std.testing.expectApproxEqAbs(@as(f64, 5), sum.d, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 7), sum.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 9), sum.v, 0.001);

    const scaled = a.scale(2);
    try std.testing.expectApproxEqAbs(@as(f64, 2), scaled.d, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 4), scaled.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 6), scaled.v, 0.001);
}

test "evalTexCoord" {
    reset();
    xtex = .{ .d = 0.1, .u = 1, .v = 0 };
    ytex = .{ .d = 0, .u = 0, .v = 1 };
    otex = .{ .d = 1, .u = 0, .v = 0 };

    const result = evalTexCoord(10, 20);
    // dd = 0.1 * 10 + 0 * 20 + 1 = 2
    // uu = (1 * 10 + 0 * 20 + 0) / 2 = 5
    // vv = (0 * 10 + 1 * 20 + 0) / 2 = 10
    try std.testing.expectApproxEqAbs(@as(f64, 5), result.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10), result.v, 0.001);
}
