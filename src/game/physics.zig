//! Blood/NBlood Movement Physics System
//! Port from: NBlood/source/blood/src/player.cpp ProcessInput() lines 1565-1954
//!            NBlood/source/blood/src/actor.cpp position update & gravity
//!
//! This module implements the player movement physics matching NBlood's behavior.
//! Physics runs at a fixed 120 Hz tick rate (CLOCKTICKSPERSECOND).

const std = @import("std");
const globals = @import("../globals.zig");
const constants = @import("../constants.zig");
const mulscale = @import("../math/mulscale.zig");
const posture = @import("posture.zig");

// =============================================================================
// Timing Constants
// =============================================================================

/// Game logic tick rate (from BUILD engine)
pub const TICKS_PER_SECOND: i32 = constants.CLOCKTICKSPERSECOND; // 120

/// Microseconds per tick
pub const TICK_DURATION_US: i64 = 1_000_000 / TICKS_PER_SECOND; // ~8333 us

/// Milliseconds per tick (as float for accumulator)
pub const TICK_DURATION_MS: f32 = 1000.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND)); // ~8.33 ms

// =============================================================================
// Physics Constants (from NBlood actor.cpp)
// =============================================================================

/// Gravity constant applied per tick (from actor.cpp)
/// zvel[nSprite] += 58254
pub const GRAVITY: i32 = 58254;

/// Ground friction damping factor
/// Typical ground: 0xB000 (about 68.75% retention per frame)
pub const GROUND_DAMPING: i32 = 0xB000;

/// Air friction damping factor (less friction in air)
pub const AIR_DAMPING: i32 = 0xD000;

/// Water friction damping factor (more resistance in water)
pub const WATER_DAMPING: i32 = 0x9000;

/// Maximum horizontal velocity
pub const MAX_XY_VEL: i32 = 0x400000; // 4194304

/// Maximum vertical velocity (terminal velocity)
pub const MAX_Z_VEL: i32 = 0x200000; // 2097152

// =============================================================================
// Input Processing
// =============================================================================

/// Process player input and update velocities
/// Matches NBlood player.cpp ProcessInput() lines 1700-1750
///
/// Parameters:
/// - sprite_idx: Index of the player's sprite in the sprite array
/// - ang: Current facing angle (0-2047, BUILD units)
/// - forward: Forward/backward input (-1.0 to 1.0 scaled to fixed point)
/// - strafe: Left/right strafe input (-1.0 to 1.0 scaled to fixed point)
/// - posture_type: Current posture (stand, swim, crouch)
/// - is_running: Whether the player is running (shift held)
pub fn processInput(
    sprite_idx: usize,
    ang: i16,
    forward: i32,
    strafe: i32,
    posture_type: posture.PostureType,
    is_running: bool,
) void {
    const post = posture.getPosture(.normal, posture_type);

    // Get acceleration values based on direction
    var front_accel = post.frontAccel;
    var side_accel = post.sideAccel;

    // Running increases acceleration
    if (is_running) {
        front_accel = mulscale.mulscale16(front_accel, posture.RUN_ACCEL_MULTIPLIER);
        side_accel = mulscale.mulscale16(side_accel, posture.RUN_ACCEL_MULTIPLIER);
    }

    // Scale input by posture acceleration
    // forward is expected to be in range [-0x10000, 0x10000] for full input
    const fwd_scaled = mulscale.mulscale16(forward, front_accel);
    const str_scaled = mulscale.mulscale16(strafe, side_accel);

    // Get trig values for angle
    const cos_ang = globals.getCos(ang);
    const sin_ang = globals.getSin(ang);

    // Forward/backward: add to velocity along angle direction
    // NBlood: xvel[pSprite->index] += mulscale30(forward, Cos(pSprite->ang));
    //         yvel[pSprite->index] += mulscale30(forward, Sin(pSprite->ang));
    globals.xvel[sprite_idx] += mulscale.mulscale30(fwd_scaled, cos_ang);
    globals.yvel[sprite_idx] += mulscale.mulscale30(fwd_scaled, sin_ang);

    // Strafing: perpendicular to angle (ang + 512 = 90 degrees in BUILD)
    // NBlood: xvel[pSprite->index] += mulscale30(strafe, Cos(pSprite->ang + 512));
    //         yvel[pSprite->index] += mulscale30(strafe, Sin(pSprite->ang + 512));
    const strafe_ang: i16 = ang +% 512; // Wrapping add for angle
    globals.xvel[sprite_idx] += mulscale.mulscale30(str_scaled, globals.getCos(strafe_ang));
    globals.yvel[sprite_idx] += mulscale.mulscale30(str_scaled, globals.getSin(strafe_ang));
}

