//! Polymer Lighting System
//! Port from: NBlood/source/build/src/polymer.cpp (lighting functions)
//!
//! Handles dynamic lighting for the polymer renderer including:
//! - Point lights
//! - Spot lights
//! - Shadow mapping
//! - Light culling

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const polymer_types = @import("types.zig");

const PrLight = polymer_types.PrLight;
const PrPlane = polymer_types.PrPlane;

// =============================================================================
// Light Constants
// =============================================================================

/// Maximum lights visible in a single frame
pub const MAX_VISIBLE_LIGHTS = 32;

/// Shadow map resolution
pub const SHADOWMAP_SIZE = 1024;

// =============================================================================
// Light State
// =============================================================================

/// Visible lights for current frame
var visibleLights: [MAX_VISIBLE_LIGHTS]i16 = .{-1} ** MAX_VISIBLE_LIGHTS;
var numVisibleLights: i32 = 0;

/// Shadow map framebuffer
var shadowFBO: u32 = 0;

/// Shadow map texture
var shadowTexture: u32 = 0;

/// Shadow matrices for each shadow-casting light
var shadowMatrices: [polymer_types.PR_MAXSHADOWMAPS][16]f32 = undefined;

// =============================================================================
// Light Visibility
// =============================================================================

/// Update which lights are visible
pub fn updateVisibleLights(viewx: f32, viewy: f32, viewz: f32, viewRadius: f32) void {
    numVisibleLights = 0;

    const render = @import("render.zig");
    if (!render.polymer_inited) return;

    // Check each active light
    // Would iterate through all lights and check visibility
    _ = viewx;
    _ = viewy;
    _ = viewz;
    _ = viewRadius;
}

/// Check if a light affects a plane
pub fn planeinlight(plane: *const PrPlane, light: *const PrLight) bool {
    // Check if the light's sphere intersects the plane's bounding box
    const lightRadius = @as(f32, @floatFromInt(light.range));
    const lightPos = [3]f32{
        @as(f32, @floatFromInt(light.x)) / 16.0,
        @as(f32, @floatFromInt(light.z)) / 256.0,
        @as(f32, @floatFromInt(light.y)) / 16.0,
    };

    // Simple distance check to plane
    const dist = plane.plane[0] * lightPos[0] +
        plane.plane[1] * lightPos[1] +
        plane.plane[2] * lightPos[2] +
        plane.plane[3];

    return @abs(dist) < lightRadius;
}

/// Add a light to a plane's light list
pub fn addplanelight(plane: *PrPlane, lighti: i16) void {
    if (plane.lightcount >= polymer_types.PR_MAXPLANELIGHTS) return;

    plane.lights[plane.lightcount] = lighti;
    plane.lightcount += 1;
}

/// Clear a plane's light list
pub fn clearplanelights(plane: *PrPlane) void {
    plane.lightcount = 0;
}

// =============================================================================
// Spotlight Processing
// =============================================================================

/// Process a spotlight
pub fn processspotlight(light: *PrLight) void {
    if ((light.publicflags & polymer_types.PrLightFlags.SPOTLIGHT) == 0) return;

    // Calculate spotlight direction from angle
    const angf = @as(f32, @floatFromInt(light.angle)) * std.math.pi * 2.0 / 2048.0;
    const horizf = @as(f32, @floatFromInt(light.horiz)) * 0.087890625;

    // Store direction in the light structure
    light.fx = @cos(angf) * @cos(horizf);
    light.fy = @sin(horizf);
    light.fz = @sin(angf) * @cos(horizf);
}

// =============================================================================
// Shadow Mapping
// =============================================================================

/// Prepare shadow maps for all shadow-casting lights
pub fn prepareshadows() void {
    const render = @import("render.zig");
    if (render.pr_shadows == 0) return;

    // Would iterate through lights and render shadow maps
}

/// Render the shadow map for a single light
pub fn rendershadowmap(light: *const PrLight, index: usize) void {
    if (index >= polymer_types.PR_MAXSHADOWMAPS) return;

    // Set up the light's view matrix
    const lightPos = [3]f32{
        @as(f32, @floatFromInt(light.x)) / 16.0,
        @as(f32, @floatFromInt(light.z)) / 256.0,
        @as(f32, @floatFromInt(light.y)) / 16.0,
    };

    // Calculate look-at point based on light direction
    const lookAt = [3]f32{
        lightPos[0] + light.fx,
        lightPos[1] + light.fy,
        lightPos[2] + light.fz,
    };

    // Calculate the projection matrix for the light
    calculateShadowMatrix(index, lightPos, lookAt, light.range);
}

/// Calculate the shadow projection matrix
fn calculateShadowMatrix(index: usize, lightPos: [3]f32, lookAt: [3]f32, range: i16) void {
    _ = lookAt;
    _ = lightPos;

    const frange = @as(f32, @floatFromInt(range));

    // Build orthographic projection for shadow map
    var matrix: [16]f32 = .{0} ** 16;

    // Simple orthographic projection
    matrix[0] = 1.0 / frange;
    matrix[5] = 1.0 / frange;
    matrix[10] = -2.0 / (frange * 2.0);
    matrix[15] = 1.0;

    shadowMatrices[index] = matrix;
}

