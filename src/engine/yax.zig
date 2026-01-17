//! YAX - True Room Over Room Support
//! Port from: NBlood/source/build/src/engine.cpp (YAX functions)
//!
//! YAX (Yet Another eXtension) is the BUILD engine's system for
//! "true" room-over-room rendering, where sectors can be stacked
//! vertically and the player can move between levels.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");

// =============================================================================
// YAX Constants
// =============================================================================

/// Maximum number of bunches (groups of connected ROR sectors)
pub const YAX_MAXBUNCHES = constants.YAX_MAXBUNCHES;

/// YAX extension bit mask
pub const YAX_BIT = 0x00800000;

/// Ceiling/Floor index
pub const YAX_CEILING: usize = 0;
pub const YAX_FLOOR: usize = 1;

// =============================================================================
// YAX State
// =============================================================================

/// Whether YAX is globally enabled
pub var yax_globallev: i32 = -1;

/// Whether YAX rendering is active
pub var r_tror_nomaskpass: i32 = 0;

/// Current rendering bunch
pub var yax_globalbunch: i32 = -1;

/// Number of bunches in the current map
pub var numyaxbunches: i32 = 0;

/// Bunch number for each sector (ceiling and floor)
/// [sector][0=ceiling, 1=floor]
pub var yax_bunchnum: [constants.MAXSECTORS][2]i16 = undefined;

/// Next wall in YAX chain
/// [wall][0=ceiling, 1=floor]
pub var yax_nextwall: [constants.MAXWALLS][2]i16 = undefined;

/// Head sectors for each bunch
/// [0=ceiling, 1=floor][bunch]
pub var headsectbunch: [2][YAX_MAXBUNCHES]i16 = undefined;

/// Next sector in bunch chain
pub var nextsectbunch: [2][constants.MAXSECTORS]i16 = undefined;

// =============================================================================
// Initialization
// =============================================================================

/// Initialize YAX state for a new map
pub fn yax_init() void {
    numyaxbunches = 0;
    yax_globallev = -1;
    yax_globalbunch = -1;

    // Initialize bunch numbers to -1 (no bunch)
    for (&yax_bunchnum) |*s| {
        s[0] = -1;
        s[1] = -1;
    }

    // Initialize next wall to -1
    for (&yax_nextwall) |*w| {
        w[0] = -1;
        w[1] = -1;
    }

    // Initialize head sectors
    for (&headsectbunch[0]) |*h| h.* = -1;
    for (&headsectbunch[1]) |*h| h.* = -1;

    // Initialize next sector
    for (&nextsectbunch[0]) |*n| n.* = -1;
    for (&nextsectbunch[1]) |*n| n.* = -1;
}

// =============================================================================
// Bunch Management
// =============================================================================

/// Get the bunch number for a sector (ceiling or floor)
/// cf: 0 = ceiling, 1 = floor
pub fn yax_getbunch(sectnum: i16, cf: i16) i16 {
    if (sectnum < 0 or sectnum >= globals.numsectors) return -1;
    if (cf < 0 or cf > 1) return -1;

    return yax_bunchnum[@intCast(sectnum)][@intCast(cf)];
}

/// Get both bunch numbers for a sector
pub fn yax_getbunches(sectnum: i16, cb: *i16, fb: *i16) void {
    if (sectnum < 0 or sectnum >= globals.numsectors) {
        cb.* = -1;
        fb.* = -1;
        return;
    }

    cb.* = yax_bunchnum[@intCast(sectnum)][YAX_CEILING];
    fb.* = yax_bunchnum[@intCast(sectnum)][YAX_FLOOR];
}

