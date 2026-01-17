//! Polymost Global Render State
//! Port from: NBlood/source/build/src/polymost.cpp (lines 81-205, 6927-6952)
//!
//! Contains all global state variables used by the polymost renderer for
//! view calculations, texture coordinate generation, and rendering.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const engine_globals = @import("../globals.zig");

// =============================================================================
// Screen/View Parameters
// =============================================================================

/// Half screen width (xdim/2)
pub var ghalfx: f64 = 0;

/// Half screen height (ydim/2)
pub var ghalfy: f64 = 0;

/// Horizon line Y position
pub var ghoriz: f64 = 0;

/// Secondary horizon value (for y-shearing)
pub var ghoriz2: f64 = 0;

/// Horizon correction factor
pub var ghorizcorrect: f64 = 0;

/// Visibility/fog factor
pub var gvisibility: f64 = 0;

/// View range correction (viewingrange/65536)
pub var gvrcorrection: f64 = 1.0;

/// Float xdim
pub var fxdim: f64 = 0;

/// Float ydim
pub var fydim: f64 = 0;

/// Float ydimen (usually same as fydim)
pub var fydimen: f64 = 0;

/// Float viewingrange
pub var fviewingrange: f64 = 0;

/// (xyaspect * viewingrange) * 5 / (65536 * 262144)
pub var gxyaspect: f64 = 0;

/// 1 / (ghalfx * 1024)
pub var grhalfxdown10: f64 = 0;

/// grhalfxdown10x (variant)
pub var grhalfxdown10x: f64 = 0;

// =============================================================================
// Angle/Rotation Parameters
// =============================================================================

/// cos(globalang) scaled
pub var gcosang: f64 = 0;

/// sin(globalang) scaled
pub var gsinang: f64 = 0;

/// gcosang * gvrcorrection
pub var gcosang2: f64 = 0;

/// gsinang * gvrcorrection
pub var gsinang2: f64 = 0;

/// cos(horizon angle) - look up/down
pub var gchang: f64 = 1.0;

/// sin(horizon angle) - look up/down
pub var gshang: f64 = 0;

/// cos(tilt angle)
pub var gctang: f64 = 1.0;

/// sin(tilt angle)
pub var gstang: f64 = 0;

/// Tilt angle (radians)
pub var gtang: f64 = 0;

/// cos(globalang) as float (high precision)
pub var fcosglobalang: f64 = 0;

/// sin(globalang) as float (high precision)
pub var fsinglobalang: f64 = 0;

// =============================================================================
// View/Rendering Globals
// =============================================================================

/// Y/X scale factor
pub var gyxscale: f64 = 0;

/// viewingrange * fxdimen / (32768*1024)
pub var gviewxrange: f64 = 0;

/// Shade scale for lighting
pub var shadescale: f64 = 1.0;

/// Whether shade scaling is unbounded
pub var shadescale_unbounded: bool = false;

/// Center horizon value for polymost
pub var polymostcenterhoriz: i32 = 100;

// =============================================================================
// Current Rendering Parameters (from engine globals, duplicated for convenience)
// =============================================================================

/// Current tile being rendered
pub var globalpicnum: i32 = 0;

/// Current shade level
pub var globalshade: i32 = 0;

/// Current palette
pub var globalpal: i32 = 0;

/// Current orientation flags
pub var globalorientation: i32 = 0;

/// Rendering flags
pub var globalflags: i32 = 0;

/// Visibility value
pub var globalvisibility: i32 = 0;

// =============================================================================
// Configuration Flags
// =============================================================================

/// Enable new shading mode (0-4)
pub var r_usenewshading: i32 = 4;

/// Enable shade interpolation
pub var r_shadeinterpolate: bool = true;

/// Use tileshades
pub var r_usetileshades: bool = true;

/// Use indexed color textures
pub var r_useindexedcolortextures: bool = true;

/// Enable fullbrights
pub var r_fullbrights: bool = true;

/// Flat sky rendering
pub var r_flatsky: bool = true;

/// NPOT wall mode
pub var r_npotwallmode: i32 = 2;

/// Parallax sky clamping
pub var r_parallaxskyclamping: bool = true;

/// Parallax sky panning
pub var r_parallaxskypanning: bool = true;

