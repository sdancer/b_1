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
const art = @import("../fs/art.zig");
const pm_globals = @import("globals.zig");

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

    // Filter mode - use LINEAR, not MIPMAP since we don't generate mipmaps
    var minFilter: i32 = gl.GL_NEAREST;
    var magFilter: i32 = gl.GL_NEAREST;

    if (filter > 0) {
        minFilter = gl.GL_LINEAR;  // Changed from GL_LINEAR_MIPMAP_LINEAR
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
                .r = globals.palette[idx],
                .g = globals.palette[idx + 1],
                .b = globals.palette[idx + 2],
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

/// Next power of 2 >= n
fn nextPow2(n: i16) i32 {
    if (n <= 0) return 1;
    var val: i32 = 1;
    while (val < n) : (val <<= 1) {}
    return val;
}

/// Load an ART tile into a texture
/// Port from: polymost.cpp gloadtile_art() lines 2123-2290
pub fn gloadtile_art(
    picnum: i32,
    pal: i32,
    shade: i32,
    dameth: i32,
    pth: *PthType,
    doalloc: i32,
) void {
    // Validate picnum
    if (picnum < 0 or picnum >= constants.MAXTILES) {
        createPlaceholderTexture(pth, dameth);
        return;
    }

    const idx: usize = @intCast(picnum);

    // Get tile dimensions
    const tsizx = art.tilesizx[idx];
    const tsizy = art.tilesizy[idx];

    if (tsizx <= 0 or tsizy <= 0) {
        createPlaceholderTexture(pth, dameth);
        return;
    }

    // Get tile pixel data
    const pixels = art.tiledata[idx] orelse {
        createPlaceholderTexture(pth, dameth);
        return;
    };

    // Calculate texture size (power of 2 for compatibility)
    const sizx: i32 = nextPow2(tsizx);
    const sizy: i32 = nextPow2(tsizy);
    const tsizx_i32: i32 = tsizx;
    const tsizy_i32: i32 = tsizy;

    // Allocate RGBA buffer
    const buf_size: usize = @intCast(sizx * sizy);
    var rgba_buf = std.heap.page_allocator.alloc(ColType, buf_size) catch {
        createPlaceholderTexture(pth, dameth);
        return;
    };
    defer std.heap.page_allocator.free(rgba_buf);

    // Clear buffer (for padding when tile < texture size)
    @memset(rgba_buf, ColType{ .r = 0, .g = 0, .b = 0, .a = 0 });

    // Get palette (base palette from engine globals)
    const palette_data = &globals.palette;

    // Debug: check if palette has colors (only once)
    if (debug_tex_loads == 0) {
        std.debug.print("Texture palette check: pal[0]={},{},{} pal[48]={},{},{} pal[144]={},{},{}\n", .{
            palette_data[0], palette_data[1], palette_data[2],
            palette_data[48 * 3], palette_data[48 * 3 + 1], palette_data[48 * 3 + 2],
            palette_data[144 * 3], palette_data[144 * 3 + 1], palette_data[144 * 3 + 2],
        });
    }

    // Get palookup (shade table) if available
    const pal_idx: usize = if (pal >= 0 and pal < constants.MAXPALOOKUPS) @intCast(pal) else 0;
    const palookup_ptr = globals.palookup[pal_idx];

    // Shade clamping
    const numshades_i32: i32 = globals.numshades;
    const actual_shade: i32 = if (numshades_i32 > 0)
        std.math.clamp(shade, 0, numshades_i32 - 1)
    else
        0;

    // Debug: trace first pixel of first texture
    var debug_first_pixel = (debug_tex_loads == 0);

    // Convert tile pixels to RGBA
    // BUILD tiles are stored column-major (x is outer loop)
    for (0..@as(usize, @intCast(tsizx_i32))) |tx| {
        for (0..@as(usize, @intCast(tsizy_i32))) |ty| {
            // BUILD stores columns: pixel[x][y] = data[x * sizy + y]
            const src_idx = tx * @as(usize, @intCast(tsizy_i32)) + ty;
            // OpenGL expects row-major
            const dst_idx = ty * @as(usize, @intCast(sizx)) + tx;

            if (src_idx >= @as(usize, @intCast(tsizx_i32 * tsizy_i32))) continue;
            if (dst_idx >= buf_size) continue;

            const color_idx = pixels[src_idx];

            if (debug_first_pixel) {
                std.debug.print("First pixel: color_idx={}", .{color_idx});
                debug_first_pixel = false;
            }

            // Index 255 is transparent in BUILD engine
            if (color_idx == 255) {
                rgba_buf[dst_idx] = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
                continue;
            }

            // Apply shade through palookup if available
            var final_idx: u8 = color_idx;
            if (palookup_ptr) |lut| {
                const shade_offset: usize = @intCast(actual_shade * 256);
                final_idx = lut[shade_offset + color_idx];
            }

            // Look up in base palette
            // Note: Blood's palette is already 8-bit (unlike Duke3D which uses 6-bit)
            const pal_offset = @as(usize, final_idx) * 3;
            if (pal_offset + 2 < palette_data.len) {
                const r = palette_data[pal_offset + 0];
                const g = palette_data[pal_offset + 1];
                const b = palette_data[pal_offset + 2];

                // Debug first few non-transparent pixels
                if (debug_tex_loads == 0 and tx < 3 and ty < 3 and color_idx != 255) {
                    std.debug.print(" -> final_idx={} -> RGB={},{},{}\n", .{ final_idx, r, g, b });
                }

                rgba_buf[dst_idx] = .{ .r = r, .g = g, .b = b, .a = 255 };
            } else {
                rgba_buf[dst_idx] = .{ .r = 255, .g = 0, .b = 255, .a = 255 }; // Magenta for debug
            }
        }
    }

    // Debug: verify RGBA buffer has colors for specific tiles
    if (picnum == 346 or picnum == 253 or debug_tex_loads == 0) {
        var has_color = false;
        var sample_r: u8 = 0;
        var sample_g: u8 = 0;
        var sample_b: u8 = 0;
        for (rgba_buf[0..@min(100, rgba_buf.len)]) |col| {
            if (col.a > 0) { // Non-transparent pixel
                sample_r = col.r;
                sample_g = col.g;
                sample_b = col.b;
                if (col.r != col.g or col.g != col.b) {
                    has_color = true;
                    break;
                }
            }
        }
        std.debug.print("Tile {} RGBA: R={} G={} B={} hasColor={}\n", .{ picnum, sample_r, sample_g, sample_b, has_color });
    }

    // Create or update OpenGL texture
    if (pth.glpic == 0 or doalloc != 0) {
        if (pth.glpic == 0) {
            gl.glGenTextures(1, @ptrCast(&pth.glpic));
        }
        gl.glBindTexture(gl.GL_TEXTURE_2D, pth.glpic);
        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            gl.GL_RGBA,
            sizx,
            sizy,
            0,
            gl.GL_RGBA,
            gl.GL_UNSIGNED_BYTE,
            @ptrCast(rgba_buf.ptr),
        );

        // Check for GL errors
        const err = gl.glGetError();
        if (err != 0 and debug_tex_loads < 3) {
            std.debug.print("GL ERROR after glTexImage2D: 0x{x}\n", .{err});
        }
    } else {
        gl.glBindTexture(gl.GL_TEXTURE_2D, pth.glpic);
        gl.glTexSubImage2D(
            gl.GL_TEXTURE_2D,
            0,
            0,
            0,
            sizx,
            sizy,
            gl.GL_RGBA,
            gl.GL_UNSIGNED_BYTE,
            @ptrCast(rgba_buf.ptr),
        );
    }

    setupTexture(dameth, 1);

    // Store texture info
    pth.siz = .{ .x = sizx, .y = sizy };
    // Scale is ratio of actual tile size to texture size (for correct UV mapping)
    pth.scale = .{
        .x = @as(f32, @floatFromInt(tsizx_i32)) / @as(f32, @floatFromInt(sizx)),
        .y = @as(f32, @floatFromInt(tsizy_i32)) / @as(f32, @floatFromInt(sizy)),
    };
    pth.picnum = @intCast(picnum);
    pth.palnum = @intCast(if (pal >= 0 and pal < 256) pal else 0);
    pth.shade = @intCast(std.math.clamp(shade, -128, 127));

    // Set flags based on whether texture has alpha
    pth.flags &= ~polymost_types.PthFlags.HASALPHA;
    // Check if any pixel is transparent
    for (rgba_buf) |col| {
        if (col.a < 255) {
            pth.flags |= polymost_types.PthFlags.HASALPHA;
            break;
        }
    }
}