/// Set the bunch number for a sector
pub fn yax_setbunch(sectnum: i16, cf: i16, bunchnum: i16) void {
    if (sectnum < 0 or sectnum >= globals.numsectors) return;
    if (cf < 0 or cf > 1) return;

    const sidx: usize = @intCast(sectnum);
    const cfidx: usize = @intCast(cf);
    const oldbunch = yax_bunchnum[sidx][cfidx];

    // Remove from old bunch
    if (oldbunch >= 0) {
        // Would need to update the bunch linked list
    }

    yax_bunchnum[sidx][cfidx] = bunchnum;

    // Add to new bunch
    if (bunchnum >= 0) {
        const bidx: usize = @intCast(bunchnum);
        nextsectbunch[cfidx][sidx] = headsectbunch[cfidx][bidx];
        headsectbunch[cfidx][bidx] = sectnum;
    }
}

// =============================================================================
// Wall YAX Extensions
// =============================================================================

/// Get the next wall in the YAX chain
pub fn yax_getnextwall(wallnum: i16, cf: i16) i16 {
    if (wallnum < 0 or wallnum >= globals.numwalls) return -1;
    if (cf < 0 or cf > 1) return -1;

    return yax_nextwall[@intCast(wallnum)][@intCast(cf)];
}

/// Set the next wall in the YAX chain
pub fn yax_setnextwall(wallnum: i16, cf: i16, thenextwall: i16) void {
    if (wallnum < 0 or wallnum >= globals.numwalls) return;
    if (cf < 0 or cf > 1) return;

    yax_nextwall[@intCast(wallnum)][@intCast(cf)] = thenextwall;
}

/// Get the next sector through a wall's YAX portal
pub fn yax_vnextsec(wallnum: i16, cf: i16) i32 {
    const nextwall = yax_getnextwall(wallnum, cf);
    if (nextwall < 0) return -1;

    // Get the sector of the next wall
    // This requires iterating through walls to find which sector contains it
    // For now, return -1 (not implemented)
    return -1;
}

// =============================================================================
// Rendering
// =============================================================================

/// Prepare for YAX-aware room drawing
pub fn yax_preparedrawrooms() void {
    yax_globallev = -1;
    yax_globalbunch = -1;
}

/// Draw rooms with YAX support
/// animatesprites: callback for sprite animation
/// sectnum: starting sector
/// didmirror: whether we're rendering a mirror
/// smoothr: smoothing ratio for interpolation
pub fn yax_drawrooms(
    animatesprites: ?*const fn () void,
    sectnum: i16,
    didmirror: i32,
    smoothr: i32,
) void {
    _ = animatesprites;
    _ = didmirror;
    _ = smoothr;

    if (numyaxbunches <= 0) {
        // No YAX, just do normal rendering
        return;
    }

    // Get bunches for the current sector
    var cb: i16 = undefined;
    var fb: i16 = undefined;
    yax_getbunches(sectnum, &cb, &fb);

    // Render ceiling bunch first (above)
    if (cb >= 0) {
        yax_globalbunch = cb;
        yax_globallev = -1;
        // Would recursively render the upper level
    }

    // Render floor bunch (below)
    if (fb >= 0) {
        yax_globalbunch = fb;
        yax_globallev = 1;
        // Would recursively render the lower level
    }

    yax_globallev = 0;
    yax_globalbunch = -1;
}

/// Update YAX state after map changes
pub fn yax_update(resetstat: i32) void {
    _ = resetstat;

    // Recount bunches and rebuild linked lists
    numyaxbunches = 0;

    for (0..@as(usize, @intCast(globals.numsectors))) |i| {
        const cb = yax_bunchnum[i][YAX_CEILING];
        const fb = yax_bunchnum[i][YAX_FLOOR];

        if (cb >= 0) numyaxbunches = @max(numyaxbunches, cb + 1);
        if (fb >= 0) numyaxbunches = @max(numyaxbunches, fb + 1);
    }
}

/// Get the neighbor sector through a YAX portal
pub fn yax_getneighborsect(x: i32, y: i32, sectnum: i32, cf: i32) i32 {
    _ = x;
    _ = y;
    _ = sectnum;
    _ = cf;

    // This would find the sector in the connected bunch that contains (x, y)
    return -1;
}

