//! BUILD Engine Fixed-Point Math Functions
//! Port from: NBlood/source/build/src/engine.cpp mulscale functions
//!
//! These functions implement the BUILD engine's fixed-point arithmetic.
//! The pattern is: (a * b) >> shift, done with 64-bit intermediate precision.

const std = @import("std");

// =============================================================================
// Core Mulscale Functions
// =============================================================================

/// mulscale: (a * b) >> shift
/// General purpose fixed-point multiply with variable shift
pub inline fn mulscale(a: i32, b: i32, shift: u5) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> shift);
}

/// mulscale8: (a * b) >> 8
/// Used for Z position updates
pub inline fn mulscale8(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 8);
}

/// mulscale12: (a * b) >> 12
/// Used for X/Y position updates
pub inline fn mulscale12(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 12);
}

/// mulscale14: (a * b) >> 14
pub inline fn mulscale14(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 14);
}

/// mulscale16: (a * b) >> 16
/// Common for fixed-point 16.16 operations
pub inline fn mulscale16(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 16);
}

/// mulscale18: (a * b) >> 18
pub inline fn mulscale18(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 18);
}

/// mulscale24: (a * b) >> 24
pub inline fn mulscale24(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 24);
}

/// mulscale26: (a * b) >> 26
pub inline fn mulscale26(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 26);
}

/// mulscale30: (a * b) >> 30
/// Used for movement physics with trig values
pub inline fn mulscale30(a: i32, b: i32) i32 {
    return @truncate(@as(i64, a) * @as(i64, b) >> 30);
}

// =============================================================================
// Double Mulscale Functions
// =============================================================================

/// dmulscale: ((a * b) + (c * d)) >> shift
/// Double multiply with single shift, used for complex calculations
pub inline fn dmulscale(a: i32, b: i32, c: i32, d: i32, shift: u5) i32 {
    return @truncate((@as(i64, a) * @as(i64, b) + @as(i64, c) * @as(i64, d)) >> shift);
}

/// dmulscale16: ((a * b) + (c * d)) >> 16
pub inline fn dmulscale16(a: i32, b: i32, c: i32, d: i32) i32 {
    return @truncate((@as(i64, a) * @as(i64, b) + @as(i64, c) * @as(i64, d)) >> 16);
}

/// dmulscale30: ((a * b) + (c * d)) >> 30
/// Used for combined forward/strafe movement
pub inline fn dmulscale30(a: i32, b: i32, c: i32, d: i32) i32 {
    return @truncate((@as(i64, a) * @as(i64, b) + @as(i64, c) * @as(i64, d)) >> 30);
}

// =============================================================================
// Division Functions
// =============================================================================

/// divscale: (a << shift) / b
/// Fixed-point division with pre-shift
pub inline fn divscale(a: i32, b: i32, shift: u5) i32 {
    if (b == 0) return 0;
    return @truncate(@divTrunc(@as(i64, a) << shift, @as(i64, b)));
}

/// divscale16: (a << 16) / b
pub inline fn divscale16(a: i32, b: i32) i32 {
    if (b == 0) return 0;
    return @truncate(@divTrunc(@as(i64, a) << 16, @as(i64, b)));
}

/// divscale30: (a << 30) / b
pub inline fn divscale30(a: i32, b: i32) i32 {
    if (b == 0) return 0;
    return @truncate(@divTrunc(@as(i64, a) << 30, @as(i64, b)));
}

// =============================================================================
// Trigonometry Helpers
// =============================================================================

/// ksgn: Returns -1, 0, or 1 based on sign of a
pub inline fn ksgn(a: i32) i32 {
    if (a > 0) return 1;
    if (a < 0) return -1;
    return 0;
}

/// klabs: Absolute value of a
pub inline fn klabs(a: i32) i32 {
    return if (a < 0) -a else a;
}

/// kmin: Minimum of two values
pub inline fn kmin(a: i32, b: i32) i32 {
    return if (a < b) a else b;
}

