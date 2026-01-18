//! MAP Viewer Demo
//!
//! Loads a BUILD engine MAP file and renders a top-down view to a BMP image.
//! This demonstrates the MAP loader functionality.
//!
//! Usage: mapview <mapfile.map> [output.bmp]
//!        mapview --rff <archive.rff> <mapname> [output.bmp]

const std = @import("std");
const build = @import("build_engine");

const fs = build.fs;
const globals = build.globals;
const constants = build.constants;

// =============================================================================
// Image Buffer
// =============================================================================

const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }
};

const Image = struct {
    width: usize,
    height: usize,
    pixels: []Color,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Image {
        const pixels = try allocator.alloc(Color, width * height);
        @memset(pixels, Color.rgb(0, 0, 0));
        return .{
            .width = width,
            .height = height,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.pixels);
    }

    pub fn setPixel(self: *Image, x: i32, y: i32, color: Color) void {
        if (x < 0 or y < 0) return;
        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);
        if (ux >= self.width or uy >= self.height) return;
        self.pixels[uy * self.width + ux] = color;
    }

    pub fn drawLine(self: *Image, x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
        // Bresenham's line algorithm
        var xx0 = x0;
        var yy0 = y0;
        const dx = @as(i32, @intCast(@abs(x1 - x0)));
        const dy = @as(i32, @intCast(@abs(y1 - y0)));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err = dx - dy;

        while (true) {
            self.setPixel(xx0, yy0, color);
            if (xx0 == x1 and yy0 == y1) break;
            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                xx0 += sx;
            }
            if (e2 < dx) {
                err += dx;
                yy0 += sy;
            }
        }
    }

    pub fn writeBMP(self: *const Image, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        var writer = file.writer(&buf);
        const w_iface = &writer.interface;

        const w: u32 = @intCast(self.width);
        const h: u32 = @intCast(self.height);

        // BMP row padding (rows must be multiple of 4 bytes)
        const row_size = self.width * 3;
        const padding = (4 - (row_size % 4)) % 4;
        const padded_row_size = row_size + padding;

        const pixel_data_size: u32 = @intCast(padded_row_size * self.height);
        const file_size: u32 = 54 + pixel_data_size;

        // BMP File Header (14 bytes)
        try w_iface.writeAll("BM"); // Signature
        try w_iface.writeInt(u32, file_size, .little); // File size
        try w_iface.writeInt(u16, 0, .little); // Reserved
        try w_iface.writeInt(u16, 0, .little); // Reserved
        try w_iface.writeInt(u32, 54, .little); // Pixel data offset

        // DIB Header (BITMAPINFOHEADER - 40 bytes)
        try w_iface.writeInt(u32, 40, .little); // Header size
        try w_iface.writeInt(i32, @intCast(w), .little); // Width
        try w_iface.writeInt(i32, @intCast(h), .little); // Height (positive = bottom-up)
        try w_iface.writeInt(u16, 1, .little); // Color planes
        try w_iface.writeInt(u16, 24, .little); // Bits per pixel
        try w_iface.writeInt(u32, 0, .little); // Compression (none)
        try w_iface.writeInt(u32, pixel_data_size, .little); // Image size
        try w_iface.writeInt(i32, 2835, .little); // X pixels per meter
        try w_iface.writeInt(i32, 2835, .little); // Y pixels per meter
        try w_iface.writeInt(u32, 0, .little); // Colors in color table
        try w_iface.writeInt(u32, 0, .little); // Important colors

        // Pixel data (bottom-up, BGR format)
        const pad_bytes = [_]u8{0} ** 3;
        var y: usize = self.height;
        while (y > 0) {
            y -= 1;
            for (0..self.width) |x| {
                const pixel = self.pixels[y * self.width + x];
                // BMP uses BGR order
                try w_iface.writeByte(pixel.b);
                try w_iface.writeByte(pixel.g);
                try w_iface.writeByte(pixel.r);
            }
            if (padding > 0) {
                try w_iface.writeAll(pad_bytes[0..padding]);
            }
        }
        try w_iface.flush();
    }
};

// =============================================================================
// Map Rendering
// =============================================================================