/// Simplified input processing that works with direction values
/// This is useful for demos where input is just WASD keys
pub fn processInputSimple(
    sprite_idx: usize,
    ang: i16,
    forward: i32,
    strafe: i32,
) void {
    processInput(sprite_idx, ang, forward, strafe, .stand, false);
}

// =============================================================================
// Velocity Application
// =============================================================================

/// Apply velocity to sprite position
/// Matches NBlood actor.cpp position update:
/// pSprite->x += xvel[nSprite] >> 12;
/// pSprite->y += yvel[nSprite] >> 12;
/// pSprite->z += zvel[nSprite] >> 8;
pub fn applyVelocityToSprite(sprite_idx: usize) void {
    const spr = &globals.sprite[sprite_idx];
    spr.x += globals.xvel[sprite_idx] >> 12;
    spr.y += globals.yvel[sprite_idx] >> 12;
    spr.z += globals.zvel[sprite_idx] >> 8;
}

/// Apply velocity to global camera position
/// Used when the camera is not tied to a specific sprite
pub fn applyVelocityToCamera(sprite_idx: usize) void {
    globals.globalposx += globals.xvel[sprite_idx] >> 12;
    globals.globalposy += globals.yvel[sprite_idx] >> 12;
    globals.globalposz += globals.zvel[sprite_idx] >> 8;
}

/// Apply velocity with custom shift values
pub fn applyVelocityCustom(sprite_idx: usize, xy_shift: u5, z_shift: u5) void {
    globals.globalposx += globals.xvel[sprite_idx] >> xy_shift;
    globals.globalposy += globals.yvel[sprite_idx] >> xy_shift;
    globals.globalposz += globals.zvel[sprite_idx] >> z_shift;
}

// =============================================================================
// Friction/Damping
// =============================================================================

/// Minimum velocity threshold - below this, velocity is zeroed
/// Prevents infinite drift from floating point / integer precision issues
pub const VELOCITY_STOP_THRESHOLD: i32 = 0x1000; // 4096

/// Apply velocity damping (friction)
/// NBlood uses different damping per surface type
pub fn applyDamping(sprite_idx: usize, damping: i32) void {
    globals.xvel[sprite_idx] = mulscale.mulscale16(globals.xvel[sprite_idx], damping);
    globals.yvel[sprite_idx] = mulscale.mulscale16(globals.yvel[sprite_idx], damping);

    // Zero out very small velocities to prevent infinite drift
    if (mulscale.klabs(globals.xvel[sprite_idx]) < VELOCITY_STOP_THRESHOLD) {
        globals.xvel[sprite_idx] = 0;
    }
    if (mulscale.klabs(globals.yvel[sprite_idx]) < VELOCITY_STOP_THRESHOLD) {
        globals.yvel[sprite_idx] = 0;
    }
}

/// Apply ground damping (standard ground friction)
pub fn applyGroundDamping(sprite_idx: usize) void {
    applyDamping(sprite_idx, GROUND_DAMPING);
}

/// Apply air damping (less friction when airborne)
pub fn applyAirDamping(sprite_idx: usize) void {
    applyDamping(sprite_idx, AIR_DAMPING);
}

/// Apply water damping (more resistance in water)
pub fn applyWaterDamping(sprite_idx: usize) void {
    applyDamping(sprite_idx, WATER_DAMPING);
}

/// Apply full damping to all velocity components including Z
pub fn applyFullDamping(sprite_idx: usize, damping: i32) void {
    globals.xvel[sprite_idx] = mulscale.mulscale16(globals.xvel[sprite_idx], damping);
    globals.yvel[sprite_idx] = mulscale.mulscale16(globals.yvel[sprite_idx], damping);
    globals.zvel[sprite_idx] = mulscale.mulscale16(globals.zvel[sprite_idx], damping);
}

