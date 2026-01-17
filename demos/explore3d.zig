//! 3D Map Explorer Demo
//!
//! Loads Blood maps and allows free camera movement through the level.
//! Uses the Polymost renderer for OpenGL 1.x rendering.
//!
//! Usage:
//!   explore3d <mapfile.map>
//!   explore3d --rff <archive.rff> <mapname>
//!
//! Controls:
//!   W/S       - Move forward/backward
//!   A/D       - Strafe left/right
//!   Q/Space   - Move up
//!   E         - Move down
//!   Arrows    - Turn and look up/down
//!   Shift     - Move faster
//!   Escape    - Quit

const std = @import("std");
const build = @import("build_engine");

const sdl = build.platform.sdl;
const input = build.platform.input;
const player_mod = build.engine.player;
const polymost = build.polymost.render;
const globals = build.globals;
const fs = build.fs;
const gl = build.gl.bindings;

// =============================================================================
// Configuration
// =============================================================================

const WINDOW_WIDTH = 1280;
const WINDOW_HEIGHT = 720;
const WINDOW_TITLE = "Blood 3D Explorer";
const TARGET_FPS = 60;
const FRAME_TIME_MS: u32 = 1000 / TARGET_FPS;

// =============================================================================
// Main
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage(args[0]);
        return;
    }

    // Initialize the build engine
    build.init();

    // Load map based on arguments
    var map_data: fs.map.MapData = undefined;
    var rff_data: ?[]u8 = null;
    defer if (rff_data) |d| allocator.free(d);
    var extracted_map: ?[]u8 = null;
    defer if (extracted_map) |m| allocator.free(m);

    if (std.mem.eql(u8, args[1], "--rff")) {
        if (args.len < 4) {
            std.debug.print("Error: --rff requires an archive path and map name\n", .{});
            printUsage(args[0]);
            return;
        }

        const rff_path = args[2];
        const map_name = args[3];

        std.debug.print("Loading RFF archive: {s}\n", .{rff_path});

        // Load RFF
        const rff_result = fs.rff.loadRFFFromFile(allocator, rff_path) catch |err| {
            std.debug.print("Error loading RFF: {}\n", .{err});
            return;
        };
        rff_data = rff_result.data;
        var archive = rff_result.archive;
        defer archive.deinit();

        // Find the map
        const entry = archive.find(map_name, "MAP") orelse {
            std.debug.print("Error: Map '{s}' not found in archive\n", .{map_name});
            return;
        };

        std.debug.print("Found map: {s}.MAP ({d} bytes)\n", .{ entry.getName(), entry.size });

        // Extract map data
        extracted_map = archive.getData(allocator, entry) catch |err| {
            std.debug.print("Error extracting map: {}\n", .{err});
            return;
        };

        // Load the map
        map_data = build.loadMap(allocator, extracted_map.?) catch |err| {
            std.debug.print("Error parsing map: {}\n", .{err});
            return;
        };
    } else {
        // Direct file loading
        const map_path = args[1];

        std.debug.print("Loading map: {s}\n", .{map_path});

        map_data = build.loadMapFromFile(allocator, map_path) catch |err| {
            std.debug.print("Error loading map: {}\n", .{err});
            return;
        };
    }
    defer map_data.deinit();

    // Print map info
    std.debug.print("\n=== Map Information ===\n", .{});
    std.debug.print("Sectors: {}\n", .{map_data.numsectors});
    std.debug.print("Walls: {}\n", .{map_data.numwalls});
    std.debug.print("Sprites: {}\n", .{map_data.numsprites});
    std.debug.print("Start: ({}, {}, {})\n", .{ map_data.startx, map_data.starty, map_data.startz });
    std.debug.print("Start angle: {}, sector: {}\n", .{ map_data.startang, map_data.startsect });

    // Initialize SDL and create window
    std.debug.print("\nInitializing SDL...\n", .{});
    var window = sdl.Window.init(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE) catch |err| {
        std.debug.print("Failed to create window: {}\n", .{err});
        return;
    };
    defer window.deinit();

    // Set up globals for rendering
    globals.xdim = WINDOW_WIDTH;
    globals.ydim = WINDOW_HEIGHT;
    globals.viewingrange = 65536;
    globals.yxaspect = 65536;

    // Initialize player at map start position
    var player = player_mod.Player.initFromMap(&map_data);

    // Capture mouse for first-person control
    window.setMouseCapture(true);

    std.debug.print("\n=== Controls ===\n", .{});
    std.debug.print("W/S       - Forward/Backward\n", .{});
    std.debug.print("A/D       - Strafe Left/Right\n", .{});
    std.debug.print("Q/Space   - Move Up\n", .{});
    std.debug.print("E         - Move Down\n", .{});
    std.debug.print("Arrows    - Turn and Look\n", .{});
    std.debug.print("Shift     - Move Faster\n", .{});
    std.debug.print("Escape    - Quit\n", .{});
    std.debug.print("\nStarting renderer...\n", .{});

    // Main loop
    var last_time = sdl.getTicks();
    var running = true;

    while (running) {
        const current_time = sdl.getTicks();
        const dt_ms = current_time - last_time;
        const dt: f32 = @as(f32, @floatFromInt(dt_ms)) / 1000.0;
        last_time = current_time;

        // Get input
        const inp = input.getInput();
        if (inp.quit) {
            running = false;
            continue;
        }

        // Update player
        player.update(&inp, dt);

        // Apply player state to globals for rendering
        player.applyToGlobals();

        // Set viewport
        gl.glViewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);

        // Clear screen with dark blue/gray
        gl.glClearColor(0.1, 0.1, 0.15, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

        // Render the scene
        polymost.polymost_drawrooms();

        // Swap buffers
        window.swapBuffers();

        // Frame rate limiting
        const frame_time = sdl.getTicks() - current_time;
        if (frame_time < FRAME_TIME_MS) {
            sdl.delay(FRAME_TIME_MS - frame_time);
        }
    }

    std.debug.print("\nExiting...\n", .{});
}

fn printUsage(program: []const u8) void {
    std.debug.print("Blood 3D Map Explorer\n\n", .{});
    std.debug.print("Usage:\n", .{});
    std.debug.print("  {s} <mapfile.map>\n", .{program});
    std.debug.print("  {s} --rff <archive.rff> <mapname>\n\n", .{program});
    std.debug.print("Examples:\n", .{});
    std.debug.print("  {s} level.map\n", .{program});
    std.debug.print("  {s} --rff blood.rff E1M1\n\n", .{program});
    std.debug.print("Controls:\n", .{});
    std.debug.print("  W/S       - Move forward/backward\n", .{});
    std.debug.print("  A/D       - Strafe left/right\n", .{});
    std.debug.print("  Q/Space   - Move up\n", .{});
    std.debug.print("  E         - Move down\n", .{});
    std.debug.print("  Arrows    - Turn and look up/down\n", .{});
    std.debug.print("  Shift     - Move faster\n", .{});
    std.debug.print("  Escape    - Quit\n", .{});
}
