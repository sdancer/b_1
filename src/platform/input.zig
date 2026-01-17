//! Input System
//! Tracks keyboard and mouse state for player movement.

const std = @import("std");
const sdl = @import("sdl.zig");

// =============================================================================
// Input State
// =============================================================================

/// Movement and action input state
pub const Input = struct {
    // Movement
    forward: bool = false,
    backward: bool = false,
    strafe_left: bool = false,
    strafe_right: bool = false,

    // Rotation
    turn_left: bool = false,
    turn_right: bool = false,
    look_up: bool = false,
    look_down: bool = false,

    // Vertical movement
    move_up: bool = false,
    move_down: bool = false,

    // Modifiers
    speed_modifier: bool = false,

    // Mouse
    mouse_dx: i32 = 0,
    mouse_dy: i32 = 0,

    // Actions
    quit: bool = false,
};

// =============================================================================
// Input Collection
// =============================================================================

/// Get current input state from SDL
pub fn getInput() Input {
    var input = Input{};

    // Process events first (for quit and mouse motion)
    const events = sdl.processEvents();
    input.quit = events.quit;
    input.mouse_dx = events.mouse_dx;
    input.mouse_dy = events.mouse_dy;

    // Get keyboard state
    const keyboard = sdl.SDL_GetKeyboardState(null);

    // Movement keys (WASD)
    input.forward = keyboard[@intCast(sdl.SDL_SCANCODE_W)] != 0;
    input.backward = keyboard[@intCast(sdl.SDL_SCANCODE_S)] != 0;
    input.strafe_left = keyboard[@intCast(sdl.SDL_SCANCODE_A)] != 0;
    input.strafe_right = keyboard[@intCast(sdl.SDL_SCANCODE_D)] != 0;

    // Vertical movement (Q/E or Space/C)
    input.move_up = keyboard[@intCast(sdl.SDL_SCANCODE_Q)] != 0 or
                    keyboard[@intCast(sdl.SDL_SCANCODE_SPACE)] != 0;
    input.move_down = keyboard[@intCast(sdl.SDL_SCANCODE_E)] != 0;

    // Rotation keys (Arrow keys)
    input.turn_left = keyboard[@intCast(sdl.SDL_SCANCODE_LEFT)] != 0;
    input.turn_right = keyboard[@intCast(sdl.SDL_SCANCODE_RIGHT)] != 0;
    input.look_up = keyboard[@intCast(sdl.SDL_SCANCODE_UP)] != 0;
    input.look_down = keyboard[@intCast(sdl.SDL_SCANCODE_DOWN)] != 0;

    // Modifiers
    input.speed_modifier = keyboard[@intCast(sdl.SDL_SCANCODE_LSHIFT)] != 0 or
                          keyboard[@intCast(sdl.SDL_SCANCODE_RSHIFT)] != 0;

    // ESC for quit
    if (keyboard[@intCast(sdl.SDL_SCANCODE_ESCAPE)] != 0) {
        input.quit = true;
    }

    return input;
}

// =============================================================================
// Input Utilities
// =============================================================================

/// Check if any movement input is active
pub fn hasMovement(input: *const Input) bool {
    return input.forward or input.backward or
           input.strafe_left or input.strafe_right or
           input.move_up or input.move_down;
}

/// Check if any rotation input is active
pub fn hasRotation(input: *const Input) bool {
    return input.turn_left or input.turn_right or
           input.look_up or input.look_down or
           input.mouse_dx != 0 or input.mouse_dy != 0;
}

// =============================================================================
// Tests
// =============================================================================

test "default input state" {
    const input = Input{};
    try std.testing.expect(!input.forward);
    try std.testing.expect(!input.quit);
    try std.testing.expectEqual(@as(i32, 0), input.mouse_dx);
}