/// Y-shearing mode (false = real look up/down)
pub var r_yshearing: bool = false;

/// Animation smoothing
pub var r_animsmoothing: bool = true;

/// Detail mapping
pub var r_detailmapping: bool = true;

/// Glow mapping
pub var r_glowmapping: bool = true;

/// Polygon mode (0=fill, 1=line, 2=point)
pub var r_polygonmode: i32 = 0;

/// Projection hacks mode
pub var glprojectionhacks: i32 = 2;

/// Texture filter mode
pub var gltexfiltermode: i32 = 0;

/// Anisotropy level
pub var glanisotropy: i32 = 16;

// =============================================================================
// Rendering State
// =============================================================================

/// Whether polymost has been initialized
pub var polymost_inited: bool = false;

/// Currently rendering 2D elements
pub var polymost2d: bool = false;

/// Preparing mirror rendering
pub var inpreparemirror: bool = false;

/// Drawing skybox face (0 = not drawing, 1-6 = face index)
pub var drawingskybox: i32 = 0;

/// Sky clamp hack active
pub var skyclamphack: bool = false;

// =============================================================================
// Fog Colors
// =============================================================================

/// Fog color type
pub const FogColor = struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 1,
};

/// Current fog color
pub var fogcol: FogColor = .{};

/// Fog factor per palette
pub var fogfactor: [constants.MAXPALOOKUPS]f32 = [_]f32{0} ** constants.MAXPALOOKUPS;

// =============================================================================
// Tile Size Cache
// =============================================================================

/// Packed tile size (x in bits 0-3, y in bits 4-7 as log2 sizes)
pub var picsiz: [constants.MAXTILES]u8 = [_]u8{0} ** constants.MAXTILES;

// =============================================================================
// Initialization Functions
// =============================================================================

/// Calculate picsiz values for all tiles
pub fn calcPicSiz() void {
    const art = @import("../fs/art.zig");
    for (0..constants.MAXTILES) |i| {
        const sizx = art.tilesizx[i];
        const sizy = art.tilesizy[i];
        if (sizx <= 0 or sizy <= 0) {
            picsiz[i] = 0;
            continue;
        }
        // Find log2 of dimensions (rounded up to power of 2)
        const xbits: u4 = @intCast(log2ceil(@intCast(sizx)));
        const ybits: u4 = @intCast(log2ceil(@intCast(sizy)));
        picsiz[i] = xbits | (@as(u8, ybits) << 4);
    }
}

/// Calculate ceil(log2(n))
fn log2ceil(n: u32) u32 {
    if (n <= 1) return 0;
    var val = n - 1;
    var result: u32 = 0;
    while (val > 0) : (val >>= 1) {
        result += 1;
    }
    return result;
}

/// Initialize polymost render state from engine globals
pub fn initFromEngine() void {
    fxdim = @floatFromInt(engine_globals.xdim);
    fydim = @floatFromInt(engine_globals.ydim);
    fydimen = fydim;
    fviewingrange = @floatFromInt(engine_globals.viewingrange);

    ghalfx = fxdim / 2.0;
    ghalfy = fydim / 2.0;

    if (ghalfx > 0) {
        grhalfxdown10 = 1.0 / (ghalfx * 1024.0);
        grhalfxdown10x = grhalfxdown10;
    }

    // Initialize angle calculations
    updateAngleState();
}