// =============================================================================
// Gravity
// =============================================================================

/// Apply gravity to Z velocity
pub fn applyGravity(sprite_idx: usize) void {
    globals.zvel[sprite_idx] += GRAVITY;

    // Clamp to terminal velocity
    if (globals.zvel[sprite_idx] > MAX_Z_VEL) {
        globals.zvel[sprite_idx] = MAX_Z_VEL;
    }
}

/// Apply reduced gravity (e.g., when in water)
pub fn applyReducedGravity(sprite_idx: usize, factor: i32) void {
    globals.zvel[sprite_idx] += mulscale.mulscale16(GRAVITY, factor);

    if (globals.zvel[sprite_idx] > MAX_Z_VEL) {
        globals.zvel[sprite_idx] = MAX_Z_VEL;
    }
}

// =============================================================================
// Jumping
// =============================================================================

/// Apply jump impulse
pub fn jump(sprite_idx: usize, posture_type: posture.PostureType, has_powerup: bool) void {
    const post = posture.getPosture(.normal, posture_type);
    globals.zvel[sprite_idx] = if (has_powerup) post.pwupJumpZ else post.normalJumpZ;
}

/// Apply custom jump velocity
pub fn jumpCustom(sprite_idx: usize, jump_velocity: i32) void {
    globals.zvel[sprite_idx] = jump_velocity;
}

// =============================================================================
// Velocity Queries
// =============================================================================

/// Get current horizontal speed (magnitude of XY velocity)
pub fn getHorizontalSpeed(sprite_idx: usize) i32 {
    const xv = globals.xvel[sprite_idx];
    const yv = globals.yvel[sprite_idx];

    // Approximate magnitude using |x| + |y| (faster than sqrt)
    const ax = mulscale.klabs(xv);
    const ay = mulscale.klabs(yv);

    // Better approximation: max + 3/8 * min
    if (ax > ay) {
        return ax + (ay >> 2) + (ay >> 3);
    } else {
        return ay + (ax >> 2) + (ax >> 3);
    }
}

/// Check if entity is moving
pub fn isMoving(sprite_idx: usize) bool {
    const threshold: i32 = 256; // Minimum velocity to be considered moving
    return mulscale.klabs(globals.xvel[sprite_idx]) > threshold or
        mulscale.klabs(globals.yvel[sprite_idx]) > threshold;
}

/// Check if entity is falling
pub fn isFalling(sprite_idx: usize) bool {
    return globals.zvel[sprite_idx] > 0;
}

/// Check if entity is rising (jumping)
pub fn isRising(sprite_idx: usize) bool {
    return globals.zvel[sprite_idx] < 0;
}

// =============================================================================
// Velocity Control
// =============================================================================

/// Set velocity directly
pub fn setVelocity(sprite_idx: usize, x: i32, y: i32, z: i32) void {
    globals.xvel[sprite_idx] = x;
    globals.yvel[sprite_idx] = y;
    globals.zvel[sprite_idx] = z;
}

/// Add impulse to velocity
pub fn addImpulse(sprite_idx: usize, x: i32, y: i32, z: i32) void {
    globals.xvel[sprite_idx] += x;
    globals.yvel[sprite_idx] += y;
    globals.zvel[sprite_idx] += z;
}

/// Clear all velocity
pub fn stopMovement(sprite_idx: usize) void {
    globals.xvel[sprite_idx] = 0;
    globals.yvel[sprite_idx] = 0;
    globals.zvel[sprite_idx] = 0;
}

/// Clear horizontal velocity only
pub fn stopHorizontalMovement(sprite_idx: usize) void {
    globals.xvel[sprite_idx] = 0;
    globals.yvel[sprite_idx] = 0;
}

/// Clear vertical velocity only
pub fn stopVerticalMovement(sprite_idx: usize) void {
    globals.zvel[sprite_idx] = 0;
}

/// Clamp velocity to maximum values
pub fn clampVelocity(sprite_idx: usize) void {
    globals.xvel[sprite_idx] = mulscale.clamp(globals.xvel[sprite_idx], -MAX_XY_VEL, MAX_XY_VEL);
    globals.yvel[sprite_idx] = mulscale.clamp(globals.yvel[sprite_idx], -MAX_XY_VEL, MAX_XY_VEL);
    globals.zvel[sprite_idx] = mulscale.clamp(globals.zvel[sprite_idx], -MAX_Z_VEL, MAX_Z_VEL);
}

