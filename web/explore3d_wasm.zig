//! 3D Map Explorer - WASM Version
//! This is the WebAssembly entry point for the 3D map explorer.

const std = @import("std");
const types = @import("types");
const constants = @import("constants");
const globals = @import("globals");
const map_loader = @import("map");
const webgl = @import("webgl");
const web = @import("web");
const render = @import("render_web");

// =============================================================================
// Player State
// =============================================================================

const Player = struct {
    x: i32,
    y: i32,
    z: i32,
    ang: i16,
    horiz: i32,
    sectnum: i16,

    move_speed: i32 = 2048,
    turn_speed: i32 = 512,
    look_speed: i32 = 256,
    vertical_speed: i32 = 4096,

    fn update(self: *Player, inp: *const web.Input, dt: f32) void {
        const speed_mult: f32 = if (inp.speed_modifier) 3.0 else 1.0;

        const ang_rad = @as(f32, @floatFromInt(self.ang)) * std.math.pi * 2.0 / 2048.0;
        const cos_ang = @cos(ang_rad);
        const sin_ang = @sin(ang_rad);

        var dx: f32 = 0;
        var dy: f32 = 0;

        if (inp.forward) {
            dx += cos_ang;
            dy += sin_ang;
        }
        if (inp.backward) {
            dx -= cos_ang;
            dy -= sin_ang;
        }
        if (inp.strafe_right) {
            dx += sin_ang;
            dy -= cos_ang;
        }
        if (inp.strafe_left) {
            dx -= sin_ang;
            dy += cos_ang;
        }

        const len = @sqrt(dx * dx + dy * dy);
        if (len > 0.001) {
            dx /= len;
            dy /= len;
        }

        const move_amount = @as(f32, @floatFromInt(self.move_speed)) * dt * speed_mult;
        self.x += @intFromFloat(dx * move_amount);
        self.y += @intFromFloat(dy * move_amount);

        const vert_amount = @as(f32, @floatFromInt(self.vertical_speed)) * dt * speed_mult;
        if (inp.move_up) {
            self.z -= @intFromFloat(vert_amount);
        }
        if (inp.move_down) {
            self.z += @intFromFloat(vert_amount);
        }

        const turn_amount = @as(f32, @floatFromInt(self.turn_speed)) * dt * speed_mult;
        if (inp.turn_left) {
            self.ang += @intFromFloat(turn_amount);
        }
        if (inp.turn_right) {
            self.ang -= @intFromFloat(turn_amount);
        }

        if (inp.mouse_dx != 0) {
            const mouse_sensitivity: f32 = 0.5;
            self.ang -= @intFromFloat(@as(f32, @floatFromInt(inp.mouse_dx)) * mouse_sensitivity);
        }

        self.ang = @mod(self.ang, 2048);
        if (self.ang < 0) self.ang += 2048;

        const look_amount = @as(f32, @floatFromInt(self.look_speed)) * dt * speed_mult;
        if (inp.look_up) {
            self.horiz += @intFromFloat(look_amount);
        }
        if (inp.look_down) {
            self.horiz -= @intFromFloat(look_amount);
        }

        if (inp.mouse_dy != 0) {
            const mouse_sensitivity: f32 = 0.3;
            self.horiz -= @intFromFloat(@as(f32, @floatFromInt(inp.mouse_dy)) * mouse_sensitivity);
        }

        self.horiz = std.math.clamp(self.horiz, -200, 300);
    }

    fn applyToGlobals(self: *const Player) void {
        globals.globalposx = self.x;
        globals.globalposy = self.y;
        globals.globalposz = self.z;
        globals.globalang = self.ang;
        globals.globalhoriz = types.fix16FromInt(self.horiz);
        globals.globalcursectnum = self.sectnum;
    }
};

// =============================================================================
// Global State
// =============================================================================

var player: Player = undefined;
var map_loaded: bool = false;
var last_time: u64 = 0;

// =============================================================================
// Exported Functions (called from JavaScript)
// =============================================================================

/// Initialize the engine
export fn init() void {
    globals.initGlobals();
    globals.initSinTable();
    render.polymost_init();

    globals.xdim = web.getWidth();
    globals.ydim = web.getHeight();
    globals.viewingrange = 65536;
    globals.yxaspect = 65536;

    last_time = web.getTicks();

    web.log("Engine initialized. Canvas: {}x{}", .{ globals.xdim, globals.ydim });
}

/// Load map data from a pointer (called after JS loads the file)
export fn loadMapData(data_ptr: [*]const u8, data_len: usize) bool {
    const data = data_ptr[0..data_len];

    const map_data = map_loader.loadMap(web.wasm_allocator, data) catch |err| {
        web.logError("Failed to load map: {}", .{err});
        return false;
    };

    // Initialize player at map start
    player = Player{
        .x = map_data.startx,
        .y = map_data.starty,
        .z = map_data.startz,
        .ang = map_data.startang,
        .horiz = 100,
        .sectnum = map_data.startsect,
    };

    map_loaded = true;

    web.log("Map loaded: {} sectors, {} walls, {} sprites", .{
        map_data.numsectors,
        map_data.numwalls,
        map_data.numsprites,
    });
    web.log("Start position: ({}, {}, {})", .{
        map_data.startx,
        map_data.starty,
        map_data.startz,
    });

    return true;
}

/// Called every frame from JavaScript's requestAnimationFrame
export fn frame() void {
    if (!map_loaded) return;

    // Calculate delta time
    const current_time = web.getTicks();
    const dt_ms = current_time - last_time;
    const dt: f32 = @as(f32, @floatFromInt(dt_ms)) / 1000.0;
    last_time = current_time;

    // Cap dt to prevent huge jumps
    const capped_dt = @min(dt, 0.1);

    // Get input
    const inp = web.getInput();

    // Update player
    player.update(&inp, capped_dt);
    player.applyToGlobals();

    // Update canvas size if changed
    globals.xdim = web.getWidth();
    globals.ydim = web.getHeight();

    // Set viewport
    webgl.glViewport(0, 0, globals.xdim, globals.ydim);

    // Clear screen
    webgl.glClearColor(0.1, 0.1, 0.15, 1.0);
    webgl.glClear(webgl.GL_COLOR_BUFFER_BIT | webgl.GL_DEPTH_BUFFER_BIT);

    // Render scene
    render.polymost_drawrooms();
}

/// Get current player position (for debug display in JS)
export fn getPlayerX() i32 {
    return player.x;
}

export fn getPlayerY() i32 {
    return player.y;
}

export fn getPlayerZ() i32 {
    return player.z;
}

export fn getPlayerAng() i16 {
    return player.ang;
}

/// Allocate memory (for JS to use when loading map data)
export fn allocate(size: usize) ?[*]u8 {
    const slice = web.wasm_allocator.alloc(u8, size) catch return null;
    return slice.ptr;
}

/// Free memory
export fn deallocate(ptr: [*]u8, size: usize) void {
    web.wasm_allocator.free(ptr[0..size]);
}
