//! Sprite Management and Rendering
//! Port from: NBlood/source/build/src/engine.cpp (sprite functions)
//!
//! This module handles sprite list management, temporary sprites for
//! rendering, and sprite-related utilities.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");

// =============================================================================
// Sprite List Management
// =============================================================================

/// Initialize all sprite linked lists
pub fn initspritelists() void {
    // Initialize status list heads
    for (&globals.headspritestat) |*h| {
        h.* = -1;
    }

    // Initialize sector list heads
    for (&globals.headspritesect) |*h| {
        h.* = -1;
    }

    // Initialize all sprites to free list (statnum = MAXSTATUS)
    for (0..constants.MAXSPRITES) |i| {
        globals.sprite[i].statnum = @intCast(constants.MAXSTATUS);
        globals.sprite[i].sectnum = -1;

        globals.prevspritestat[i] = @as(i16, @intCast(i)) - 1;
        globals.nextspritestat[i] = @as(i16, @intCast(i)) + 1;
        globals.prevspritesect[i] = -1;
        globals.nextspritesect[i] = -1;
    }

    // Set up the free list
    globals.prevspritestat[0] = -1;
    globals.nextspritestat[constants.MAXSPRITES - 1] = -1;
    globals.headspritestat[constants.MAXSTATUS] = 0;

    globals.Numsprites = 0;
    globals.spritesortcnt = 0;
}

/// Insert a sprite into a status list
pub fn insertspritestat(statnum: i16) i32 {
    // Get a sprite from the free list
    const newsprite = globals.headspritestat[constants.MAXSTATUS];
    if (newsprite < 0) {
        return -1; // No free sprites
    }

    // Remove from free list
    const next = globals.nextspritestat[@intCast(newsprite)];
    globals.headspritestat[constants.MAXSTATUS] = next;
    if (next >= 0) {
        globals.prevspritestat[@intCast(next)] = -1;
    }

    // Add to target status list
    const oldhead = globals.headspritestat[@intCast(statnum)];
    globals.headspritestat[@intCast(statnum)] = newsprite;
    globals.prevspritestat[@intCast(newsprite)] = -1;
    globals.nextspritestat[@intCast(newsprite)] = oldhead;
    if (oldhead >= 0) {
        globals.prevspritestat[@intCast(oldhead)] = newsprite;
    }

    globals.sprite[@intCast(newsprite)].statnum = statnum;
    globals.Numsprites += 1;

    return newsprite;
}

/// Insert a sprite into a sector list
pub fn insertspritesect(spritenum: i16, sectnum: i16) void {
    if (spritenum < 0 or sectnum < 0) return;

    const oldhead = globals.headspritesect[@intCast(sectnum)];
    globals.headspritesect[@intCast(sectnum)] = spritenum;
    globals.prevspritesect[@intCast(spritenum)] = -1;
    globals.nextspritesect[@intCast(spritenum)] = oldhead;
    if (oldhead >= 0) {
        globals.prevspritesect[@intCast(oldhead)] = spritenum;
    }

    globals.sprite[@intCast(spritenum)].sectnum = sectnum;
}

/// Insert a sprite into both status and sector lists
pub fn insertsprite(sectnum: i16, statnum: i16) i32 {
    const spritenum = insertspritestat(statnum);
    if (spritenum >= 0) {
        insertspritesect(@intCast(spritenum), sectnum);
    }
    return spritenum;
}

/// Delete a sprite from its status list
pub fn deletespritestat(spritenum: i16) void {
    if (spritenum < 0) return;

    const spr = &globals.sprite[@intCast(spritenum)];
    const statnum = spr.statnum;

    const prev = globals.prevspritestat[@intCast(spritenum)];
    const next = globals.nextspritestat[@intCast(spritenum)];

    if (prev >= 0) {
        globals.nextspritestat[@intCast(prev)] = next;
    } else {
        globals.headspritestat[@intCast(statnum)] = next;
    }

    if (next >= 0) {
        globals.prevspritestat[@intCast(next)] = prev;
    }

    // Add to free list
    const freehead = globals.headspritestat[constants.MAXSTATUS];
    globals.headspritestat[constants.MAXSTATUS] = spritenum;
    globals.prevspritestat[@intCast(spritenum)] = -1;
    globals.nextspritestat[@intCast(spritenum)] = freehead;
    if (freehead >= 0) {
        globals.prevspritestat[@intCast(freehead)] = spritenum;
    }

    spr.statnum = @intCast(constants.MAXSTATUS);
    globals.Numsprites -= 1;
}

/// Delete a sprite from its sector list
pub fn deletespritesect(spritenum: i16) void {
    if (spritenum < 0) return;

    const spr = &globals.sprite[@intCast(spritenum)];
    const sectnum = spr.sectnum;
    if (sectnum < 0) return;

    const prev = globals.prevspritesect[@intCast(spritenum)];
    const next = globals.nextspritesect[@intCast(spritenum)];

    if (prev >= 0) {
        globals.nextspritesect[@intCast(prev)] = next;
    } else {
        globals.headspritesect[@intCast(sectnum)] = next;
    }

    if (next >= 0) {
        globals.prevspritesect[@intCast(next)] = prev;
    }

    globals.prevspritesect[@intCast(spritenum)] = -1;
    globals.nextspritesect[@intCast(spritenum)] = -1;
    spr.sectnum = -1;
}

