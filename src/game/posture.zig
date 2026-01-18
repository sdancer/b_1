//! Blood/NBlood Posture System
//! Port from: NBlood/source/blood/src/player.cpp lines 129-158 (gPostureDefaults)
//!
//! The posture system defines movement characteristics for different
//! player states: standing, swimming, crouching, etc.

const std = @import("std");

// =============================================================================
// Posture Type
// =============================================================================

/// Player posture type
pub const PostureType = enum(u3) {
    stand = 0,
    swim = 1,
    crouch = 2,
};

/// Player life mode (affects posture values)
pub const LifeMode = enum(u2) {
    normal = 0,
    shrink = 1,
    grow = 2,
};

// =============================================================================
// Posture Structure
// =============================================================================

/// Posture parameters matching NBlood's POSTURE struct
pub const Posture = struct {
    /// Eye height above sprite Z (negative = higher)
    eyeAboveZ: i32,
    /// Weapon height relative to eye
    weaponAboveZ: i32,
    /// X offset
    xOffset: i32,
    /// Z offset (additional height adjustment)
    zOffset: i32,
    /// Jump velocity when standing on ground
    normalJumpZ: i32,
    /// Jump velocity with powerup
    pwupJumpZ: i32,
    /// Forward acceleration (higher = faster)
    frontAccel: i32,
    /// Strafe acceleration
    sideAccel: i32,
    /// Backward acceleration
    backAccel: i32,
    /// Footstep timing [normal, sprint]
    pace: [2]i32,
    /// View bob vertical amplitude
    bobV: i32,
    /// View bob horizontal amplitude
    bobH: i32,
    /// Weapon sway vertical amplitude
    swayV: i32,
    /// Weapon sway horizontal amplitude
    swayH: i32,

    /// Create a default posture
    pub fn init() Posture {
        return .{
            .eyeAboveZ = 0,
            .weaponAboveZ = 0,
            .xOffset = 0,
            .zOffset = 0,
            .normalJumpZ = 0,
            .pwupJumpZ = 0,
            .frontAccel = 0x4000,
            .sideAccel = 0x4000,
            .backAccel = 0x4000,
            .pace = .{ 0x4800, 0x3000 },
            .bobV = 0,
            .bobH = 0,
            .swayV = 0,
            .swayH = 0,
        };
    }
};

// =============================================================================
// Default Posture Values
// =============================================================================

