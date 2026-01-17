//! RFF Archive Lister
//! Lists all entries in an RFF archive for debugging

const std = @import("std");
const build = @import("build_engine");

const fs = build.fs;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <archive.rff>\n", .{args[0]});
        return;
    }

    const rff_path = args[1];
    std.debug.print("Loading RFF archive: {s}\n\n", .{rff_path});

    // Load RFF
    const rff_result = fs.rff.loadRFFFromFile(allocator, rff_path) catch |err| {
        std.debug.print("Error loading RFF: {}\n", .{err});
        return;
    };
    defer allocator.free(rff_result.data);
    var archive = rff_result.archive;
    defer archive.deinit();

    std.debug.print("Version: {d}\n", .{archive.version});
    std.debug.print("Entries: {d}\n\n", .{archive.entries.len});

    std.debug.print("{s:>12} {s:>4} {s:>10} {s:>10} {s:>5}\n", .{ "Name", "Type", "Offset", "Size", "Flags" });
    std.debug.print("{s:-<50}\n", .{""});

    // Count types manually
    var map_count: usize = 0;
    var seq_count: usize = 0;
    var sfx_count: usize = 0;
    var qav_count: usize = 0;
    var other_count: usize = 0;

    for (archive.entries, 0..) |entry, i| {
        const entry_type = entry.getType();

        // Always show MAP files
        if (std.ascii.eqlIgnoreCase(entry_type, "MAP")) {
            std.debug.print("{s:>12} {s:>4} {d:>10} {d:>10} 0x{x:0>2}\n", .{
                entry.getName(),
                entry.getType(),
                entry.offset,
                entry.size,
                entry.flags,
            });
            map_count += 1;
        } else if (i < 30) {
            std.debug.print("{s:>12} {s:>4} {d:>10} {d:>10} 0x{x:0>2}\n", .{
                entry.getName(),
                entry.getType(),
                entry.offset,
                entry.size,
                entry.flags,
            });
        } else if (i == 30) {
            std.debug.print("... (more entries) ...\n", .{});
        }

        // Count types
        if (std.ascii.eqlIgnoreCase(entry_type, "SEQ")) {
            seq_count += 1;
        } else if (std.ascii.eqlIgnoreCase(entry_type, "SFX")) {
            sfx_count += 1;
        } else if (std.ascii.eqlIgnoreCase(entry_type, "QAV")) {
            qav_count += 1;
        } else if (!std.ascii.eqlIgnoreCase(entry_type, "MAP")) {
            other_count += 1;
        }
    }

    std.debug.print("\n=== Type Summary ===\n", .{});
    std.debug.print("  MAP: {d} files\n", .{map_count});
    std.debug.print("  SEQ: {d} files\n", .{seq_count});
    std.debug.print("  SFX: {d} files\n", .{sfx_count});
    std.debug.print("  QAV: {d} files\n", .{qav_count});
    std.debug.print("  Other: {d} files\n", .{other_count});
}