// =============================================================================
// Complete Physics Step (per tick)
// =============================================================================

/// Run a complete physics step for a sprite on ground
pub fn stepGroundPhysics(sprite_idx: usize, ang: i16, forward: i32, strafe: i32) void {
    processInputSimple(sprite_idx, ang, forward, strafe);
    applyGroundDamping(sprite_idx);
    clampVelocity(sprite_idx);
    applyVelocityToCamera(sprite_idx);
}

/// Run a complete physics step for a sprite in air
pub fn stepAirPhysics(sprite_idx: usize, ang: i16, forward: i32, strafe: i32) void {
    // Reduced control in air (1/4 input effectiveness)
    processInputSimple(sprite_idx, ang, forward >> 2, strafe >> 2);
    applyAirDamping(sprite_idx);
    applyGravity(sprite_idx);
    clampVelocity(sprite_idx);
    applyVelocityToCamera(sprite_idx);
}

/// Run a complete physics step for a sprite in water
pub fn stepWaterPhysics(sprite_idx: usize, ang: i16, forward: i32, strafe: i32) void {
    processInput(sprite_idx, ang, forward, strafe, .swim, false);
    applyWaterDamping(sprite_idx);
    applyReducedGravity(sprite_idx, 0x4000); // 1/4 gravity in water
    clampVelocity(sprite_idx);
    applyVelocityToCamera(sprite_idx);
}

// =============================================================================
// Fixed Timestep System (120 Hz)
// =============================================================================

/// Input state for physics processing
pub const InputState = struct {
    forward: i32 = 0, // Positive = forward, negative = backward
    strafe: i32 = 0, // Positive = right, negative = left
    turn: i32 = 0, // Positive = right, negative = left (in BUILD angle units per tick)
    look: i32 = 0, // Positive = up, negative = down
    is_running: bool = false,
    jump_pressed: bool = false,
    crouch_pressed: bool = false,
};