fn worldToScreen(wx: i32, wy: i32, bounds: anytype, img_width: usize, img_height: usize, margin: i32) struct { x: i32, y: i32 } {
    const map_width = bounds.maxx - bounds.minx;
    const map_height = bounds.maxy - bounds.miny;

    if (map_width == 0 or map_height == 0) {
        return .{ .x = 0, .y = 0 };
    }

    const img_w: i32 = @intCast(img_width);
    const img_h: i32 = @intCast(img_height);
    const usable_w = img_w - 2 * margin;
    const usable_h = img_h - 2 * margin;

    // Calculate scale to fit map in image
    const scale_x: f64 = @as(f64, @floatFromInt(usable_w)) / @as(f64, @floatFromInt(map_width));
    const scale_y: f64 = @as(f64, @floatFromInt(usable_h)) / @as(f64, @floatFromInt(map_height));
    const scale = @min(scale_x, scale_y);

    // Transform coordinates
    const rel_x = wx - bounds.minx;
    const rel_y = wy - bounds.miny;

    const screen_x: i32 = margin + @as(i32, @intFromFloat(@as(f64, @floatFromInt(rel_x)) * scale));
    const screen_y: i32 = margin + @as(i32, @intFromFloat(@as(f64, @floatFromInt(rel_y)) * scale));

    // Flip Y coordinate (BUILD uses Y-down in world space for 2D maps)
    return .{
        .x = screen_x,
        .y = img_h - 1 - screen_y,
    };
}

