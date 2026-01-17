//! Player/Camera State
//! Manages camera position and movement in the BUILD engine coordinate system.
//!
//! BUILD Engine Coordinate System:
//! - X: East (positive) / West (negative)
//! - Y: North (positive) / South (negative)
//! - Z: Height (NEGATIVE = higher, POSITIVE = lower - inverted!)
//! - Angles: 0-2047 where 0=East, 512=North, 1024=West, 1536=South

const std = @import("std");
const globals = @import("../globals.zig");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const input = @import("../platform/input.zig");

// =============================================================================
// Player State
// =============================================================================

pub const Player = struct {
    // Position in BUILD units
    x: i32,
    y: i32,
    z: i32, // Height (negative = higher)

    // Orientation
    ang: i16, // 0-2047 (0=east, 512=north, 1024=west, 1536=south)
    horiz: i32, // Look up/down (-100 to +100 or so, 100 = level)

    // Current sector
    sectnum: i16,

    // Movement speeds (BUILD units per second)
    move_speed: i32 = 2048,
    turn_speed: i32 = 512, // Angle units per second
    look_speed: i32 = 256,
    vertical_speed: i32 = 4096,

    /// Create player at map start position
    pub fn initFromMap(map_data: anytype) Player {
        return Player{
            .x = map_data.startx,
            .y = map_data.starty,
            .z = map_data.startz,
            .ang = map_data.startang,
            .horiz = 100, // Level view
            .sectnum = map_data.startsect,
        };
    }

    /// Create player at specific position
    pub fn init(x: i32, y: i32, z: i32, ang: i16, sectnum: i16) Player {
        return Player{
            .x = x,
            .y = y,
            .z = z,
            .ang = ang,
            .horiz = 100,
            .sectnum = sectnum,
        };
    }

    /// Update player based on input
    pub fn update(self: *Player, inp: *const input.Input, dt: f32) void {
        // Speed modifier (shift = faster)
        const speed_mult: f32 = if (inp.speed_modifier) 3.0 else 1.0;

        // Calculate movement based on angle
        const ang_rad = @as(f32, @floatFromInt(self.ang)) * std.math.pi * 2.0 / 2048.0;
        const cos_ang = @cos(ang_rad);
        const sin_ang = @sin(ang_rad);

        // Forward/backward movement
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

        // Strafe movement (perpendicular to facing direction)
        if (inp.strafe_right) {
            dx += sin_ang;
            dy -= cos_ang;
        }
        if (inp.strafe_left) {
            dx -= sin_ang;
            dy += cos_ang;
        }

        // Normalize diagonal movement
        const len = @sqrt(dx * dx + dy * dy);
        if (len > 0.001) {
            dx /= len;
            dy /= len;
        }

        // Apply movement speed
        const move_amount = @as(f32, @floatFromInt(self.move_speed)) * dt * speed_mult;
        self.x += @intFromFloat(dx * move_amount);
        self.y += @intFromFloat(dy * move_amount);

        // Vertical movement (negative Z = higher in BUILD)
        const vert_amount = @as(f32, @floatFromInt(self.vertical_speed)) * dt * speed_mult;
        if (inp.move_up) {
            self.z -= @intFromFloat(vert_amount);
        }
        if (inp.move_down) {
            self.z += @intFromFloat(vert_amount);
        }

        // Keyboard turning
        const turn_amount = @as(f32, @floatFromInt(self.turn_speed)) * dt * speed_mult;
        if (inp.turn_left) {
            self.ang += @intFromFloat(turn_amount);
        }
        if (inp.turn_right) {
            self.ang -= @intFromFloat(turn_amount);
        }

        // Mouse turning (if captured)
        if (inp.mouse_dx != 0) {
            const mouse_sensitivity: f32 = 0.5;
            self.ang -= @intFromFloat(@as(f32, @floatFromInt(inp.mouse_dx)) * mouse_sensitivity);
        }

        // Wrap angle to 0-2047
        self.ang = @mod(self.ang, 2048);
        if (self.ang < 0) self.ang += 2048;

        // Look up/down (keyboard)
        const look_amount = @as(f32, @floatFromInt(self.look_speed)) * dt * speed_mult;
        if (inp.look_up) {
            self.horiz += @intFromFloat(look_amount);
        }
        if (inp.look_down) {
            self.horiz -= @intFromFloat(look_amount);
        }

        // Mouse look (if captured)
        if (inp.mouse_dy != 0) {
            const mouse_sensitivity: f32 = 0.3;
            self.horiz -= @intFromFloat(@as(f32, @floatFromInt(inp.mouse_dy)) * mouse_sensitivity);
        }

        // Clamp horiz
        self.horiz = std.math.clamp(self.horiz, -200, 300);

        // Update current sector
        self.updateSector();
    }

    /// Find which sector the player is in
    pub fn updateSector(self: *Player) void {
        // First check if we're still in the current sector
        if (self.sectnum >= 0 and self.sectnum < globals.numsectors) {
            if (isPointInSector(self.x, self.y, self.sectnum)) {
                return; // Still in same sector
            }

            // Check neighboring sectors through walls
            const sec = &globals.sector[@intCast(self.sectnum)];
            const startwall: usize = @intCast(sec.wallptr);
            const endwall = startwall + @as(usize, @intCast(sec.wallnum));

            for (startwall..endwall) |i| {
                const wall = &globals.wall[i];
                if (wall.nextsector >= 0 and wall.nextsector < globals.numsectors) {
                    if (isPointInSector(self.x, self.y, wall.nextsector)) {
                        self.sectnum = wall.nextsector;
                        return;
                    }
                }
            }
        }

        // Full search if not found in neighbors
        for (0..@as(usize, @intCast(globals.numsectors))) |i| {
            if (isPointInSector(self.x, self.y, @intCast(i))) {
                self.sectnum = @intCast(i);
                return;
            }
        }

        // Not found - keep current sector
    }

    /// Apply player position to global rendering state
    pub fn applyToGlobals(self: *const Player) void {
        globals.globalposx = self.x;
        globals.globalposy = self.y;
        globals.globalposz = self.z;
        globals.globalang = self.ang;
        globals.globalhoriz = types.fix16FromInt(self.horiz);
        globals.globalcursectnum = self.sectnum;
    }
};

