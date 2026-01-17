//! Polymost Texture Management
//! Port from: NBlood/source/build/src/polymost.cpp (texture functions)
//!
//! Handles texture loading, caching, palette management, and texture
//! coordinate calculations for the polymost renderer.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const enums = @import("../enums.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");
const polymost_types = @import("types.zig");

const PthType = polymost_types.PthType;
const ColType = polymost_types.ColType;
const Dameth = polymost_types.Dameth;

// =============================================================================
// Texture Cache
// =============================================================================

/// Number of hash buckets for texture cache
const GLTEXCACHE_BUCKETS = 4096;

/// Texture cache hash table
var texcache: [GLTEXCACHE_BUCKETS]?*PthType = .{null} ** GLTEXCACHE_BUCKETS;

/// Currently bound texture
var currentTextureId: u32 = 0;

/// Base palette texture
var paletteTextureId: u32 = 0;

/// Palette swap textures
var palswapTextureIds: [constants.MAXPALOOKUPS]u32 = .{0} ** constants.MAXPALOOKUPS;

// =============================================================================
// Texture Cache Functions
// =============================================================================

/// Calculate hash for texture cache lookup
fn calcTexHash(picnum: i16, palnum: u8, dameth: i32) u32 {
    var hash: u32 = @as(u32, @intCast(@as(u16, @bitCast(picnum))));
    hash = hash *% 17 +% @as(u32, palnum);
    hash = hash *% 17 +% @as(u32, @intCast(@as(u16, @bitCast(@as(i16, @truncate(dameth))))));
    return hash % GLTEXCACHE_BUCKETS;
}

/// Find a texture in the cache
pub fn findTexture(picnum: i16, palnum: u8, dameth: i32) ?*PthType {
    const hash = calcTexHash(picnum, palnum, dameth);
    var pth = texcache[hash];

    while (pth) |p| {
        if (p.picnum == picnum and p.palnum == palnum) {
            // Check dameth compatibility
            const hasClamped = (p.flags & polymost_types.PthFlags.CLAMPED) != 0;
            const wantClamped = (dameth & Dameth.CLAMPED) != 0;
            if (hasClamped == wantClamped) {
                return p;
            }
        }
        pth = p.next;
    }

    return null;
}

/// Add a texture to the cache
pub fn addTexture(pth: *PthType) void {
    const hash = calcTexHash(pth.picnum, pth.palnum, if ((pth.flags & polymost_types.PthFlags.CLAMPED) != 0) Dameth.CLAMPED else 0);

    pth.next = texcache[hash];
    texcache[hash] = pth;
}

/// Invalidate a specific texture
pub fn gltexinvalidate(dapicnum: i32, dapalnum: i32, dameth: i32) void {
    const hash = calcTexHash(@intCast(dapicnum), @intCast(dapalnum), dameth);
    var pth = texcache[hash];

    while (pth) |p| {
        if (p.picnum == @as(i16, @intCast(dapicnum)) and p.palnum == @as(u8, @intCast(dapalnum))) {
            // Mark for reload
            if (p.glpic != 0) {
                gl.glDeleteTextures(1, &p.glpic);
                p.glpic = 0;
            }
        }
        pth = p.next;
    }
}

/// Invalidate all textures of a certain type
pub fn gltexinvalidatetype(textureType: i32) void {
    _ = textureType;

    // Clear entire cache
    for (&texcache) |*bucket| {
        var pth = bucket.*;
        while (pth) |p| {
            const next = p.next;
            if (p.glpic != 0) {
                gl.glDeleteTextures(1, &p.glpic);
                p.glpic = 0;
            }
            pth = next;
        }
        bucket.* = null;
    }
}

/// Invalidate all textures
pub fn gltexinvalidateall() void {
    gltexinvalidatetype(0);
}

// =============================================================================
// Texture Setup
// =============================================================================

/// Set up texture parameters
pub fn setupTexture(dameth: i32, filter: i32) void {
    // Wrapping mode
    const wrapS: i32 = if ((dameth & Dameth.CLAMPED) != 0) gl.GL_CLAMP_TO_EDGE else gl.GL_REPEAT;
    const wrapT: i32 = if ((dameth & Dameth.CLAMPED) != 0) gl.GL_CLAMP_TO_EDGE else gl.GL_REPEAT;

    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, wrapS);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, wrapT);

    // Filter mode
    var minFilter: i32 = gl.GL_NEAREST;
    var magFilter: i32 = gl.GL_NEAREST;

    if (filter > 0) {
        minFilter = gl.GL_LINEAR_MIPMAP_LINEAR;
        magFilter = gl.GL_LINEAR;
    }

    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, minFilter);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, magFilter);
}