/// Create a placeholder texture for missing/invalid tiles
fn createPlaceholderTexture(pth: *PthType, dameth: i32) void {
    if (pth.glpic == 0) {
        gl.glGenTextures(1, @ptrCast(&pth.glpic));
    }

    gl.glBindTexture(gl.GL_TEXTURE_2D, pth.glpic);

    // Create a 16x16 checkerboard placeholder
    var placeholder: [16 * 16]ColType = undefined;
    for (0..16) |y| {
        for (0..16) |x| {
            const isWhite = ((x / 4) + (y / 4)) % 2 == 0;
            // Magenta/dark magenta checkerboard for visibility
            if (isWhite) {
                placeholder[y * 16 + x] = .{ .r = 255, .g = 0, .b = 255, .a = 255 };
            } else {
                placeholder[y * 16 + x] = .{ .r = 128, .g = 0, .b = 128, .a = 255 };
            }
        }
    }

    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RGBA,
        16,
        16,
        0,
        gl.GL_RGBA,
        gl.GL_UNSIGNED_BYTE,
        @ptrCast(&placeholder),
    );

    setupTexture(dameth, 0);

    pth.siz = .{ .x = 16, .y = 16 };
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
// Texture Acquisition (gltex)
// =============================================================================

/// Texture cache storage (preallocated pool)
var pth_pool: [4096]PthType = undefined;
var pth_pool_used: usize = 0;