/// NBlood defaults from player.cpp gPostureDefaults
/// Array is [LifeMode][PostureType]
pub const defaults: [3][3]Posture = .{
    // Normal life mode (index 0)
    .{
        // Stand (posture 0)
        .{
            .eyeAboveZ = 0x4000, // 16384 - eye height
            .weaponAboveZ = -0x6000, // -24576 - weapon below eye
            .xOffset = 0,
            .zOffset = 0,
            .normalJumpZ = -0xd5c0, // -54720 - normal jump velocity
            .pwupJumpZ = -0x175c0, // -95680 - powerup jump velocity
            .frontAccel = 0x4000, // 16384 - standing forward acceleration
            .sideAccel = 0x4000, // 16384 - standing strafe acceleration
            .backAccel = 0x4000, // 16384 - standing backward acceleration
            .pace = .{ 0x4800, 0x3000 }, // footstep timing
            .bobV = 0xa000, // 40960 - vertical bob
            .bobH = 0x600, // 1536 - horizontal bob
            .swayV = 0x6000, // 24576 - vertical sway
            .swayH = 0x600, // 1536 - horizontal sway
        },
        // Swim (posture 1)
        .{
            .eyeAboveZ = -0x2000, // -8192 - underwater eye adjustment
            .weaponAboveZ = 0x8000, // 32768
            .xOffset = 0,
            .zOffset = 0,
            .normalJumpZ = 0, // no jumping while swimming
            .pwupJumpZ = 0,
            .frontAccel = 0x1200, // 4608 - slower in water
            .sideAccel = 0x1200,
            .backAccel = 0x1200,
            .pace = .{ 0x4800, 0x3000 },
            .bobV = 0xa000,
            .bobH = 0x600,
            .swayV = 0x6000,
            .swayH = 0x600,
        },
        // Crouch (posture 2)
        .{
            .eyeAboveZ = -0x9000, // -36864 - lower eye when crouching
            .weaponAboveZ = -0x3000, // -12288
            .xOffset = 0,
            .zOffset = -0x6000, // -24576 - height offset
            .normalJumpZ = -0xd5c0,
            .pwupJumpZ = -0x175c0,
            .frontAccel = 0x2000, // 8192 - slower when crouching
            .sideAccel = 0x2000,
            .backAccel = 0x2000,
            .pace = .{ 0x5000, 0x3000 },
            .bobV = 0x8000, // 32768
            .bobH = 0x400, // 1024
            .swayV = 0x4000, // 16384
            .swayH = 0x400, // 1024
        },
    },
    // Shrink life mode (index 1) - same as normal for now
    .{
        // Stand
        .{
            .eyeAboveZ = 0x4000,
            .weaponAboveZ = -0x6000,
            .xOffset = 0,
            .zOffset = 0,
            .normalJumpZ = -0xd5c0,
            .pwupJumpZ = -0x175c0,
            .frontAccel = 0x4000,
            .sideAccel = 0x4000,
            .backAccel = 0x4000,
            .pace = .{ 0x4800, 0x3000 },
            .bobV = 0xa000,
            .bobH = 0x600,
            .swayV = 0x6000,
            .swayH = 0x600,
        },
        // Swim
        .{
            .eyeAboveZ = -0x2000,
            .weaponAboveZ = 0x8000,
            .xOffset = 0,
            .zOffset = 0,
            .normalJumpZ = 0,
            .pwupJumpZ = 0,
            .frontAccel = 0x1200,
            .sideAccel = 0x1200,
            .backAccel = 0x1200,
            .pace = .{ 0x4800, 0x3000 },
            .bobV = 0xa000,
            .bobH = 0x600,
            .swayV = 0x6000,
            .swayH = 0x600,
        },
        // Crouch
        .{
            .eyeAboveZ = -0x9000,
            .weaponAboveZ = -0x3000,
            .xOffset = 0,
            .zOffset = -0x6000,
            .normalJumpZ = -0xd5c0,
            .pwupJumpZ = -0x175c0,
            .frontAccel = 0x2000,
            .sideAccel = 0x2000,
            .backAccel = 0x2000,
            .pace = .{ 0x5000, 0x3000 },
            .bobV = 0x8000,
            .bobH = 0x400,
            .swayV = 0x4000,
            .swayH = 0x400,
        },
    },
    // Grow life mode (index 2) - same as normal for now
    .{
        // Stand
        .{
            .eyeAboveZ = 0x4000,
            .weaponAboveZ = -0x6000,
            .xOffset = 0,
            .zOffset = 0,
            .normalJumpZ = -0xd5c0,
            .pwupJumpZ = -0x175c0,
            .frontAccel = 0x4000,
            .sideAccel = 0x4000,
            .backAccel = 0x4000,
            .pace = .{ 0x4800, 0x3000 },
            .bobV = 0xa000,
            .bobH = 0x600,
            .swayV = 0x6000,
            .swayH = 0x600,
        },
        // Swim
        .{
            .eyeAboveZ = -0x2000,
            .weaponAboveZ = 0x8000,
            .xOffset = 0,
            .zOffset = 0,
            .normalJumpZ = 0,
            .pwupJumpZ = 0,
            .frontAccel = 0x1200,
            .sideAccel = 0x1200,
            .backAccel = 0x1200,
            .pace = .{ 0x4800, 0x3000 },
            .bobV = 0xa000,
            .bobH = 0x600,
            .swayV = 0x6000,
            .swayH = 0x600,
        },
        // Crouch
        .{
            .eyeAboveZ = -0x9000,
            .weaponAboveZ = -0x3000,
            .xOffset = 0,
            .zOffset = -0x6000,
            .normalJumpZ = -0xd5c0,
            .pwupJumpZ = -0x175c0,
            .frontAccel = 0x2000,
            .sideAccel = 0x2000,
            .backAccel = 0x2000,
            .pace = .{ 0x5000, 0x3000 },
            .bobV = 0x8000,
            .bobH = 0x400,
            .swayV = 0x4000,
            .swayH = 0x400,
        },
    },
};

/// Get posture for given life mode and posture type
pub fn getPosture(life_mode: LifeMode, posture_type: PostureType) *const Posture {
    return &defaults[@intFromEnum(life_mode)][@intFromEnum(posture_type)];
}

/// Convenience function to get normal standing posture
pub fn getStandingPosture() *const Posture {
    return getPosture(.normal, .stand);
}

/// Convenience function to get swimming posture
pub fn getSwimmingPosture() *const Posture {
    return getPosture(.normal, .swim);
}

/// Convenience function to get crouching posture
pub fn getCrouchingPosture() *const Posture {
    return getPosture(.normal, .crouch);
}

// =============================================================================
// Running Modifier
// =============================================================================

/// Running multiplier for acceleration (approximately 1.375x = 0x5800/0x4000)
pub const RUN_ACCEL_MULTIPLIER: i32 = 0x16000; // 90112 - 1.375 in 16.16 fixed point

/// Diving acceleration (underwater without surface)
pub const DIVE_FRONT_ACCEL: i32 = 0x600; // 1536 - very slow underwater

// =============================================================================
// Tests
// =============================================================================

test "posture defaults" {
    const stand = getStandingPosture();
    try std.testing.expectEqual(@as(i32, 0x4000), stand.frontAccel);
    try std.testing.expectEqual(@as(i32, 0x4000), stand.sideAccel);
    try std.testing.expectEqual(@as(i32, 0x4000), stand.backAccel);

    const swim = getSwimmingPosture();
    try std.testing.expectEqual(@as(i32, 0x1200), swim.frontAccel);

    const crouch = getCrouchingPosture();
    try std.testing.expectEqual(@as(i32, 0x2000), crouch.frontAccel);
}

test "posture type values" {
    try std.testing.expectEqual(@as(u3, 0), @intFromEnum(PostureType.stand));
    try std.testing.expectEqual(@as(u3, 1), @intFromEnum(PostureType.swim));
    try std.testing.expectEqual(@as(u3, 2), @intFromEnum(PostureType.crouch));
}