/// Fixed timestep physics controller
pub const FixedTimestep = struct {
    /// Time accumulator in milliseconds
    accumulator: f32 = 0.0,

    /// Number of ticks processed this frame (for debugging)
    ticks_this_frame: u32 = 0,

    /// Total ticks processed
    total_ticks: u64 = 0,

    /// Current input state (updated by game each frame)
    input: InputState = .{},

    /// Player sprite index
    sprite_idx: usize = 0,

    /// Current posture
    posture_type: posture.PostureType = .stand,

    /// Maximum ticks per frame (to prevent spiral of death)
    const MAX_TICKS_PER_FRAME: u32 = 10;

    /// Input scale for NBlood-compatible movement
    /// After posture accel (mulscale16 with 0x4000) and trig (mulscale30 with ~16383),
    /// input is reduced by ~factor of 4 million. We need large input to compensate.
    /// Velocity is then shifted right by 12 for position update.
    pub const INPUT_MAGNITUDE: i32 = 0x400000; // 4194304 - large to compensate for shifts

    /// Initialize with player sprite index
    pub fn init(sprite_idx: usize) FixedTimestep {
        return .{
            .sprite_idx = sprite_idx,
        };
    }

    /// Update physics with frame delta time
    /// Returns number of ticks processed
    pub fn update(self: *FixedTimestep, delta_ms: f32) u32 {
        self.accumulator += delta_ms;
        self.ticks_this_frame = 0;

        // Process fixed timestep ticks
        while (self.accumulator >= TICK_DURATION_MS and self.ticks_this_frame < MAX_TICKS_PER_FRAME) {
            self.tick();
            self.accumulator -= TICK_DURATION_MS;
            self.ticks_this_frame += 1;
            self.total_ticks += 1;
        }

        // If we hit max ticks, discard remaining time to prevent spiral
        if (self.ticks_this_frame >= MAX_TICKS_PER_FRAME) {
            self.accumulator = 0;
        }

        return self.ticks_this_frame;
    }

    /// Process one physics tick (1/120th second)
    fn tick(self: *FixedTimestep) void {
        const idx = self.sprite_idx;

        // Apply turning (direct angle change, not velocity-based)
        if (self.input.turn != 0) {
            const new_ang = @as(i32, globals.globalang) + self.input.turn;
            globals.globalang = @intCast(new_ang & 2047);
        }

        // Apply look up/down
        if (self.input.look != 0) {
            var horiz = @import("../types.zig").fix16ToInt(globals.globalhoriz);
            horiz = mulscale.clamp(horiz + self.input.look, 1, 199);
            globals.globalhoriz = @import("../types.zig").fix16FromInt(horiz);
        }

        // Process movement input
        processInput(
            idx,
            globals.globalang,
            self.input.forward,
            self.input.strafe,
            self.posture_type,
            self.input.is_running,
        );

        // Apply damping based on posture
        switch (self.posture_type) {
            .stand => applyGroundDamping(idx),
            .swim => applyWaterDamping(idx),
            .crouch => applyGroundDamping(idx),
        }

        // Clamp velocities
        clampVelocity(idx);

        // Apply velocity to position
        applyVelocityToCamera(idx);
    }

    /// Set input from key states (call each frame before update)
    pub fn setInput(
        self: *FixedTimestep,
        forward: bool,
        backward: bool,
        strafe_left: bool,
        strafe_right: bool,
        turn_left: bool,
        turn_right: bool,
        look_up: bool,
        look_down: bool,
        running: bool,
    ) void {
        // Movement input (magnitude per tick)
        self.input.forward = 0;
        if (forward) self.input.forward += INPUT_MAGNITUDE;
        if (backward) self.input.forward -= INPUT_MAGNITUDE;

        self.input.strafe = 0;
        if (strafe_right) self.input.strafe += INPUT_MAGNITUDE;
        if (strafe_left) self.input.strafe -= INPUT_MAGNITUDE;

        // Turn speed: ~4 units per tick = 480 units per second = ~84 degrees/sec
        self.input.turn = 0;
        if (turn_right) self.input.turn += 4;
        if (turn_left) self.input.turn -= 4;

        // Look speed
        self.input.look = 0;
        if (look_up) self.input.look += 1;
        if (look_down) self.input.look -= 1;

        self.input.is_running = running;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "velocity application" {
    // Initialize
    globals.initGlobals();

    const idx: usize = 0;
    globals.xvel[idx] = 4096 << 12; // Should move 4096 units
    globals.yvel[idx] = 2048 << 12; // Should move 2048 units
    globals.zvel[idx] = 1024 << 8; // Should move 1024 units

    applyVelocityToCamera(idx);

    try std.testing.expectEqual(@as(i32, 4096), globals.globalposx);
    try std.testing.expectEqual(@as(i32, 2048), globals.globalposy);
    try std.testing.expectEqual(@as(i32, 1024), globals.globalposz);
}

test "damping reduces velocity" {
    globals.initGlobals();

    const idx: usize = 0;
    globals.xvel[idx] = 65536;
    globals.yvel[idx] = 65536;

    applyGroundDamping(idx);

    // Damping of 0xB000 should reduce velocity
    try std.testing.expect(globals.xvel[idx] < 65536);
    try std.testing.expect(globals.yvel[idx] < 65536);
    try std.testing.expect(globals.xvel[idx] > 0);
}

test "gravity increases zvel" {
    globals.initGlobals();

    const idx: usize = 0;
    globals.zvel[idx] = 0;

    applyGravity(idx);

    try std.testing.expectEqual(GRAVITY, globals.zvel[idx]);

    applyGravity(idx);

    try std.testing.expectEqual(GRAVITY * 2, globals.zvel[idx]);
}

test "jump sets negative zvel" {
    globals.initGlobals();

    const idx: usize = 0;
    globals.zvel[idx] = 0;

    jump(idx, .stand, false);

    try std.testing.expect(globals.zvel[idx] < 0);
}

test "horizontal speed calculation" {
    globals.initGlobals();

    const idx: usize = 0;
    globals.xvel[idx] = 1000;
    globals.yvel[idx] = 0;

    const speed = getHorizontalSpeed(idx);
    try std.testing.expect(speed > 900); // Should be close to 1000
    try std.testing.expect(speed < 1200);
}