fn renderMap(img: *Image, map_data: *const fs.map.MapData) void {
    const bounds = fs.map.getMapBounds();
    const margin: i32 = 20;

    // Wall colors based on properties
    const color_normal = Color.rgb(200, 200, 200);
    const color_masked = Color.rgb(100, 100, 255);
    const color_red = Color.rgb(255, 100, 100);

    // Draw all walls
    const numwalls: usize = @intCast(map_data.numwalls);
    for (0..numwalls) |i| {
        const wall = &globals.wall[i];
        const point2: usize = @intCast(wall.point2);

        if (point2 >= numwalls) continue;

        const wall2 = &globals.wall[point2];

        const p1 = worldToScreen(wall.x, wall.y, bounds, img.width, img.height, margin);
        const p2 = worldToScreen(wall2.x, wall2.y, bounds, img.width, img.height, margin);

        // Choose color based on wall properties
        var color = color_normal;
        if (wall.nextsector >= 0) {
            // Portal wall (connects to another sector)
            color = color_masked;
        }
        if ((wall.cstat & 1) != 0) {
            // Blocking wall
            color = color_red;
        }

        img.drawLine(p1.x, p1.y, p2.x, p2.y, color);
    }

    // Draw sprites as small crosses
    const sprite_color = Color.rgb(255, 255, 0);
    const numsprites: usize = @intCast(map_data.numsprites);
    for (0..numsprites) |i| {
        const spr = &globals.sprite[i];
        const pos = worldToScreen(spr.x, spr.y, bounds, img.width, img.height, margin);

        // Draw small cross
        img.drawLine(pos.x - 2, pos.y, pos.x + 2, pos.y, sprite_color);
        img.drawLine(pos.x, pos.y - 2, pos.x, pos.y + 2, sprite_color);
    }

    // Draw player start position
    const start_color = Color.rgb(0, 255, 0);
    const start_pos = worldToScreen(map_data.startx, map_data.starty, bounds, img.width, img.height, margin);

    // Draw larger marker for player start
    img.drawLine(start_pos.x - 5, start_pos.y - 5, start_pos.x + 5, start_pos.y + 5, start_color);
    img.drawLine(start_pos.x - 5, start_pos.y + 5, start_pos.x + 5, start_pos.y - 5, start_color);
    img.drawLine(start_pos.x - 5, start_pos.y, start_pos.x + 5, start_pos.y, start_color);
    img.drawLine(start_pos.x, start_pos.y - 5, start_pos.x, start_pos.y + 5, start_color);
}

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
        std.debug.print("Usage: {s} <mapfile.map> [output.bmp]\n", .{args[0]});
        std.debug.print("       {s} --rff <archive.rff> <mapname> [output.bmp]\n", .{args[0]});
        std.debug.print("\nLoads a BUILD engine MAP file and renders a top-down view.\n", .{});
        std.debug.print("Supports both Blood (.MAP) and standard BUILD formats.\n", .{});
        std.debug.print("\nExamples:\n", .{});
        std.debug.print("  {s} level.map output.bmp\n", .{args[0]});
        std.debug.print("  {s} --rff blood.rff E1M1 e1m1.bmp\n", .{args[0]});
        std.debug.print("  {s} --rff blood.rff --list  (list all maps in archive)\n", .{args[0]});
        return;
    }

    // Initialize the build engine globals
    build.init();

    var map_data: fs.map.MapData = undefined;
    var output_path: []const u8 = "mapview.bmp";
    var rff_data: ?[]u8 = null;
    defer if (rff_data) |d| allocator.free(d);
    var extracted_map: ?[]u8 = null;
    defer if (extracted_map) |m| allocator.free(m);

    // Check for --rff mode
    if (std.mem.eql(u8, args[1], "--rff")) {
        if (args.len < 3) {
            std.debug.print("Error: --rff requires an archive path\n", .{});
            return;
        }

        const rff_path = args[2];
        std.debug.print("Loading RFF archive: {s}\n", .{rff_path});

        // Load RFF
        const rff_result = fs.rff.loadRFFFromFile(allocator, rff_path) catch |err| {
            std.debug.print("Error loading RFF: {}\n", .{err});
            return;
        };
        rff_data = rff_result.data;
        var archive = rff_result.archive;
        defer archive.deinit();

        // Check for --list option
        if (args.len >= 4 and std.mem.eql(u8, args[3], "--list")) {
            std.debug.print("\nMAP files in archive:\n", .{});
            std.debug.print("{s:-<40}\n", .{""});
            var count: usize = 0;
            for (archive.entries) |entry| {
                if (std.ascii.eqlIgnoreCase(entry.getType(), "MAP")) {
                    std.debug.print("  {s}.MAP ({d} bytes)\n", .{ entry.getName(), entry.size });
                    count += 1;
                }
            }
            std.debug.print("\nTotal: {d} maps\n", .{count});
            return;
        }

        if (args.len < 4) {
            std.debug.print("Error: --rff requires a map name (use --list to see available maps)\n", .{});
            return;
        }

        const map_name = args[3];
        if (args.len > 4) output_path = args[4];

        // Find the map
        const entry = archive.find(map_name, "MAP") orelse {
            std.debug.print("Error: Map '{s}' not found in archive\n", .{map_name});
            std.debug.print("Use --list to see available maps\n", .{});
            return;
        };

        std.debug.print("Found map: {s}.MAP ({d} bytes, encrypted={any})\n", .{
            entry.getName(),
            entry.size,
            entry.isEncrypted(),
        });

        // Extract map data
        extracted_map = archive.getData(allocator, entry) catch |err| {
            std.debug.print("Error extracting map: {}\n", .{err});
            return;
        };

        // Load the map from extracted data
        map_data = build.loadMap(allocator, extracted_map.?) catch |err| {
            std.debug.print("Error parsing map: {}\n", .{err});
            return;
        };
    } else {
        // Direct file loading
        const map_path = args[1];
        if (args.len > 2) output_path = args[2];

        std.debug.print("Loading map: {s}\n", .{map_path});

        // Load the map
        map_data = build.loadMapFromFile(allocator, map_path) catch |err| {
            std.debug.print("Error loading map: {}\n", .{err});
            return;
        };
    }
    defer map_data.deinit();

    // Print map information
    std.debug.print("\n=== Map Information ===\n", .{});
    std.debug.print("Sectors: {}\n", .{map_data.numsectors});
    std.debug.print("Walls: {}\n", .{map_data.numwalls});
    std.debug.print("Sprites: {}\n", .{map_data.numsprites});
    std.debug.print("Start position: ({}, {}, {})\n", .{ map_data.startx, map_data.starty, map_data.startz });
    std.debug.print("Start angle: {}\n", .{map_data.startang});
    std.debug.print("Start sector: {}\n", .{map_data.startsect});

    // Get map bounds
    const bounds = fs.map.getMapBounds();
    std.debug.print("\nMap bounds:\n", .{});
    std.debug.print("  X: {} to {}\n", .{ bounds.minx, bounds.maxx });
    std.debug.print("  Y: {} to {}\n", .{ bounds.miny, bounds.maxy });

    // Create image and render
    const img_size: usize = 1024;
    var img = try Image.init(allocator, img_size, img_size);
    defer img.deinit();

    std.debug.print("\nRendering map to {s}...\n", .{output_path});
    renderMap(&img, &map_data);

    // Save image
    try img.writeBMP(output_path);
    std.debug.print("Done! Output written to {s}\n", .{output_path});
    std.debug.print("\nLegend:\n", .{});
    std.debug.print("  White lines: Normal walls\n", .{});
    std.debug.print("  Blue lines: Portal walls (sector connections)\n", .{});
    std.debug.print("  Red lines: Blocking walls\n", .{});
    std.debug.print("  Yellow crosses: Sprites\n", .{});
    std.debug.print("  Green X: Player start position\n", .{});
}
