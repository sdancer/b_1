//! Binary File Reader
//!
//! Provides utilities for reading binary files with proper endianness handling.
//! Matches the behavior of NBlood's file reading functions.

const std = @import("std");

/// Binary reader for parsing file data
pub const BinaryReader = struct {
    data: []const u8,
    pos: usize,

    pub fn init(data: []const u8) BinaryReader {
        return .{ .data = data, .pos = 0 };
    }

    /// Read a single byte
    pub fn readByte(self: *BinaryReader) !u8 {
        if (self.pos >= self.data.len) return error.EndOfFile;
        const b = self.data[self.pos];
        self.pos += 1;
        return b;
    }

    /// Read a signed byte
    pub fn readI8(self: *BinaryReader) !i8 {
        return @bitCast(try self.readByte());
    }

    /// Read bytes into a buffer
    pub fn readBytes(self: *BinaryReader, buf: []u8) !void {
        if (self.pos + buf.len > self.data.len) return error.EndOfFile;
        @memcpy(buf, self.data[self.pos .. self.pos + buf.len]);
        self.pos += buf.len;
    }

    /// Read a slice of bytes without copying
    pub fn readSlice(self: *BinaryReader, len: usize) ![]const u8 {
        if (self.pos + len > self.data.len) return error.EndOfFile;
        const slice = self.data[self.pos .. self.pos + len];
        self.pos += len;
        return slice;
    }

    /// Read little-endian i16
    pub fn readI16LE(self: *BinaryReader) !i16 {
        if (self.pos + 2 > self.data.len) return error.EndOfFile;
        const val = std.mem.readInt(i16, self.data[self.pos..][0..2], .little);
        self.pos += 2;
        return val;
    }

    /// Read little-endian u16
    pub fn readU16LE(self: *BinaryReader) !u16 {
        if (self.pos + 2 > self.data.len) return error.EndOfFile;
        const val = std.mem.readInt(u16, self.data[self.pos..][0..2], .little);
        self.pos += 2;
        return val;
    }

    /// Read little-endian i32
    pub fn readI32LE(self: *BinaryReader) !i32 {
        if (self.pos + 4 > self.data.len) return error.EndOfFile;
        const val = std.mem.readInt(i32, self.data[self.pos..][0..4], .little);
        self.pos += 4;
        return val;
    }

    /// Read little-endian u32
    pub fn readU32LE(self: *BinaryReader) !u32 {
        if (self.pos + 4 > self.data.len) return error.EndOfFile;
        const val = std.mem.readInt(u32, self.data[self.pos..][0..4], .little);
        self.pos += 4;
        return val;
    }

    /// Skip bytes
    pub fn skip(self: *BinaryReader, count: usize) !void {
        if (self.pos + count > self.data.len) return error.EndOfFile;
        self.pos += count;
    }

    /// Seek to position
    pub fn seek(self: *BinaryReader, pos: usize) !void {
        if (pos > self.data.len) return error.EndOfFile;
        self.pos = pos;
    }

    /// Get current position
    pub fn tell(self: *const BinaryReader) usize {
        return self.pos;
    }

    /// Get remaining bytes
    pub fn remaining(self: *const BinaryReader) usize {
        return self.data.len - self.pos;
    }

    /// Check if at end
    pub fn isEof(self: *const BinaryReader) bool {
        return self.pos >= self.data.len;
    }
};

/// Load a file into memory
pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(data);

    const bytes_read = try file.readAll(data);
    if (bytes_read != stat.size) {
        return error.UnexpectedEof;
    }

    return data;
}

/// Load a file from an absolute path
pub fn loadFileAbsolute(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(data);

    const bytes_read = try file.readAll(data);
    if (bytes_read != stat.size) {
        return error.UnexpectedEof;
    }

    return data;
}

// =============================================================================
// Tests
// =============================================================================

test "binary reader basic" {
    const data = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 };
    var reader = BinaryReader.init(&data);

    try std.testing.expectEqual(@as(u8, 0x01), try reader.readByte());
    try std.testing.expectEqual(@as(usize, 1), reader.tell());

    try std.testing.expectEqual(@as(i16, 0x0302), try reader.readI16LE());
    try std.testing.expectEqual(@as(usize, 3), reader.tell());
}

test "binary reader i32" {
    const data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    var reader = BinaryReader.init(&data);

    try std.testing.expectEqual(@as(i32, 0x12345678), try reader.readI32LE());
}

test "binary reader skip and seek" {
    const data = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 };
    var reader = BinaryReader.init(&data);

    try reader.skip(4);
    try std.testing.expectEqual(@as(usize, 4), reader.tell());

    try reader.seek(2);
    try std.testing.expectEqual(@as(usize, 2), reader.tell());
    try std.testing.expectEqual(@as(u8, 0x03), try reader.readByte());
}
