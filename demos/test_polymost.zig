//! Polymost Texture Test Demo
//!
//! A simple SDL2+OpenGL application that loads a Blood map and renders it
//! with textures using the polymost renderer.
//!
//! Usage:
//!   ./test_polymost <data_folder> <mapname>
//!   ./test_polymost --map <path/to/map.map>
//!
//! Examples:
//!   ./test_polymost web/data E1M1
//!   ./test_polymost --map maps/test.map
//!
//! Controls:
//!   W/S - Move forward/backward
//!   A/D - Strafe left/right
//!   Left/Right arrows - Turn
//!   Up/Down arrows - Look up/down
//!   T - Toggle textures on/off
//!   Escape - Quit

const std = @import("std");
const build_engine = @import("build_engine");

const types = build_engine.types;
const constants = build_engine.constants;
const globals = build_engine.globals;
const fs = build_engine.fs;
const polymost = build_engine.polymost;
const platform = build_engine.platform;
const engine = build_engine.engine;
const art = build_engine.fs.art;

// =============================================================================
// SDL2 C Bindings
// =============================================================================

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

// =============================================================================
// Screenshot Function
// =============================================================================

fn saveScreenshot(allocator: std.mem.Allocator, width: u32, height: u32) !void {
    const gl = build_engine.gl.bindings;

    // Allocate buffer for pixel data (RGB)
    const size = width * height * 3;
    const pixels = try allocator.alloc(u8, size);
    defer allocator.free(pixels);

    // Read pixels from OpenGL framebuffer
    gl.glReadPixels(0, 0, @intCast(width), @intCast(height), gl.GL_RGB, gl.GL_UNSIGNED_BYTE, pixels.ptr);

    // Write PPM file (simple format)
    const file = try std.fs.cwd().createFile("screenshot.ppm", .{});
    defer file.close();

    // PPM header
    var header_buf: [64]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "P6\n{} {}\n255\n", .{ width, height }) catch return error.BufferTooSmall;
    try file.writeAll(header);

    // PPM stores top-to-bottom, but OpenGL reads bottom-to-top, so flip
    var y: u32 = height;
    while (y > 0) {
        y -= 1;
        const row_start = y * width * 3;
        try file.writeAll(pixels[row_start .. row_start + width * 3]);
    }

    std.debug.print("Screenshot saved to screenshot.ppm\n", .{});
}