/// Delete a sprite completely
pub fn deletesprite(spritenum: i16) i32 {
    deletespritesect(spritenum);
    deletespritestat(spritenum);
    return 0;
}

/// Change a sprite's status number
pub fn changespritestat(spritenum: i16, newstatnum: i16) i32 {
    if (spritenum < 0) return -1;

    const spr = &globals.sprite[@intCast(spritenum)];
    const oldstatnum = spr.statnum;

    if (oldstatnum == newstatnum) return 0;

    // Remove from old status list
    const prev = globals.prevspritestat[@intCast(spritenum)];
    const next = globals.nextspritestat[@intCast(spritenum)];

    if (prev >= 0) {
        globals.nextspritestat[@intCast(prev)] = next;
    } else {
        globals.headspritestat[@intCast(oldstatnum)] = next;
    }

    if (next >= 0) {
        globals.prevspritestat[@intCast(next)] = prev;
    }

    // Add to new status list
    const newhead = globals.headspritestat[@intCast(newstatnum)];
    globals.headspritestat[@intCast(newstatnum)] = spritenum;
    globals.prevspritestat[@intCast(spritenum)] = -1;
    globals.nextspritestat[@intCast(spritenum)] = newhead;
    if (newhead >= 0) {
        globals.prevspritestat[@intCast(newhead)] = spritenum;
    }

    spr.statnum = newstatnum;

    return 0;
}

/// Change a sprite's sector
pub fn changespritesect(spritenum: i16, newsectnum: i16) i32 {
    if (spritenum < 0 or newsectnum < 0) return -1;

    const spr = &globals.sprite[@intCast(spritenum)];
    const oldsectnum = spr.sectnum;

    if (oldsectnum == newsectnum) return 0;

    // Remove from old sector
    if (oldsectnum >= 0) {
        const prev = globals.prevspritesect[@intCast(spritenum)];
        const next = globals.nextspritesect[@intCast(spritenum)];

        if (prev >= 0) {
            globals.nextspritesect[@intCast(prev)] = next;
        } else {
            globals.headspritesect[@intCast(oldsectnum)] = next;
        }

        if (next >= 0) {
            globals.prevspritesect[@intCast(next)] = prev;
        }
    }

    // Add to new sector
    const newhead = globals.headspritesect[@intCast(newsectnum)];
    globals.headspritesect[@intCast(newsectnum)] = spritenum;
    globals.prevspritesect[@intCast(spritenum)] = -1;
    globals.nextspritesect[@intCast(spritenum)] = newhead;
    if (newhead >= 0) {
        globals.prevspritesect[@intCast(newhead)] = spritenum;
    }

    spr.sectnum = newsectnum;

    return 0;
}

// =============================================================================
// Temporary Sprites (for rendering)
// =============================================================================

/// Add a temporary sprite for rendering
pub fn renderAddTsprite(z: i16, sectnum: i16) i32 {
    if (globals.spritesortcnt >= constants.MAXSPRITESONSCREEN) {
        return -1;
    }

    const idx = @as(usize, @intCast(globals.spritesortcnt));
    globals.tsprite[idx].z = z;
    globals.tsprite[idx].sectnum = sectnum;
    globals.tspriteptr[idx] = &globals.tsprite[idx];

    globals.spritesortcnt += 1;

    return @intCast(globals.spritesortcnt - 1);
}

/// Create a temporary sprite from an existing sprite
pub fn renderMakeTSpriteFromSprite(tspr: *types.TSpriteType, spritenum: u16) *types.TSpriteType {
    const spr = &globals.sprite[@intCast(spritenum)];

    tspr.x = spr.x;
    tspr.y = spr.y;
    tspr.z = spr.z;
    tspr.cstat = spr.cstat;
    tspr.picnum = spr.picnum;
    tspr.shade = spr.shade;
    tspr.pal = spr.pal;
    tspr.clipdist = spr.clipdist;
    tspr.blend = spr.blend;
    tspr.xrepeat = spr.xrepeat;
    tspr.yrepeat = spr.yrepeat;
    tspr.xoffset = spr.xoffset;
    tspr.yoffset = spr.yoffset;
    tspr.sectnum = spr.sectnum;
    tspr.statnum = spr.statnum;
    tspr.ang = spr.ang;
    tspr.owner = @intCast(spritenum);
    tspr.xvel = spr.xvel;
    tspr.yvel = spr.yvel;
    tspr.zvel = spr.zvel;
    tspr.lotag = spr.lotag;
    tspr.hitag = spr.hitag;
    tspr.extra = spr.extra;

    return tspr;
}

