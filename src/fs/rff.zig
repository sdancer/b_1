//! RFF File Loader
//! Port from: NBlood/source/blood/src/resource.cpp
//!
//! Loads Blood RFF (Resource File Format) archives.
//! RFF files contain maps, sounds, and other game resources.

const std = @import("std");
const reader = @import("reader.zig");

const BinaryReader = reader.BinaryReader;

// =============================================================================
// RFF Constants
// =============================================================================

/// RFF signature "RFF\x1a"
pub const RFF_SIGNATURE: u32 = 0x1a464652;

/// Dictionary flags
pub const DICT_CRYPT: u8 = 16;

// =============================================================================
// RFF Structures
// =============================================================================

/// RFF file header (32 bytes)
pub const RFFHeader = struct {
    signature: u32,
    version: u16,
    pad1: u16,
    offset: u32, // Offset to dictionary
    filenum: u32, // Number of files
    pad2: [16]u8,
};

/// RFF dictionary entry (48 bytes as stored in file)
pub const RFFEntry = struct {
    unused1: [16]u8,
    offset: u32,
    size: u32,
    unused2: [8]u8,
    flags: u8,
    entry_type: [3]u8,
    name: [8]u8,
    id: i32,
};

/// Parsed resource entry
pub const ResourceEntry = struct {
    name: [9]u8, // 8 chars + null terminator
    entry_type: [4]u8, // 3 chars + null terminator
    offset: u32,
    size: u32,
    flags: u8,
    id: i32,

    pub fn getName(self: *const ResourceEntry) []const u8 {
        // Find null terminator or return full length
        for (self.name, 0..) |c, i| {
            if (c == 0) return self.name[0..i];
        }
        return self.name[0..8];
    }

    pub fn getType(self: *const ResourceEntry) []const u8 {
        // Find null terminator or return full length
        for (self.entry_type, 0..) |c, i| {
            if (c == 0) return self.entry_type[0..i];
        }
        return self.entry_type[0..3];
    }

    pub fn isEncrypted(self: *const ResourceEntry) bool {
        return (self.flags & DICT_CRYPT) != 0;
    }
};

/// Loaded RFF archive
pub const RFFArchive = struct {
    version: u16,
    entries: []ResourceEntry,
    data: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *RFFArchive) void {
        self.allocator.free(self.entries);
    }

    /// Find an entry by name and type
    pub fn find(self: *const RFFArchive, name: []const u8, entry_type: []const u8) ?*const ResourceEntry {
        for (self.entries) |*entry| {
            if (std.ascii.eqlIgnoreCase(entry.getName(), name) and
                std.ascii.eqlIgnoreCase(entry.getType(), entry_type))
            {
                return entry;
            }
        }
        return null;
    }

    /// Find all entries of a given type
    pub fn findByType(self: *const RFFArchive, entry_type: []const u8, result: []?*const ResourceEntry) usize {
        var count: usize = 0;
        for (self.entries) |*entry| {
            if (std.ascii.eqlIgnoreCase(entry.getType(), entry_type)) {
                if (count < result.len) {
                    result[count] = entry;
                    count += 1;
                }
            }
        }
        return count;
    }

    /// Get raw data for an entry (may be encrypted)
    pub fn getRawData(self: *const RFFArchive, entry: *const ResourceEntry) ?[]const u8 {
        const start = entry.offset;
        const end = start + entry.size;
        if (end > self.data.len) return null;
        return self.data[start..end];
    }

    /// Get decrypted data for an entry
    pub fn getData(self: *const RFFArchive, allocator: std.mem.Allocator, entry: *const ResourceEntry) ![]u8 {
        const raw = self.getRawData(entry) orelse return error.InvalidOffset;

        const result = try allocator.alloc(u8, raw.len);
        @memcpy(result, raw);

        if (entry.isEncrypted()) {
            decrypt(result);
        }

        return result;
    }
};

// =============================================================================
// RFF Loading
// =============================================================================