/// Update gray-out state for editor (sectors at different levels)
pub fn yax_updategrays(posze: i32) void {
    _ = posze;

    // This is primarily for the editor to show which sectors
    // are at the current level vs above/below
}

// =============================================================================
// Query Functions
// =============================================================================

/// Check if a sector has YAX extensions
pub fn yax_hassector(sectnum: i16) bool {
    if (sectnum < 0 or sectnum >= globals.numsectors) return false;

    return yax_bunchnum[@intCast(sectnum)][YAX_CEILING] >= 0 or
        yax_bunchnum[@intCast(sectnum)][YAX_FLOOR] >= 0;
}

/// Check if a wall has YAX extensions
pub fn yax_haswall(wallnum: i16) bool {
    if (wallnum < 0 or wallnum >= globals.numwalls) return false;

    return yax_nextwall[@intCast(wallnum)][YAX_CEILING] >= 0 or
        yax_nextwall[@intCast(wallnum)][YAX_FLOOR] >= 0;
}

/// Get the number of sectors in a bunch
pub fn yax_getbunchsectors(bunchnum: i16, cf: i16) i32 {
    if (bunchnum < 0 or bunchnum >= numyaxbunches) return 0;
    if (cf < 0 or cf > 1) return 0;

    var count: i32 = 0;
    var sectnum = headsectbunch[@intCast(cf)][@intCast(bunchnum)];

    while (sectnum >= 0) {
        count += 1;
        sectnum = nextsectbunch[@intCast(cf)][@intCast(sectnum)];
    }

    return count;
}

/// Check if we're currently rendering YAX
pub fn yax_isrendering() bool {
    return yax_globallev != 0;
}

/// Get the current YAX level (-1 = above, 0 = normal, 1 = below)
pub fn yax_getlevel() i32 {
    return yax_globallev;
}

// =============================================================================
// Tests
// =============================================================================

test "yax initialization" {
    yax_init();

    try std.testing.expectEqual(@as(i32, 0), numyaxbunches);
    try std.testing.expectEqual(@as(i32, -1), yax_globallev);
    try std.testing.expectEqual(@as(i32, -1), yax_globalbunch);
}

test "bunch management" {
    yax_init();
    globals.numsectors = 10;

    // Initially no bunches
    try std.testing.expectEqual(@as(i16, -1), yax_getbunch(0, 0));
    try std.testing.expectEqual(@as(i16, -1), yax_getbunch(0, 1));

    // Set a bunch
    yax_setbunch(0, 0, 0);
    try std.testing.expectEqual(@as(i16, 0), yax_getbunch(0, 0));
    try std.testing.expectEqual(@as(i16, -1), yax_getbunch(0, 1));

    // Check both bunches at once
    var cb: i16 = undefined;
    var fb: i16 = undefined;
    yax_getbunches(0, &cb, &fb);
    try std.testing.expectEqual(@as(i16, 0), cb);
    try std.testing.expectEqual(@as(i16, -1), fb);
}

test "has sector/wall" {
    yax_init();
    globals.numsectors = 10;
    globals.numwalls = 20;

    try std.testing.expect(!yax_hassector(0));
    try std.testing.expect(!yax_haswall(0));

    yax_setbunch(0, 0, 0);
    try std.testing.expect(yax_hassector(0));

    yax_setnextwall(0, 0, 1);
    try std.testing.expect(yax_haswall(0));
}

test "get next wall" {
    yax_init();
    globals.numwalls = 20;

    try std.testing.expectEqual(@as(i16, -1), yax_getnextwall(0, 0));

    yax_setnextwall(0, 0, 5);
    try std.testing.expectEqual(@as(i16, 5), yax_getnextwall(0, 0));
    try std.testing.expectEqual(@as(i16, -1), yax_getnextwall(0, 1));
}