/// Add a temporary sprite from an existing sprite
pub fn renderAddTSpriteFromSprite(spritenum: u16) ?*types.TSpriteType {
    if (globals.spritesortcnt >= constants.MAXSPRITESONSCREEN) {
        return null;
    }

    const idx = @as(usize, @intCast(globals.spritesortcnt));
    const tspr = &globals.tsprite[idx];

    _ = renderMakeTSpriteFromSprite(tspr, spritenum);
    globals.tspriteptr[idx] = tspr;
    globals.spritesortcnt += 1;

    return tspr;
}

/// Clear all temporary sprites
pub fn clearTSprites() void {
    globals.spritesortcnt = 0;
}

// =============================================================================
// Sprite Utilities
// =============================================================================

/// Get the height of a sprite
pub fn spriteheightofsptr(spr: *const types.SpriteType, height: *i32, alsotileyofs: i32) i32 {
    _ = alsotileyofs;

    // This would normally look up the tile size
    // For now, use a default calculation based on yrepeat
    const yrepeat = @as(i32, spr.yrepeat);
    height.* = yrepeat * 4; // Simplified

    return 0;
}

/// Set sprite position
pub fn setsprite(spritenum: i16, pos: *const types.Vec3) i32 {
    if (spritenum < 0) return -1;

    const spr = &globals.sprite[@intCast(spritenum)];
    spr.x = pos.x;
    spr.y = pos.y;
    spr.z = pos.z;

    // Update sector if needed (simplified)
    // In the full implementation, this would call updatesector

    return 0;
}

/// Set sprite position with sector update
pub fn setspritez(spritenum: i16, pos: *const types.Vec3) i32 {
    return setsprite(spritenum, pos);
}

/// Get sprite alignment type
pub fn getSpriteAlignment(cstat: u16) enums.CstatSprite.ALIGNMENT_FACING {
    return @enumFromInt(cstat & enums.CstatSprite.ALIGNMENT_MASK);
}

/// Check if sprite is a wall sprite
pub fn isSpriteWall(spr: *const types.SpriteType) bool {
    return (spr.cstat & enums.CstatSprite.ALIGNMENT_MASK) == enums.CstatSprite.ALIGNMENT_WALL;
}

/// Check if sprite is a floor sprite
pub fn isSpriteFloor(spr: *const types.SpriteType) bool {
    return (spr.cstat & enums.CstatSprite.ALIGNMENT_MASK) == enums.CstatSprite.ALIGNMENT_FLOOR;
}

/// Check if sprite is a face sprite
pub fn isSpriteFace(spr: *const types.SpriteType) bool {
    return (spr.cstat & enums.CstatSprite.ALIGNMENT_MASK) == enums.CstatSprite.ALIGNMENT_FACING;
}

/// Check if sprite is visible
pub fn isSpriteVisible(spr: *const types.SpriteType) bool {
    return (spr.cstat & enums.CstatSprite.INVISIBLE) == 0;
}

/// Check if sprite is translucent
pub fn isSpriteTranslucent(spr: *const types.SpriteType) bool {
    return (spr.cstat & enums.CstatSprite.TRANSLUCENT) != 0;
}

// =============================================================================
// Sprite Slope (for sloped sprites)
// =============================================================================

/// Set sprite slope (heinum)
pub fn spriteSetSlope(spritenum: u16, heinum: i16) void {
    // Slope is stored in the sprite extension data
    // This is a simplified version
    _ = spritenum;
    _ = heinum;
}

/// Get sprite slope
pub fn spriteGetSlope(spritenum: u16) i16 {
    _ = spritenum;
    return 0;
}

// =============================================================================
// Tests
// =============================================================================

test "sprite list initialization" {
    initspritelists();

    // All status lists should be empty except free list
    for (0..constants.MAXSTATUS) |i| {
        try std.testing.expectEqual(@as(i16, -1), globals.headspritestat[i]);
    }

    // Free list should have sprite 0 at head
    try std.testing.expectEqual(@as(i16, 0), globals.headspritestat[constants.MAXSTATUS]);

    // Count should be 0
    try std.testing.expectEqual(@as(i32, 0), globals.Numsprites);
}

test "insert and delete sprite" {
    initspritelists();

    // Insert a sprite
    const spritenum = insertsprite(0, 0);
    try std.testing.expect(spritenum >= 0);
    try std.testing.expectEqual(@as(i32, 1), globals.Numsprites);

    // Delete the sprite
    _ = deletesprite(@intCast(spritenum));
    try std.testing.expectEqual(@as(i32, 0), globals.Numsprites);
}

test "temporary sprites" {
    initspritelists();
    clearTSprites();

    try std.testing.expectEqual(@as(i32, 0), globals.spritesortcnt);

    // Add a tsprite
    const idx = renderAddTsprite(100, 0);
    try std.testing.expect(idx >= 0);
    try std.testing.expectEqual(@as(i32, 1), globals.spritesortcnt);

    // Clear
    clearTSprites();
    try std.testing.expectEqual(@as(i32, 0), globals.spritesortcnt);
}
