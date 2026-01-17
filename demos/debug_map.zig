//! Debug Map Loading

const std = @import("std");
const build = @import("build_engine");

const fs = build.fs;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <archive.rff> <mapname>\n", .{args[0]});
        return;
    }

    // Load RFF
    const rff_result = fs.rff.loadRFFFromFile(allocator, args[1]) catch |err| {
        std.debug.print("Error loading RFF: {}\n", .{err});
        return;
    };
    defer allocator.free(rff_result.data);
    var archive = rff_result.archive;
    defer archive.deinit();

    // Find map
    const entry = archive.find(args[2], "MAP") orelse {
        std.debug.print("Map not found\n", .{});
        return;
    };

    std.debug.print("Entry: {s}.{s}\n", .{ entry.getName(), entry.getType() });
    std.debug.print("  Offset: {d}\n", .{entry.offset});
    std.debug.print("  Size: {d}\n", .{entry.size});
    std.debug.print("  Flags: 0x{x:0>2}\n", .{entry.flags});
    std.debug.print("  ID: {d}\n", .{entry.id});
    std.debug.print("  Encrypted: {}\n", .{entry.isEncrypted()});

    // Get raw data
    const raw = archive.getRawData(entry) orelse {
        std.debug.print("Invalid offset\n", .{});
        return;
    };

    std.debug.print("\nRaw data (first 32 bytes):\n", .{});
    for (raw[0..@min(32, raw.len)], 0..) |b, i| {
        if (i > 0 and i % 16 == 0) std.debug.print("\n", .{});
        std.debug.print("{x:0>2} ", .{b});
    }
    std.debug.print("\n", .{});

    // Get decrypted data
    const data = archive.getData(allocator, entry) catch |err| {
        std.debug.print("Error getting data: {}\n", .{err});
        return;
    };
    defer allocator.free(data);

    std.debug.print("\nDecrypted data (first 32 bytes):\n", .{});
    for (data[0..@min(32, data.len)], 0..) |b, i| {
        if (i > 0 and i % 16 == 0) std.debug.print("\n", .{});
        std.debug.print("{x:0>2} ", .{b});
    }
    std.debug.print("\n", .{});

    // Check signature
    std.debug.print("\nSignature check:\n", .{});
    const sig = std.mem.readInt(u32, data[0..4], .little);
    std.debug.print("  Signature: 0x{x:0>8}\n", .{sig});
    std.debug.print("  Expected Blood MAP: 0x{x:0>8}\n", .{@as(u32, 0x1a4d4c42)});
    if (sig == 0x1a4d4c42) {
        std.debug.print("  -> Blood MAP format detected!\n", .{});
        const version = std.mem.readInt(u16, data[4..6], .little);
        std.debug.print("  Version: 0x{x:0>4}\n", .{version});

        // Parse Blood header
        var offset: usize = 6;
        const posx = std.mem.readInt(i32, data[offset..][0..4], .little);
        offset += 4;
        const posy = std.mem.readInt(i32, data[offset..][0..4], .little);
        offset += 4;
        const posz = std.mem.readInt(i32, data[offset..][0..4], .little);
        offset += 4;
        const ang = std.mem.readInt(i16, data[offset..][0..2], .little);
        offset += 2;
        const cursectnum = std.mem.readInt(i16, data[offset..][0..2], .little);
        offset += 2;
        const pskybits = std.mem.readInt(i16, data[offset..][0..2], .little);
        offset += 2;
        const visibility = std.mem.readInt(i32, data[offset..][0..4], .little);
        offset += 4;
        const songid = std.mem.readInt(i32, data[offset..][0..4], .little);
        offset += 4;
        const parallaxtype = data[offset];
        offset += 1;
        const maprevision = std.mem.readInt(i32, data[offset..][0..4], .little);
        offset += 4;
        const numsectors = std.mem.readInt(i16, data[offset..][0..2], .little);
        offset += 2;
        const numwalls = std.mem.readInt(i16, data[offset..][0..2], .little);
        offset += 2;
        const numsprites = std.mem.readInt(i16, data[offset..][0..2], .little);
        offset += 2;

        std.debug.print("\nBlood Map Header:\n", .{});
        std.debug.print("  Start pos: ({d}, {d}, {d})\n", .{ posx, posy, posz });
        std.debug.print("  Angle: {d}, Sector: {d}\n", .{ ang, cursectnum });
        std.debug.print("  Pskybits: {d}, Visibility: {d}\n", .{ pskybits, visibility });
        std.debug.print("  Song ID: {d}, Parallax type: {d}\n", .{ songid, parallaxtype });
        std.debug.print("  Map revision: {d}\n", .{maprevision});
        std.debug.print("  Sectors: {d}, Walls: {d}, Sprites: {d}\n", .{ numsectors, numwalls, numsprites });
        std.debug.print("  Header size: {d} bytes\n", .{offset});
    } else {
        // Try as BUILD map
        std.debug.print("  As BUILD version: {d}\n", .{@as(i32, @bitCast(sig))});
    }
}