/// Update angle-related state from engine globals
pub fn updateAngleState() void {
    const ang_rad = @as(f64, @floatFromInt(engine_globals.globalang)) * std.math.pi / 1024.0;
    fcosglobalang = @cos(ang_rad) * 16383.0;
    fsinglobalang = @sin(ang_rad) * 16383.0;

    gvrcorrection = fviewingrange / 65536.0;
    if (glprojectionhacks == 2 and fydim > 0 and fxdim > 0) {
        // Calculate zenith glitch correction
        const yxasp: f64 = @floatFromInt(engine_globals.yxaspect);
        const verticalfovtan = (fviewingrange * fydim * 5.0) / (yxasp * fxdim * 4.0);
        const verticalfov = std.math.atan(verticalfovtan) * (2.0 / std.math.pi);
        const maxhorizangle: f64 = 0.6361136; // horiz of 199 in degrees
        const zenglitch = verticalfov + maxhorizangle - 0.95;
        if (zenglitch > 0) {
            gvrcorrection /= (zenglitch * 2.5) + 1.0;
        }
    }

    // X dimension scale
    const xdimenscale: i32 = engine_globals.viewingrange; // simplified
    gyxscale = @as(f64, @floatFromInt(xdimenscale)) * (1.0 / 131072.0);

    // Aspect ratio coefficient
    const xyaspect: f64 = @floatFromInt(engine_globals.yxaspect);
    gxyaspect = (xyaspect * fviewingrange) * (5.0 / (65536.0 * 262144.0));

    // View x range
    gviewxrange = fviewingrange * fxdim * (1.0 / (32768.0 * 1024.0));

    // Scaled cos/sin values
    gcosang = fcosglobalang * (1.0 / 262144.0);
    gsinang = fsinglobalang * (1.0 / 262144.0);
    gcosang2 = gcosang * (fviewingrange * (1.0 / 65536.0));
    gsinang2 = gsinang * (fviewingrange * (1.0 / 65536.0));

    // Horizon
    const horiz_fix16 = engine_globals.globalhoriz;
    ghoriz = types.fix16ToFloat(horiz_fix16);
    ghorizcorrect = @as(f64, @floatFromInt(100 - polymostcenterhoriz)) *
        @as(f64, @floatFromInt(xdimenscale)) / @as(f64, @floatFromInt(engine_globals.viewingrange));

    // Visibility
    gvisibility = @as(f64, @floatFromInt(engine_globals.globalvisibility)) * (1.0 / 2097152.0);

    // Look up/down (gchang, gshang)
    if (r_yshearing) {
        gshang = 0;
        gchang = 1;
        ghoriz2 = ghalfy - (ghoriz + ghorizcorrect);
    } else {
        const r = ghalfy - (ghoriz + ghorizcorrect);
        const denom = @sqrt(r * r + ghalfx * ghalfx / (gvrcorrection * gvrcorrection));
        if (denom > 0.0001) {
            gshang = r / denom;
            gchang = @sqrt(1.0 - gshang * gshang);
        } else {
            gshang = 0;
            gchang = 1;
        }
        ghoriz2 = 0;
    }

    // Reset ghoriz to center
    ghoriz = ghalfy;

    // Tilt angle (gctang, gstang)
    gctang = @cos(gtang);
    gstang = @sin(gtang);

    if (@abs(gstang) < 0.001) {
        gstang = 0;
        gctang = if (gctang > 0) 1.0 else -1.0;
    }

    if (inpreparemirror) {
        gstang = -gstang;
    }
}

/// Sync global rendering parameters from engine
pub fn syncRenderParams() void {
    globalpicnum = engine_globals.globalpicnum;
    globalshade = engine_globals.globalshade;
    globalpal = engine_globals.globalpal;
    globalorientation = engine_globals.globalorientation;
    globalflags = engine_globals.globalflags;
    globalvisibility = engine_globals.globalvisibility;
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Get shade factor for a given shade and palette
pub fn getShadeFactor(shade: i32, pal: i32) f32 {
    _ = pal;
    const shadeFloat = @as(f32, @floatFromInt(shade)) / 64.0;
    return std.math.clamp(1.0 - shadeFloat * @as(f32, @floatCast(shadescale)), 0.0, 1.0);
}

/// Check if a tile is eligible for tileshades
pub fn eligibleForTileshades(picnum: i32, pal: i32) bool {
    _ = picnum;
    _ = pal;
    return r_usetileshades;
}

// =============================================================================
// Tests
// =============================================================================

test "log2ceil" {
    try std.testing.expectEqual(@as(u32, 0), log2ceil(1));
    try std.testing.expectEqual(@as(u32, 1), log2ceil(2));
    try std.testing.expectEqual(@as(u32, 2), log2ceil(3));
    try std.testing.expectEqual(@as(u32, 2), log2ceil(4));
    try std.testing.expectEqual(@as(u32, 3), log2ceil(5));
    try std.testing.expectEqual(@as(u32, 4), log2ceil(16));
    try std.testing.expectEqual(@as(u32, 5), log2ceil(17));
}

test "shade factor" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getShadeFactor(0, 0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getShadeFactor(32, 0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getShadeFactor(64, 0), 0.01);
}