// =============================================================================
// Light Culling
// =============================================================================

/// Cull a light against the view frustum
pub fn culllight(light: *const PrLight, frustum: *const [24]f32) bool {
    // Check if light's sphere is inside the frustum
    const lightPos = [3]f32{
        @as(f32, @floatFromInt(light.x)) / 16.0,
        @as(f32, @floatFromInt(light.z)) / 256.0,
        @as(f32, @floatFromInt(light.y)) / 16.0,
    };
    const radius = @as(f32, @floatFromInt(light.range));

    // Check against each frustum plane
    for (0..6) |i| {
        const d = frustum[i * 4 + 0] * lightPos[0] +
            frustum[i * 4 + 1] * lightPos[1] +
            frustum[i * 4 + 2] * lightPos[2] +
            frustum[i * 4 + 3];

        if (d < -radius) return false; // Light is outside this plane
    }

    return true; // Light is visible
}

// =============================================================================
// Light Color Calculations
// =============================================================================

/// Calculate attenuated light color at a point
pub fn calculateLightColor(light: *const PrLight, px: f32, py: f32, pz: f32) [3]f32 {
    const lightPos = [3]f32{
        @as(f32, @floatFromInt(light.x)) / 16.0,
        @as(f32, @floatFromInt(light.z)) / 256.0,
        @as(f32, @floatFromInt(light.y)) / 16.0,
    };

    // Calculate distance
    const dx = px - lightPos[0];
    const dy = py - lightPos[1];
    const dz = pz - lightPos[2];
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);

    // Calculate attenuation
    const range = @as(f32, @floatFromInt(light.range));
    if (dist >= range) return .{ 0.0, 0.0, 0.0 };

    const attenuation = 1.0 - (dist / range);

    // Apply attenuation to light color
    return .{
        @as(f32, @floatFromInt(light.color[0])) / 255.0 * attenuation,
        @as(f32, @floatFromInt(light.color[1])) / 255.0 * attenuation,
        @as(f32, @floatFromInt(light.color[2])) / 255.0 * attenuation,
    };
}

/// Calculate spotlight factor
pub fn calculateSpotlightFactor(light: *const PrLight, px: f32, py: f32, pz: f32) f32 {
    if ((light.publicflags & polymer_types.PrLightFlags.SPOTLIGHT) == 0) {
        return 1.0; // Not a spotlight
    }

    const lightPos = [3]f32{
        @as(f32, @floatFromInt(light.x)) / 16.0,
        @as(f32, @floatFromInt(light.z)) / 256.0,
        @as(f32, @floatFromInt(light.y)) / 16.0,
    };

    // Direction from light to point
    const dx = px - lightPos[0];
    const dy = py - lightPos[1];
    const dz = pz - lightPos[2];
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);

    if (dist < 0.001) return 1.0;

    // Normalize direction
    const ndx = dx / dist;
    const ndy = dy / dist;
    const ndz = dz / dist;

    // Dot product with light direction
    const dot = ndx * light.fx + ndy * light.fy + ndz * light.fz;

    // Calculate cone factor
    const innerAngle = @as(f32, @floatFromInt(light.radius)) * std.math.pi / 2048.0;
    const outerAngle = @as(f32, @floatFromInt(light.faderadius)) * std.math.pi / 2048.0;

    const cosInner = @cos(innerAngle);
    const cosOuter = @cos(outerAngle);

    if (dot < cosOuter) return 0.0;
    if (dot > cosInner) return 1.0;

    return (dot - cosOuter) / (cosInner - cosOuter);
}

// =============================================================================
// Tests
// =============================================================================

test "light color calculation" {
    var light = PrLight{
        .x = 0,
        .y = 0,
        .z = 0,
        .range = 100, // Range in BUILD units
        .color = .{ 255, 128, 64 },
    };

    // At center, should get full color
    const colorCenter = calculateLightColor(&light, 0.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), colorCenter[0], 0.01);

    // Way beyond range (distance > range)
    const colorBeyond = calculateLightColor(&light, 200.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), colorBeyond[0], 0.01);

    // Attenuation is linear: at distance 50 with range 100, attenuation = 0.5
    const colorMid = calculateLightColor(&light, 50.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), colorMid[0], 0.01);
}

test "plane in light" {
    var light = PrLight{
        .x = 0,
        .y = 0,
        .z = 0,
        .range = 100,
    };

    // Plane facing up at origin
    var plane = PrPlane{};
    plane.plane = .{ 0.0, 1.0, 0.0, 0.0 };

    try std.testing.expect(planeinlight(&plane, &light));

    // Plane far away
    plane.plane = .{ 0.0, 1.0, 0.0, 1000.0 };
    try std.testing.expect(!planeinlight(&plane, &light));
}