/// Debug: count texture loads
var debug_tex_loads: usize = 0;
var debug_tex_cache_hits: usize = 0;
var debug_reported: bool = false;

/// Get or load a texture for rendering
/// This is the main entry point for acquiring a texture before drawing.
pub fn gltex(picnum: i32, palnum: i32, dameth: i32) ?*PthType {
    // Check bounds
    if (picnum < 0 or picnum >= constants.MAXTILES) return null;

    // Check if already cached
    if (findTexture(@intCast(picnum), @intCast(if (palnum >= 0 and palnum < 256) palnum else 0), dameth)) |pth| {
        // Check if texture needs reload (marked invalid)
        if (pth.glpic != 0) {
            debug_tex_cache_hits += 1;
            return pth;
        }
    }

    // Allocate new cache entry
    if (pth_pool_used >= pth_pool.len) {
        // Cache full, can't allocate
        std.debug.print("WARNING: Texture pool exhausted!\n", .{});
        return null;
    }

    const pth = &pth_pool[pth_pool_used];
    pth_pool_used += 1;

    // Initialize
    pth.* = PthType{};
    pth.picnum = @intCast(picnum);
    pth.palnum = @intCast(if (palnum >= 0 and palnum < 256) palnum else 0);

    // Set clamped flag based on dameth
    if ((dameth & Dameth.CLAMPED) != 0) {
        pth.flags |= polymost_types.PthFlags.CLAMPED;
    }

    // Load the tile
    const shade: i32 = pm_globals.globalshade;
    gloadtile_art(picnum, palnum, shade, dameth, pth, 1);

    debug_tex_loads += 1;

    // Debug: report first few texture loads
    if (debug_tex_loads <= 5) {
        const idx: usize = @intCast(picnum);
        std.debug.print("  Loaded tex #{}: picnum={} glpic={} size={}x{} tiledata={}\n", .{
            debug_tex_loads,
            picnum,
            pth.glpic,
            pth.siz.x,
            pth.siz.y,
            art.tiledata[idx] != null,
        });
    }

    // Add to cache
    addTexture(pth);

    return pth;
}

/// Print texture stats (call once per second or on demand)
pub fn debugPrintStats() void {
    if (!debug_reported and debug_tex_loads > 0) {
        std.debug.print("Texture stats: {} loaded, {} cache hits, pool={}/{}\n", .{
            debug_tex_loads,
            debug_tex_cache_hits,
            pth_pool_used,
            pth_pool.len,
        });
        debug_reported = true;
    }
}

/// Reset the texture pool (for testing or reload)
pub fn resetTexturePool() void {
    // Delete all GL textures
    for (pth_pool[0..pth_pool_used]) |*pth| {
        if (pth.glpic != 0) {
            gl.glDeleteTextures(1, &pth.glpic);
            pth.glpic = 0;
        }
    }
    pth_pool_used = 0;

    // Clear cache hash table
    for (&texcache) |*bucket| {
        bucket.* = null;
    }
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