/// kmax: Maximum of two values
pub inline fn kmax(a: i32, b: i32) i32 {
    return if (a > b) a else b;
}

/// clamp: Clamp value to range [lo, hi]
pub inline fn clamp(val: i32, lo: i32, hi: i32) i32 {
    return kmin(kmax(val, lo), hi);
}

/// clamp2: Clamp value to range [-val2, val2]
pub inline fn clamp2(val: i32, val2: i32) i32 {
    return clamp(val, -val2, val2);
}

// =============================================================================
// Scale Functions (like MulDiv)
// =============================================================================

/// scale: (a * b) / c with 64-bit intermediate
pub inline fn scale(a: i32, b: i32, c: i32) i32 {
    if (c == 0) return 0;
    return @truncate(@divTrunc(@as(i64, a) * @as(i64, b), @as(i64, c)));
}

// =============================================================================
// Tests
// =============================================================================

test "mulscale30 basic" {
    // mulscale30(16384, 16384) = (16384 * 16384) >> 30 = 268435456 >> 30 = 0.25 = 0
    // With BUILD engine values (sintable max = 16383):
    // mulscale30(move, cos) where cos ~= 16383 gives move >> ~16
    try std.testing.expectEqual(@as(i32, 0), mulscale30(1, 1));
    try std.testing.expectEqual(@as(i32, 0), mulscale30(16383, 16383)); // ~0.25

    // Larger values
    try std.testing.expectEqual(@as(i32, 1), mulscale30(1 << 15, 1 << 15)); // 0.5 * 0.5 = 0.25 ~= 1
}

test "mulscale16 basic" {
    // mulscale16(65536, 65536) = 65536 (1.0 * 1.0 = 1.0 in 16.16 fixed point)
    try std.testing.expectEqual(@as(i32, 65536), mulscale16(65536, 65536));
    try std.testing.expectEqual(@as(i32, 32768), mulscale16(65536, 32768)); // 1.0 * 0.5 = 0.5
}

test "mulscale12 for position updates" {
    // Position update: x += xvel >> 12
    // mulscale12(velocity, 4096) should give velocity
    try std.testing.expectEqual(@as(i32, 1000), mulscale12(1000, 4096));
}

test "dmulscale30 for combined movement" {
    // dmulscale30(forward, cos, strafe, sin) for combined velocity
    // With larger input values to get meaningful results after >> 30
    const forward: i32 = 0x10000; // 65536 - typical input scale
    const strafe: i32 = 0;
    const cos_val: i32 = 16383; // ~1.0 (max sin/cos value)
    const sin_val: i32 = 0; // 0.0

    // forward * cos + strafe * sin = 65536 * 16383 + 0
    // = 1073676288 >> 30 = 0 (still small)
    const result = dmulscale30(forward, cos_val, strafe, sin_val);
    // Result is (65536 * 16383) >> 30 = ~0.999 in fixed point, rounds to 0-1
    try std.testing.expect(result >= 0);
    try std.testing.expect(result < 2);

    // With posture acceleration applied (0x4000 = 16384)
    // mulscale16(forward, 0x4000) = 65536 * 16384 >> 16 = 16384
    // dmulscale30(16384, 16383, 0, 0) = (16384 * 16383) >> 30 = ~0.25
    const scaled_forward = mulscale16(forward, 0x4000);
    const result2 = dmulscale30(scaled_forward, cos_val, 0, sin_val);
    try std.testing.expect(result2 >= 0);
}

test "scale function" {
    // scale(100, 50, 25) = (100 * 50) / 25 = 200
    try std.testing.expectEqual(@as(i32, 200), scale(100, 50, 25));
}

test "clamp function" {
    try std.testing.expectEqual(@as(i32, 50), clamp(50, 0, 100));
    try std.testing.expectEqual(@as(i32, 0), clamp(-10, 0, 100));
    try std.testing.expectEqual(@as(i32, 100), clamp(150, 0, 100));
}
