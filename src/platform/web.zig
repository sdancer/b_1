//! Web Platform Layer
//! Provides platform functions for running in a browser via WASM.

const std = @import("std");

// =============================================================================
// JavaScript Imports
// =============================================================================

extern "env" fn consoleLog(ptr: [*]const u8, len: usize) void;
extern "env" fn consoleError(ptr: [*]const u8, len: usize) void;
extern "env" fn getCanvasWidth() i32;
extern "env" fn getCanvasHeight() i32;
extern "env" fn getTimeMs() f64;

// Input state (set by JavaScript)
extern "env" fn isKeyPressed(scancode: u32) bool;
extern "env" fn getMouseDeltaX() i32;
extern "env" fn getMouseDeltaY() i32;
extern "env" fn resetMouseDelta() void;

// =============================================================================
// Logging
// =============================================================================

pub fn log(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleLog(msg.ptr, msg.len);
}

pub fn logError(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleError(msg.ptr, msg.len);
}

// =============================================================================
// Canvas/Window
// =============================================================================

pub fn getWidth() i32 {
    return getCanvasWidth();
}

pub fn getHeight() i32 {
    return getCanvasHeight();
}

// =============================================================================
// Timing
// =============================================================================

pub fn getTicks() u64 {
    return @intFromFloat(getTimeMs());
}

// =============================================================================
// Input
// =============================================================================

// Scancode values (matching SDL scancodes used in input.zig)
pub const SCANCODE_W: u32 = 26;
pub const SCANCODE_A: u32 = 4;
pub const SCANCODE_S: u32 = 22;
pub const SCANCODE_D: u32 = 7;
pub const SCANCODE_Q: u32 = 20;
pub const SCANCODE_E: u32 = 8;
pub const SCANCODE_UP: u32 = 82;
pub const SCANCODE_DOWN: u32 = 81;
pub const SCANCODE_LEFT: u32 = 80;
pub const SCANCODE_RIGHT: u32 = 79;
pub const SCANCODE_LSHIFT: u32 = 225;
pub const SCANCODE_SPACE: u32 = 44;
pub const SCANCODE_ESCAPE: u32 = 41;

/// Input state structure
pub const Input = struct {
    forward: bool = false,
    backward: bool = false,
    strafe_left: bool = false,
    strafe_right: bool = false,
    turn_left: bool = false,
    turn_right: bool = false,
    look_up: bool = false,
    look_down: bool = false,
    move_up: bool = false,
    move_down: bool = false,
    speed_modifier: bool = false,
    mouse_dx: i32 = 0,
    mouse_dy: i32 = 0,
    quit: bool = false,
};

pub fn getInput() Input {
    var input = Input{};

    // Movement
    input.forward = isKeyPressed(SCANCODE_W);
    input.backward = isKeyPressed(SCANCODE_S);
    input.strafe_left = isKeyPressed(SCANCODE_A);
    input.strafe_right = isKeyPressed(SCANCODE_D);

    // Vertical
    input.move_up = isKeyPressed(SCANCODE_Q) or isKeyPressed(SCANCODE_SPACE);
    input.move_down = isKeyPressed(SCANCODE_E);

    // Rotation
    input.turn_left = isKeyPressed(SCANCODE_LEFT);
    input.turn_right = isKeyPressed(SCANCODE_RIGHT);
    input.look_up = isKeyPressed(SCANCODE_UP);
    input.look_down = isKeyPressed(SCANCODE_DOWN);

    // Modifier
    input.speed_modifier = isKeyPressed(SCANCODE_LSHIFT);

    // Mouse
    input.mouse_dx = getMouseDeltaX();
    input.mouse_dy = getMouseDeltaY();
    resetMouseDelta();

    // ESC
    input.quit = isKeyPressed(SCANCODE_ESCAPE);

    return input;
}

// =============================================================================
// Memory Allocator for WASM
// =============================================================================

/// Page allocator for WASM (uses memory.grow)
pub const wasm_allocator = std.heap.wasm_allocator;
