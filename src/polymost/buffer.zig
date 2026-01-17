//! Polymost Buffer Management
//! Port from: NBlood/source/build/src/polymost.cpp (buffer functions)
//!
//! Handles vertex buffer management, streaming vertices, and
//! buffered drawing for the polymost renderer.

const std = @import("std");
const types = @import("../types.zig");
const constants = @import("../constants.zig");
const globals = @import("../globals.zig");
const gl_state = @import("../gl/state.zig");
const gl = @import("../gl/bindings.zig");
const polymost_types = @import("types.zig");

// =============================================================================
// Buffer Constants
// =============================================================================

/// Maximum vertices per buffer
const MAX_BUFFER_VERTS = 65536;

/// Number of VBOs in the pool
const VBO_COUNT = 64;

/// Vertex size in bytes
const VERTEX_SIZE = @sizeOf(polymost_types.PolymostVertex);

// =============================================================================
// Buffer State
// =============================================================================

/// Vertex buffer for streaming
var vertexBuffer: [MAX_BUFFER_VERTS]polymost_types.PolymostVertex = undefined;

/// Current vertex count in buffer
var vertexCount: usize = 0;

/// VBO pool
var vboPool: [VBO_COUNT]u32 = .{0} ** VBO_COUNT;

/// Current VBO index
var currentVboIndex: usize = 0;

/// Currently bound VBO
var boundVbo: u32 = 0;

/// Buffer initialized flag
var buffersInitialized: bool = false;

// =============================================================================
// Initialization
// =============================================================================

/// Initialize buffer management
pub fn initBuffers() void {
    if (buffersInitialized) return;

    // Generate VBOs
    gl.glGenBuffers(VBO_COUNT, &vboPool);

    // Initialize each VBO with empty data
    for (vboPool) |vbo| {
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            MAX_BUFFER_VERTS * VERTEX_SIZE,
            null,
            gl.GL_STREAM_DRAW,
        );
    }

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    buffersInitialized = true;
}

/// Cleanup buffer management
pub fn cleanupBuffers() void {
    if (!buffersInitialized) return;

    gl.glDeleteBuffers(VBO_COUNT, &vboPool);
    buffersInitialized = false;
}

// =============================================================================
// Buffered Drawing
// =============================================================================

/// Start buffered drawing mode
/// nn: expected number of vertices (for optimization)
pub fn polymost_startBufferedDrawing(nn: i32) void {
    _ = nn;
    vertexCount = 0;
}

/// Add a vertex to the buffer
pub fn polymost_bufferVert(v: types.Vec3f, t: types.Vec2f) void {
    if (vertexCount >= MAX_BUFFER_VERTS) {
        // Buffer full, need to flush
        polymost_finishBufferedDrawing(gl.GL_TRIANGLES);
        vertexCount = 0;
    }

    vertexBuffer[vertexCount] = .{
        .x = v.x,
        .y = v.y,
        .z = v.z,
        .u = t.x,
        .v = t.y,
    };
    vertexCount += 1;
}

/// Add a vertex with explicit coordinates
pub fn polymost_bufferVertXYZUV(x: f32, y: f32, z: f32, u: f32, v: f32) void {
    polymost_bufferVert(.{ .x = x, .y = y, .z = z }, .{ .x = u, .y = v });
}

/// Finish buffered drawing and render
pub fn polymost_finishBufferedDrawing(mode: u32) void {
    if (vertexCount == 0) return;

    if (buffersInitialized) {
        // Use VBO for rendering
        const vbo = vboPool[currentVboIndex];
        currentVboIndex = (currentVboIndex + 1) % VBO_COUNT;

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);

        // Upload vertex data
        gl.glBufferSubData(
            gl.GL_ARRAY_BUFFER,
            0,
            @intCast(vertexCount * VERTEX_SIZE),
            @ptrCast(&vertexBuffer),
        );

        // Set up vertex pointers
        gl.glEnableClientState(gl.GL_VERTEX_ARRAY);
        gl.glEnableClientState(gl.GL_TEXTURE_COORD_ARRAY);

        gl.glVertexPointer(3, gl.GL_FLOAT, VERTEX_SIZE, @ptrFromInt(0));
        gl.glTexCoordPointer(2, gl.GL_FLOAT, VERTEX_SIZE, @ptrFromInt(12));

        // Draw
        gl.glDrawArrays(mode, 0, @intCast(vertexCount));

        // Clean up
        gl.glDisableClientState(gl.GL_TEXTURE_COORD_ARRAY);
        gl.glDisableClientState(gl.GL_VERTEX_ARRAY);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    } else {
        // Fallback to immediate mode
        gl.glBegin(mode);
        for (0..vertexCount) |i| {
            const vert = &vertexBuffer[i];
            gl.glTexCoord2f(vert.u, vert.v);
            gl.glVertex3f(vert.x, vert.y, vert.z);
        }
        gl.glEnd();
    }

    vertexCount = 0;
}