/// Load an RFF archive
pub fn loadRFF(allocator: std.mem.Allocator, data: []const u8) !RFFArchive {
    if (data.len < 32) return error.FileTooSmall;

    var r = BinaryReader.init(data);

    // Read header
    const sig = try r.readU32LE();
    if (sig != RFF_SIGNATURE) {
        return error.InvalidRFFSignature;
    }

    const version = try r.readU16LE();
    _ = try r.readU16LE(); // pad1
    const dict_offset = try r.readU32LE();
    const filenum = try r.readU32LE();

    // Check if dictionary is encrypted (version 0x03xx)
    const is_encrypted = (version & 0xff00) == 0x0300;

    // Calculate dictionary size
    const dict_size = filenum * 48; // Each entry is 48 bytes

    // Read raw dictionary data
    if (dict_offset + dict_size > data.len) {
        return error.InvalidOffset;
    }

    const dict_data = try allocator.alloc(u8, dict_size);
    defer allocator.free(dict_data);
    @memcpy(dict_data, data[dict_offset .. dict_offset + dict_size]);

    // Decrypt dictionary if needed
    if (is_encrypted) {
        const key: u32 = dict_offset +% (@as(u32, version & 0xff) *% dict_offset);
        cryptData(dict_data, @truncate(key));
    }

    // Parse dictionary entries
    const entries = try allocator.alloc(ResourceEntry, filenum);
    errdefer allocator.free(entries);

    var dr = BinaryReader.init(dict_data);

    for (0..filenum) |i| {
        // Read raw entry (48 bytes)
        try dr.skip(16); // unused1
        const offset = try dr.readU32LE();
        const size = try dr.readU32LE();
        try dr.skip(8); // unused2
        const flags = try dr.readByte();
        var entry_type: [3]u8 = undefined;
        _ = try dr.readBytes(&entry_type);
        var name: [8]u8 = undefined;
        _ = try dr.readBytes(&name);
        const id = try dr.readI32LE();

        entries[i] = .{
            .name = name ++ [1]u8{0},
            .entry_type = entry_type ++ [1]u8{0},
            .offset = offset,
            .size = size,
            .flags = flags,
            .id = id,
        };
    }

    return RFFArchive{
        .version = version,
        .entries = entries,
        .data = data,
        .allocator = allocator,
    };
}

/// Load an RFF archive from file
pub fn loadRFFFromFile(allocator: std.mem.Allocator, path: []const u8) !struct { archive: RFFArchive, data: []u8 } {
    const data = try reader.loadFile(allocator, path);
    errdefer allocator.free(data);

    const archive = try loadRFF(allocator, data);

    return .{ .archive = archive, .data = data };
}

// =============================================================================
// Decryption
// =============================================================================

/// Decrypt data using Blood's Crypt algorithm
/// void Resource::Crypt(void *p, int length, unsigned short key)
/// Each byte is XORed with (key >> 1), and key is incremented after each byte
fn cryptData(data: []u8, initial_key: u16) void {
    var key = initial_key;
    for (data) |*byte| {
        byte.* ^= @truncate(key >> 1);
        key +%= 1;
    }
}

/// Decrypt resource data
/// Blood only encrypts the first 256 bytes with key=0
pub fn decrypt(data: []u8) void {
    const size = @min(data.len, 0x100);
    cryptData(data[0..size], 0);
}

// =============================================================================
// Utility Functions
// =============================================================================

/// List all entries in the archive
pub fn listEntries(archive: *const RFFArchive, writer: anytype) !void {
    try writer.print("RFF Archive v{d} - {d} entries:\n", .{ archive.version, archive.entries.len });
    try writer.print("{s:>8} {s:>4} {s:>10} {s:>10} {s}\n", .{ "Name", "Type", "Offset", "Size", "Flags" });
    try writer.print("{s:-<50}\n", .{""});

    for (archive.entries) |entry| {
        try writer.print("{s:>8} {s:>4} {d:>10} {d:>10} 0x{x:0>2}\n", .{
            entry.getName(),
            entry.getType(),
            entry.offset,
            entry.size,
            entry.flags,
        });
    }
}

// =============================================================================
// Tests
// =============================================================================

test "rff signature" {
    try std.testing.expectEqual(@as(u32, 0x1a464652), RFF_SIGNATURE);
}

test "resource entry size" {
    // ResourceEntry should be compact
    try std.testing.expect(@sizeOf(ResourceEntry) <= 32);
}