// =============================================================================
// Sector Point-In-Polygon Test
// =============================================================================

/// Check if a point is inside a sector using ray casting
pub fn isPointInSector(x: i32, y: i32, sectnum: i16) bool {
    if (sectnum < 0 or sectnum >= globals.numsectors) return false;

    const sec = &globals.sector[@intCast(sectnum)];
    const startwall: usize = @intCast(sec.wallptr);
    const wallcount: usize = @intCast(sec.wallnum);

    if (wallcount < 3) return false;

    // Ray casting algorithm
    var inside = false;
    var j = wallcount - 1;

    for (0..wallcount) |i| {
        const wall_i = &globals.wall[startwall + i];
        const wall_j = &globals.wall[startwall + j];

        const xi = wall_i.x;
        const yi = wall_i.y;
        const xj = wall_j.x;
        const yj = wall_j.y;

        // Check if the ray from (x, y) going right crosses this edge
        if (((yi > y) != (yj > y)) and
            (x < @divTrunc((xj - xi) * (y - yi), (yj - yi)) + xi))
        {
            inside = !inside;
        }

        j = i;
    }

    return inside;
}

// =============================================================================
// Global Position Variables (needed by polymost)
// =============================================================================

// These need to be added to globals.zig - for now we define them here
// and the render code will use Player.applyToGlobals()

// =============================================================================
// Tests
// =============================================================================

test "player init" {
    const player = Player.init(1000, 2000, -5000, 512, 0);
    try std.testing.expectEqual(@as(i32, 1000), player.x);
    try std.testing.expectEqual(@as(i32, 2000), player.y);
    try std.testing.expectEqual(@as(i16, 512), player.ang);
}

test "angle wrapping" {
    var player = Player.init(0, 0, 0, 2040, 0);

    // Create input that turns left
    var inp = input.Input{};
    inp.turn_left = true;

    // After update with enough time, angle should wrap
    player.update(&inp, 0.1);
    try std.testing.expect(player.ang >= 0);
    try std.testing.expect(player.ang < 2048);
}