/// Upload a texture to OpenGL
pub fn uploadTexture(
    doalloc: i32,
    siz: types.Vec2,
    texfmt: i32,
    pic: [*]const ColType,
    tsiz: types.Vec2,
    dameth: i32,
) void {
    _ = tsiz;

    if (doalloc != 0) {
        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            texfmt,
            siz.x,
            siz.y,
            0,
            gl.GL_RGBA,
            gl.GL_UNSIGNED_BYTE,
            @ptrCast(pic),
        );
    } else {
        gl.glTexSubImage2D(
            gl.GL_TEXTURE_2D,
            0,
            0,
            0,
            siz.x,
            siz.y,
            gl.GL_RGBA,
            gl.GL_UNSIGNED_BYTE,
            @ptrCast(pic),
        );
    }

    setupTexture(dameth, 1);
}

/// Upload an indexed (paletted) texture
pub fn uploadTextureIndexed(
    doalloc: i32,
    offset: types.Vec2,
    siz: types.Vec2,
    tile: [*]const u8,
) void {
    _ = offset;
    _ = doalloc;

    // For indexed textures, we use a single-channel format
    // and look up in the palette during rendering
    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RED,
        siz.x,
        siz.y,
        0,
        gl.GL_RED,
        gl.GL_UNSIGNED_BYTE,
        @ptrCast(tile),
    );
}

// =============================================================================
// Palette Management
// =============================================================================

/// Upload the base palette texture
pub fn uploadBasePalette(basepalnum: i32) void {
    _ = basepalnum;

    if (paletteTextureId == 0) {
        gl.glGenTextures(1, &paletteTextureId);
    }

    gl.glBindTexture(gl.GL_TEXTURE_2D, paletteTextureId);

    // Palette is 256 colors, stored as a 256x1 texture
    var paletteData: [256]ColType = undefined;

    for (0..256) |i| {
        const idx = i * 3;
        if (idx + 2 < globals.palette.len) {
            paletteData[i] = .{
                .r = globals.palette[idx] << 2, // BUILD palettes are 6-bit
                .g = globals.palette[idx + 1] << 2,
                .b = globals.palette[idx + 2] << 2,
                .a = if (i == 255) 0 else 255, // Index 255 is typically transparent
            };
        } else {
            paletteData[i] = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
        }
    }

    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RGBA,
        256,
        1,
        0,
        gl.GL_RGBA,
        gl.GL_UNSIGNED_BYTE,
        @ptrCast(&paletteData),
    );

    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
}

/// Upload a palette swap (shade table) texture
pub fn uploadPalSwap(palookupnum: i32) void {
    if (palookupnum < 0 or palookupnum >= constants.MAXPALOOKUPS) return;

    const idx: usize = @intCast(palookupnum);

    if (palswapTextureIds[idx] == 0) {
        gl.glGenTextures(1, &palswapTextureIds[idx]);
    }

    gl.glBindTexture(gl.GL_TEXTURE_2D, palswapTextureIds[idx]);

    // Palswap is a numshades x 256 lookup table
    const numshades: usize = @intCast(@max(1, globals.numshades));
    const dataSize = numshades * 256;
    var palswapData = std.ArrayList(u8).init(std.heap.page_allocator);
    defer palswapData.deinit();
    palswapData.resize(dataSize) catch return;

    // Fill with identity mapping (simplified - real implementation would use palookup)
    for (0..numshades) |shade| {
        for (0..256) |color| {
            palswapData.items[shade * 256 + color] = @intCast(color);
        }
    }

    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RED,
        256,
        @intCast(numshades),
        0,
        gl.GL_RED,
        gl.GL_UNSIGNED_BYTE,
        @ptrCast(palswapData.items.ptr),
    );

    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
}

// =============================================================================
// Tile Loading
// =============================================================================