// =============================================================================
// Quad Drawing Helpers
// =============================================================================

/// Buffer a quad (4 vertices as 2 triangles)
pub fn polymost_bufferQuad(
    v0: types.Vec3f,
    v1: types.Vec3f,
    v2: types.Vec3f,
    v3: types.Vec3f,
    t0: types.Vec2f,
    t1: types.Vec2f,
    t2: types.Vec2f,
    t3: types.Vec2f,
) void {
    // First triangle: v0, v1, v2
    polymost_bufferVert(v0, t0);
    polymost_bufferVert(v1, t1);
    polymost_bufferVert(v2, t2);

    // Second triangle: v0, v2, v3
    polymost_bufferVert(v0, t0);
    polymost_bufferVert(v2, t2);
    polymost_bufferVert(v3, t3);
}

/// Draw an immediate quad (not buffered)
pub fn drawQuadImmediate(
    x0: f32,
    y0: f32,
    z0: f32,
    x1: f32,
    y1: f32,
    z1: f32,
    tex_u0: f32,
    tex_v0: f32,
    tex_u1: f32,
    tex_v1: f32,
) void {
    gl.glBegin(gl.GL_QUADS);

    gl.glTexCoord2f(tex_u0, tex_v0);
    gl.glVertex3f(x0, y0, z0);

    gl.glTexCoord2f(tex_u1, tex_v0);
    gl.glVertex3f(x1, y0, z1);

    gl.glTexCoord2f(tex_u1, tex_v1);
    gl.glVertex3f(x1, y1, z1);

    gl.glTexCoord2f(tex_u0, tex_v1);
    gl.glVertex3f(x0, y1, z0);

    gl.glEnd();
}

// =============================================================================
// Index Buffer
// =============================================================================

/// Index buffer for indexed drawing
var indexBuffer: [MAX_BUFFER_VERTS * 6 / 4]u16 = undefined;
var indexCount: usize = 0;

/// Add indices for a quad (using current vertex count)
pub fn addQuadIndices() void {
    if (indexCount + 6 > indexBuffer.len) return;

    const baseVertex: u16 = @intCast(vertexCount);

    // Triangle 1: 0, 1, 2
    indexBuffer[indexCount] = baseVertex;
    indexBuffer[indexCount + 1] = baseVertex + 1;
    indexBuffer[indexCount + 2] = baseVertex + 2;

    // Triangle 2: 0, 2, 3
    indexBuffer[indexCount + 3] = baseVertex;
    indexBuffer[indexCount + 4] = baseVertex + 2;
    indexBuffer[indexCount + 5] = baseVertex + 3;

    indexCount += 6;
}

/// Reset index buffer
pub fn resetIndexBuffer() void {
    indexCount = 0;
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Get current vertex count
pub fn getVertexCount() usize {
    return vertexCount;
}

/// Check if buffers are initialized
pub fn areBuffersInitialized() bool {
    return buffersInitialized;
}

/// Get the vertex buffer for direct access
pub fn getVertexBuffer() []polymost_types.PolymostVertex {
    return &vertexBuffer;
}

// =============================================================================
// Tests
// =============================================================================

test "vertex buffering" {
    polymost_startBufferedDrawing(10);
    try std.testing.expectEqual(@as(usize, 0), getVertexCount());

    polymost_bufferVertXYZUV(0.0, 0.0, 0.0, 0.0, 0.0);
    try std.testing.expectEqual(@as(usize, 1), getVertexCount());

    polymost_bufferVertXYZUV(1.0, 0.0, 0.0, 1.0, 0.0);
    try std.testing.expectEqual(@as(usize, 2), getVertexCount());

    polymost_bufferVertXYZUV(1.0, 1.0, 0.0, 1.0, 1.0);
    try std.testing.expectEqual(@as(usize, 3), getVertexCount());

    // Check vertex data
    const buffer = getVertexBuffer();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), buffer[0].x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), buffer[1].x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), buffer[2].y, 0.01);
}

test "quad indices" {
    resetIndexBuffer();
    addQuadIndices();

    try std.testing.expectEqual(@as(usize, 6), indexCount);
}