// =============================================================================
// Main Application
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <data_folder> <mapname>\n", .{args[0]});
        std.debug.print("       {s} --map <mapfile.map>\n", .{args[0]});
        return;
    }

    // Initialize BUILD engine
    build_engine.init();

    // Load data based on arguments
    var map_loaded = false;

    if (!std.mem.eql(u8, args[1], "--map")) {
        // First arg is data folder, second is map name
        const data_folder = args[1];
        const map_name = args[2];

        // Build path to blood.rff
        var rff_path_buf: [512]u8 = undefined;
        const rff_path = std.fmt.bufPrint(&rff_path_buf, "{s}/blood.rff", .{data_folder}) catch {
            std.debug.print("Path too long\n", .{});
            return;
        };

        std.debug.print("Loading RFF: {s}\n", .{rff_path});

        // Load RFF archive
        const rff_result = fs.rff.loadRFFFromFile(allocator, rff_path) catch |err| {
            std.debug.print("Failed to load RFF: {}\n", .{err});
            return;
        };
        var rff = rff_result.archive;
        defer {
            rff.deinit();
            allocator.free(rff_result.data);
        }

        std.debug.print("RFF loaded: {} entries\n", .{rff.entries.len});

        // Load palette (name="BLOOD", type="PAL")
        if (rff.find("BLOOD", "PAL")) |pal_entry| {
            std.debug.print("Found BLOOD.PAL, size={}\n", .{pal_entry.size});
            if (rff.getData(allocator, pal_entry)) |pal_data| {
                defer allocator.free(pal_data);
                if (pal_data.len >= 768) {
                    @memcpy(&globals.palette, pal_data[0..768]);
                    globals.numshades = 64; // Blood uses 64 shade levels
                    std.debug.print("Palette loaded. Sample colors:\n", .{});
                    // Print several palette entries to check for colors
                    const indices = [_]usize{ 0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240 };
                    for (indices) |i| {
                        const r = globals.palette[i * 3 + 0];
                        const g = globals.palette[i * 3 + 1];
                        const b = globals.palette[i * 3 + 2];
                        std.debug.print("  [{d:3}]: r={d:2} g={d:2} b={d:2}\n", .{ i, r, g, b });
                    }
                }
            } else |_| {
                std.debug.print("Failed to extract palette\n", .{});
            }
        } else {
            std.debug.print("BLOOD.PAL not found in RFF!\n", .{});
        }

        // Load palookup/shade table (name="NORMAL", type="PLU")
        if (rff.find("NORMAL", "PLU")) |plu_entry| {
            std.debug.print("Found NORMAL.PLU, size={}\n", .{plu_entry.size});
            if (rff.getData(allocator, plu_entry)) |plu_data| {
                // Store the palookup - it persists for the lifetime of the app
                // PLU is numshades (64) * 256 colors = 16384 bytes
                if (plu_data.len >= 16384) {
                    globals.palookup[0] = plu_data.ptr;
                    std.debug.print("Palookup loaded\n", .{});
                }
            } else |_| {
                std.debug.print("Failed to extract palookup\n", .{});
            }
        } else {
            std.debug.print("NORMAL.PLU not found in RFF!\n", .{});
        }

        // Load ART files from disk (they're separate files, not in RFF)
        var art_count: u32 = 0;
        for (0..20) |file_idx| {
            // Try both lowercase (tiles000.art) and uppercase (TILES000.ART)
            var name_buf: [256]u8 = undefined;

            // Try lowercase first
            var art_path = std.fmt.bufPrint(&name_buf, "{s}/tiles{d:0>3}.art", .{ data_folder, file_idx }) catch continue;
            var art_file_result = fs.art.loadArtFromFile(allocator, art_path);

            // If lowercase fails, try uppercase
            if (art_file_result == error.FileNotFound) {
                art_path = std.fmt.bufPrint(&name_buf, "{s}/TILES{d:0>3}.ART", .{ data_folder, file_idx }) catch continue;
                art_file_result = fs.art.loadArtFromFile(allocator, art_path);
            }

            if (art_file_result) |art_file_data| {
                var art_file = art_file_data;
                const storage = allocator.alloc(u8, fs.art.calculateStorageNeeded(&art_file)) catch continue;
                fs.art.loadTilesToGlobals(&art_file, storage);
                std.debug.print("  Loaded {s}: tiles {}-{}\n", .{ art_path, art_file.tilestart, art_file.tileend });
                art_count += 1;
                art_file.deinit();
            } else |_| {
                // File not found or parse error - skip silently
            }
        }
        std.debug.print("Loaded {} ART files\n", .{art_count});

        // Debug: print some tile sizes
        std.debug.print("Sample tiles loaded:\n", .{});
        for (0..20) |i| {
            const idx = i * 100;
            if (idx < constants.MAXTILES) {
                const sx = art.tilesizx[idx];
                const sy = art.tilesizy[idx];
                const has_data = art.tiledata[idx] != null;
                if (sx > 0 and sy > 0) {
                    std.debug.print("  Tile {}: {}x{} data={}\n", .{ idx, sx, sy, has_data });
                }
            }
        }

        // Try to load map (type="MAP")
        if (rff.find(map_name, "MAP")) |map_entry| {
            if (rff.getData(allocator, map_entry)) |map_data| {
                defer allocator.free(map_data);

                var map_result = fs.map.loadBloodMap(allocator, map_data) catch |err| {
                    std.debug.print("Failed to parse map: {}\n", .{err});
                    return;
                };
                defer map_result.deinit();

                // Map data is loaded directly into globals by loadBloodMap
                // Set sprite count (numsectors and numwalls are set by loader)
                globals.Numsprites = map_result.numsprites;

                // Set player start position
                globals.globalposx = map_result.startx;
                globals.globalposy = map_result.starty;
                globals.globalposz = map_result.startz;
                globals.globalang = @intCast(map_result.startang);
                globals.globalcursectnum = @intCast(map_result.startsect);

                map_loaded = true;
                std.debug.print("Map loaded: {s}\n", .{map_name});
                std.debug.print("  Sectors: {}, Walls: {}, Sprites: {}\n", .{
                    map_result.numsectors,
                    map_result.numwalls,
                    map_result.numsprites,
                });

                // Debug: show what tiles the map uses
                std.debug.print("Sample sector floor tiles:\n", .{});
                for (0..@min(5, @as(usize, @intCast(globals.numsectors)))) |i| {
                    const sec = &globals.sector[i];
                    const fpic = sec.floorpicnum;
                    const cpic = sec.ceilingpicnum;
                    const fhas = if (fpic >= 0 and fpic < constants.MAXTILES) art.tiledata[@intCast(fpic)] != null else false;
                    const chas = if (cpic >= 0 and cpic < constants.MAXTILES) art.tiledata[@intCast(cpic)] != null else false;
                    std.debug.print("  Sector {}: floor={} (loaded={}), ceil={} (loaded={})\n", .{ i, fpic, fhas, cpic, chas });
                }

                std.debug.print("Sample wall tiles:\n", .{});
                for (0..@min(5, @as(usize, @intCast(globals.numwalls)))) |i| {
                    const wal = &globals.wall[i];
                    const pic = wal.picnum;
                    const has = if (pic >= 0 and pic < constants.MAXTILES) art.tiledata[@intCast(pic)] != null else false;
                    std.debug.print("  Wall {}: picnum={} (loaded={})\n", .{ i, pic, has });
                }
            } else |err| {
                std.debug.print("Failed to extract map: {}\n", .{err});
            }
        } else {
            std.debug.print("Map not found in RFF: {s}\n", .{map_name});
        }
    } else if (std.mem.eql(u8, args[1], "--map")) {
        const map_path = args[2];
        std.debug.print("Loading map: {s}\n", .{map_path});

        var map_result = fs.map.loadMapFromFile(allocator, map_path) catch |err| {
            std.debug.print("Failed to load map: {}\n", .{err});
            return;
        };
        defer map_result.deinit();

        // Map data is loaded directly into globals by loadMapFromFile
        // Set sprite count (numsectors and numwalls are set by loader)
        globals.Numsprites = map_result.numsprites;

        // Set player start position
        globals.globalposx = map_result.startx;
        globals.globalposy = map_result.starty;
        globals.globalposz = map_result.startz;
        globals.globalang = @intCast(map_result.startang);
        globals.globalcursectnum = @intCast(map_result.startsect);

        map_loaded = true;
    }

    if (!map_loaded) {
        std.debug.print("No map loaded!\n", .{});
        return;
    }

    // Initialize SDL
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        std.debug.print("SDL_Init failed\n", .{});
        return;
    }
    defer c.SDL_Quit();

    // Set OpenGL attributes
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);

    // Create window
    const window = c.SDL_CreateWindow(
        "Polymost Texture Test",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        1280,
        720,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN,
    );
    if (window == null) {
        std.debug.print("SDL_CreateWindow failed\n", .{});
        return;
    }
    defer c.SDL_DestroyWindow(window);

    // Create GL context
    const gl_context = c.SDL_GL_CreateContext(window);
    if (gl_context == null) {
        std.debug.print("SDL_GL_CreateContext failed\n", .{});
        return;
    }
    defer c.SDL_GL_DeleteContext(gl_context);

    // Enable VSync
    _ = c.SDL_GL_SetSwapInterval(1);

    // Set up initial viewport
    globals.xdim = 1280;
    globals.ydim = 720;
    globals.viewingrange = 65536;
    globals.yxaspect = 65536;
    globals.globalhoriz = types.fix16FromInt(100);

    // Initialize polymost
    _ = polymost.render.polymost_init();

    std.debug.print("\nControls:\n", .{});
    std.debug.print("  W/S - Move forward/backward\n", .{});
    std.debug.print("  A/D - Strafe left/right\n", .{});
    std.debug.print("  Left/Right arrows - Turn\n", .{});
    std.debug.print("  Up/Down arrows - Look up/down\n", .{});
    std.debug.print("  T - Toggle textures\n", .{});
    std.debug.print("  Escape - Quit\n", .{});

    // Check for --screenshot flag
    var screenshot_mode = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--screenshot")) {
            screenshot_mode = true;
        }
    }

    // Main loop
    var running = true;
    var last_time = c.SDL_GetTicks();
    var frame_count: u32 = 0;

    while (running) {
        // Handle events
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            } else if (event.type == c.SDL_KEYDOWN) {
                const sym = event.key.keysym.sym;
                if (sym == c.SDLK_ESCAPE) {
                    running = false;
                } else switch (sym) {
                    c.SDLK_t => {
                        polymost.render.use_textures = !polymost.render.use_textures;
                        std.debug.print("Textures: {s}\n", .{if (polymost.render.use_textures) @as([]const u8, "ON") else @as([]const u8, "OFF")});
                    },
                    else => {},
                }
            }
        }

        // Calculate delta time
        const current_time = c.SDL_GetTicks();
        const dt: f32 = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        last_time = current_time;

        // Get keyboard state for movement
        const keys = c.SDL_GetKeyboardState(null);

        // Movement speed
        const move_speed: i32 = @intFromFloat(50000.0 * dt);
        const turn_speed: i16 = @intFromFloat(512.0 * dt);
        const look_speed: i32 = @intFromFloat(50.0 * dt);

        // Calculate forward/side vectors
        const ang = globals.globalang;
        const cos_ang = globals.getSin(ang + 512); // cos = sin(ang + 90)
        const sin_ang = globals.getSin(ang);

        // Forward/backward
        if (keys[c.SDL_SCANCODE_W] != 0) {
            globals.globalposx += @divTrunc(cos_ang * move_speed, 16384);
            globals.globalposy += @divTrunc(sin_ang * move_speed, 16384);
        }
        if (keys[c.SDL_SCANCODE_S] != 0) {
            globals.globalposx -= @divTrunc(cos_ang * move_speed, 16384);
            globals.globalposy -= @divTrunc(sin_ang * move_speed, 16384);
        }

        // Strafe left/right
        if (keys[c.SDL_SCANCODE_A] != 0) {
            globals.globalposx -= @divTrunc(sin_ang * move_speed, 16384);
            globals.globalposy += @divTrunc(cos_ang * move_speed, 16384);
        }
        if (keys[c.SDL_SCANCODE_D] != 0) {
            globals.globalposx += @divTrunc(sin_ang * move_speed, 16384);
            globals.globalposy -= @divTrunc(cos_ang * move_speed, 16384);
        }

        // Turn
        if (keys[c.SDL_SCANCODE_LEFT] != 0) {
            globals.globalang = @intCast((@as(i32, globals.globalang) - turn_speed) & 2047);
        }
        if (keys[c.SDL_SCANCODE_RIGHT] != 0) {
            globals.globalang = @intCast((@as(i32, globals.globalang) + turn_speed) & 2047);
        }

        // Look up/down
        var horiz = types.fix16ToInt(globals.globalhoriz);
        if (keys[c.SDL_SCANCODE_UP] != 0) {
            horiz = @min(199, horiz + look_speed);
        }
        if (keys[c.SDL_SCANCODE_DOWN] != 0) {
            horiz = @max(1, horiz - look_speed);
        }
        globals.globalhoriz = types.fix16FromInt(horiz);

        // Clear screen
        const gl = build_engine.gl.bindings;
        gl.glClearColor(0.1, 0.1, 0.2, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

        // Render the scene
        polymost.render.polymost_drawrooms();

        // Swap buffers
        c.SDL_GL_SwapWindow(window);

        frame_count += 1;

        // Screenshot mode: save first frame and exit
        if (screenshot_mode and frame_count == 1) {
            saveScreenshot(allocator, 1280, 720) catch |err| {
                std.debug.print("Failed to save screenshot: {}\n", .{err});
            };
            running = false;
        }
    }

    std.debug.print("Shutting down...\n", .{});
}