/// Load an ART tile into a texture
pub fn gloadtile_art(
    picnum: i32,
    pal: i32,
    shade: i32,
    dameth: i32,
    pth: *PthType,
    doalloc: i32,
) void {
    _ = shade;
    _ = pal;
    _ = picnum;
    _ = doalloc;

    // This would load tile data from the ART files
    // For now, create a placeholder texture

    if (pth.glpic == 0) {
        gl.glGenTextures(1, &pth.glpic);
    }

    gl.glBindTexture(gl.GL_TEXTURE_2D, pth.glpic);

    // Create a placeholder 64x64 checkerboard texture
    var placeholder: [64 * 64]ColType = undefined;
    for (0..64) |y| {
        for (0..64) |x| {
            const isWhite = ((x / 8) + (y / 8)) % 2 == 0;
            const gray: u8 = if (isWhite) 200 else 100;
            placeholder[y * 64 + x] = .{ .r = gray, .g = gray, .b = gray, .a = 255 };
        }
    }

    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RGBA,
        64,
        64,
        0,
        gl.GL_RGBA,
        gl.GL_UNSIGNED_BYTE,
        @ptrCast(&placeholder),
    );

    setupTexture(dameth, 1);

    pth.siz = .{ .x = 64, .y = 64 };
    pth.scale = .{ .x = 1.0, .y = 1.0 };
}

/// Load a high-resolution replacement tile
pub fn gloadtile_hi(
    picnum: i32,
    pal: i32,
    dameth: i32,
    hicr: ?*anyopaque,
    pth: *PthType,
    doalloc: i32,
) i32 {
    _ = doalloc;
    _ = hicr;
    _ = dameth;
    _ = pal;
    _ = picnum;
    _ = pth;

    // This would load replacement textures (PNG, etc.)
    // For now, return error (no hires replacement found)
    return -1;
}

// =============================================================================
// Texture Binding
// =============================================================================

/// Bind a texture for rendering
pub fn bindTexture(pth: *PthType) void {
    if (pth.glpic != currentTextureId) {
        currentTextureId = pth.glpic;
        gl.glBindTexture(gl.GL_TEXTURE_2D, pth.glpic);
    }
}

/// Bind the palette texture
pub fn bindPalette() void {
    gl_state.activeTexture(gl.GL_TEXTURE1);
    gl.glBindTexture(gl.GL_TEXTURE_2D, paletteTextureId);
    gl_state.activeTexture(gl.GL_TEXTURE0);
}

/// Bind a palette swap texture
pub fn bindPalSwap(palookupnum: i32) void {
    if (palookupnum < 0 or palookupnum >= constants.MAXPALOOKUPS) return;

    gl_state.activeTexture(gl.GL_TEXTURE2);
    gl.glBindTexture(gl.GL_TEXTURE_2D, palswapTextureIds[@intCast(palookupnum)]);
    gl_state.activeTexture(gl.GL_TEXTURE0);
}

// =============================================================================
// Precaching
// =============================================================================

/// Precache tiles for faster rendering
pub fn polymost_precache(dession: i32, dapal: i32, dameth: i32) void {
    _ = dameth;
    _ = dapal;
    _ = dession;

    // This would pre-load textures into the cache
    // Simplified for now
}

// =============================================================================
// Texture Coordinate Helpers
// =============================================================================

/// Calculate Y panning for a texture
pub fn calc_ypanning(y: f32, ryp: f32, ftl: f32, pic: *const PthType, method: i32) f32 {
    _ = method;

    const yscale = pic.scale.y;
    if (yscale <= 0.0) return 0.0;

    return (y - ryp * ftl) / yscale;
}

/// Calculate scroll step for animated textures
pub fn calc_yscrollstep() void {
    // Animation scroll calculation would go here
}

// =============================================================================
// Cleanup
// =============================================================================

/// Free all texture resources
pub fn cleanup() void {
    gltexinvalidateall();

    if (paletteTextureId != 0) {
        gl.glDeleteTextures(1, &paletteTextureId);
        paletteTextureId = 0;
    }

    for (&palswapTextureIds) |*id| {
        if (id.* != 0) {
            gl.glDeleteTextures(1, id);
            id.* = 0;
        }
    }
}

// =============================================================================
// Tests
// =============================================================================

test "texture hash calculation" {
    const hash1 = calcTexHash(0, 0, 0);
    const hash2 = calcTexHash(100, 0, 0);
    const hash3 = calcTexHash(0, 1, 0);

    // Different inputs should generally produce different hashes
    try std.testing.expect(hash1 != hash2);
    try std.testing.expect(hash1 != hash3);
    try std.testing.expect(hash2 != hash3);

    // Same inputs should produce same hash
    try std.testing.expectEqual(hash1, calcTexHash(0, 0, 0));
}

test "find texture in empty cache" {
    const pth = findTexture(0, 0, 0);
    try std.testing.expect(pth == null);
}

test "Dameth flags" {
    try std.testing.expect(Dameth.hasMask(Dameth.MASK));
    try std.testing.expect(!Dameth.hasMask(Dameth.NOMASK));
    try std.testing.expect(Dameth.hasTranslucency(Dameth.TRANS1));
}
