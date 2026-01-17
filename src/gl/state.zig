//! OpenGL State Management Layer
//! Port from: NBlood/source/build/include/glbuild.h, src/glbuild.cpp
//!
//! This module provides state tracking to minimize redundant GL calls
//! and provides a consistent interface for the rendering engine.

const std = @import("std");
const c = @import("bindings.zig");
const constants = @import("../constants.zig");
const enums = @import("../enums.zig");
const types = @import("../types.zig");

// =============================================================================
// GL Types (matching OpenGL types)
// =============================================================================

pub const GLuint = c_uint;
pub const GLint = c_int;
pub const GLsizei = c_int;
pub const GLenum = c_uint;
pub const GLfloat = f32;
pub const GLboolean = u8;
pub const GLubyte = u8;

// =============================================================================
// GL Constants
// =============================================================================

pub const GL_TEXTURE0: GLenum = 0x84C0;
pub const GL_TEXTURE1: GLenum = 0x84C1;
pub const GL_TEXTURE2: GLenum = 0x84C2;
pub const GL_TEXTURE3: GLenum = 0x84C3;
pub const GL_TEXTURE4: GLenum = 0x84C4;
pub const GL_TEXTURE5: GLenum = 0x84C5;
pub const GL_TEXTURE6: GLenum = 0x84C6;
pub const GL_TEXTURE7: GLenum = 0x84C7;
pub const GL_TEXTURE15: GLenum = 0x84CF;
pub const GL_TEXTURE16: GLenum = 0x84D0;

pub const GL_TEXTURE_2D: GLenum = 0x0DE1;
pub const GL_ARRAY_BUFFER: GLenum = 0x8892;
pub const GL_ELEMENT_ARRAY_BUFFER: GLenum = 0x8893;

pub const GL_FRONT: GLenum = 0x0404;
pub const GL_BACK: GLenum = 0x0405;

pub const GL_DEPTH_TEST: GLenum = 0x0B71;
pub const GL_BLEND: GLenum = 0x0BE2;
pub const GL_CULL_FACE: GLenum = 0x0B44;
pub const GL_ALPHA_TEST: GLenum = 0x0BC0;
pub const GL_POLYGON_OFFSET_FILL: GLenum = 0x8037;
pub const GL_FOG: GLenum = 0x0B60;
pub const GL_TEXTURE_GEN_S: GLenum = 0x0C60;
pub const GL_TEXTURE_GEN_T: GLenum = 0x0C61;

pub const GL_NEVER: GLenum = 0x0200;
pub const GL_LESS: GLenum = 0x0201;
pub const GL_EQUAL: GLenum = 0x0202;
pub const GL_LEQUAL: GLenum = 0x0203;
pub const GL_GREATER: GLenum = 0x0204;
pub const GL_NOTEQUAL: GLenum = 0x0205;
pub const GL_GEQUAL: GLenum = 0x0206;
pub const GL_ALWAYS: GLenum = 0x0207;

// =============================================================================
// Build GL State Structure
// =============================================================================

pub const BuildGLState = struct {
    currentShaderProgramID: GLuint = 0,
    currentActiveTexture: GLenum = GL_TEXTURE0,
    currentBoundSampler: [constants.MAXTEXUNIT]enums.SamplerType = [_]enums.SamplerType{.none} ** constants.MAXTEXUNIT,

    // Viewport
    x: GLint = 0,
    y: GLint = 0,
    width: GLsizei = 0,
    height: GLsizei = 0,

    // Bound textures per unit (simplified tracking)
    boundTextures: [constants.MAXTEXUNIT]GLuint = [_]GLuint{0} ** constants.MAXTEXUNIT,

    // Bound buffers
    boundArrayBuffer: GLuint = 0,
    boundElementBuffer: GLuint = 0,

    // State flags
    fullReset: bool = false,

    // Enabled states
    depthTestEnabled: bool = false,
    blendEnabled: bool = false,
    cullFaceEnabled: bool = false,
    alphaTestEnabled: bool = false,

    // Depth function
    depthFunc: GLenum = GL_LESS,

    // Alpha function
    alphaFunc: GLenum = GL_ALWAYS,
    alphaRef: GLfloat = 0.0,
};

/// Global GL state tracker
pub var gl: BuildGLState = .{};

/// Sampler object IDs
pub var samplerObjectIDs: [constants.NUM_SAMPLERS]GLuint = [_]GLuint{0} ** constants.NUM_SAMPLERS;

/// Whether sampler objects are available and enabled
pub var r_usesamplerobjects: i32 = 1;

// =============================================================================
// State Management Functions
// =============================================================================

/// Set the active texture unit
pub fn activeTexture(texture: GLenum) void {
    if (gl.currentActiveTexture != texture) {
        gl.currentActiveTexture = texture;
        c.glActiveTexture(texture);
    }
}

/// Bind a buffer to a target
pub fn bindBuffer(target: GLenum, bufferID: GLuint) void {
    switch (target) {
        GL_ARRAY_BUFFER => {
            if (gl.boundArrayBuffer != bufferID) {
                gl.boundArrayBuffer = bufferID;
                c.glBindBuffer(target, bufferID);
            }
        },
        GL_ELEMENT_ARRAY_BUFFER => {
            if (gl.boundElementBuffer != bufferID) {
                gl.boundElementBuffer = bufferID;
                c.glBindBuffer(target, bufferID);
            }
        },
        else => {
            c.glBindBuffer(target, bufferID);
        },
    }
}

/// Bind a sampler object to a texture unit
pub fn bindSamplerObject(texunit: i32, pth_method: i32) void {
    if (!samplerObjectsEnabled()) return;

    const unit_index = @as(usize, @intCast(texunit));
    if (unit_index >= constants.MAXTEXUNIT) return;

    const sampler_type = @as(enums.SamplerType, @enumFromInt(pth_method));
    if (gl.currentBoundSampler[unit_index] != sampler_type) {
        gl.currentBoundSampler[unit_index] = sampler_type;
        const sampler_id = if (pth_method >= 0 and pth_method < constants.NUM_SAMPLERS)
            samplerObjectIDs[@intCast(pth_method)]
        else
            0;
        c.glBindSampler(@intCast(texunit), sampler_id);
    }
}

/// Bind a texture to the current texture unit
pub fn bindTexture(target: GLenum, textureID: GLuint) void {
    const unit_index = texunitIndexFromName(gl.currentActiveTexture);
    if (unit_index < constants.MAXTEXUNIT) {
        if (gl.boundTextures[unit_index] != textureID) {
            gl.boundTextures[unit_index] = textureID;
            c.glBindTexture(target, textureID);
        }
    } else {
        c.glBindTexture(target, textureID);
    }
}

/// Use a shader program
pub fn useShaderProgram(shaderID: GLuint) void {
    if (gl.currentShaderProgramID != shaderID) {
        gl.currentShaderProgramID = shaderID;
        c.glUseProgram(shaderID);
    }
}

/// Set the viewport
pub fn setViewport(x: GLint, y: GLint, width: GLsizei, height: GLsizei) void {
    if (gl.x != x or gl.y != y or gl.width != width or gl.height != height) {
        gl.x = x;
        gl.y = y;
        gl.width = width;
        gl.height = height;
        c.glViewport(x, y, width, height);
    }
}

/// Set up a perspective projection matrix
pub fn setPerspective(fovy: f32, aspect: f32, zNear: f32, zFar: f32) void {
    const f = 1.0 / @tan(fovy * 0.5);
    const nf = 1.0 / (zNear - zFar);

    var matrix: [16]f32 = [_]f32{0} ** 16;
    matrix[0] = f / aspect;
    matrix[5] = f;
    matrix[10] = (zFar + zNear) * nf;
    matrix[11] = -1.0;
    matrix[14] = 2.0 * zFar * zNear * nf;

    c.glLoadMatrixf(&matrix);
}

/// Enable a GL capability
pub fn setEnabled(key: GLenum) void {
    switch (key) {
        GL_DEPTH_TEST => {
            if (!gl.depthTestEnabled) {
                gl.depthTestEnabled = true;
                c.glEnable(key);
            }
        },
        GL_BLEND => {
            if (!gl.blendEnabled) {
                gl.blendEnabled = true;
                c.glEnable(key);
            }
        },
        GL_CULL_FACE => {
            if (!gl.cullFaceEnabled) {
                gl.cullFaceEnabled = true;
                c.glEnable(key);
            }
        },
        GL_ALPHA_TEST => {
            if (!gl.alphaTestEnabled) {
                gl.alphaTestEnabled = true;
                c.glEnable(key);
            }
        },
        else => {
            c.glEnable(key);
        },
    }
}

/// Disable a GL capability
pub fn setDisabled(key: GLenum) void {
    switch (key) {
        GL_DEPTH_TEST => {
            if (gl.depthTestEnabled) {
                gl.depthTestEnabled = false;
                c.glDisable(key);
            }
        },
        GL_BLEND => {
            if (gl.blendEnabled) {
                gl.blendEnabled = false;
                c.glDisable(key);
            }
        },
        GL_CULL_FACE => {
            if (gl.cullFaceEnabled) {
                gl.cullFaceEnabled = false;
                c.glDisable(key);
            }
        },
        GL_ALPHA_TEST => {
            if (gl.alphaTestEnabled) {
                gl.alphaTestEnabled = false;
                c.glDisable(key);
            }
        },
        else => {
            c.glDisable(key);
        },
    }
}

/// Set the depth comparison function
pub fn setDepthFunc(func: GLenum) void {
    if (gl.depthFunc != func) {
        gl.depthFunc = func;
        c.glDepthFunc(func);
    }
}

/// Set the alpha test function
pub fn setAlphaFunc(func: GLenum, ref: GLfloat) void {
    if (gl.alphaFunc != func or gl.alphaRef != ref) {
        gl.alphaFunc = func;
        gl.alphaRef = ref;
        c.glAlphaFunc(func, ref);
    }
}

/// Reset all state accounting (call after context switch)
pub fn resetStateAccounting() void {
    gl = .{};
    gl.fullReset = true;
}

/// Reset sampler objects
pub fn resetSamplerObjects() void {
    for (&gl.currentBoundSampler) |*s| {
        s.* = .none;
    }
}

/// Set up a look-at view matrix
pub fn lookAt(eye: types.Vec3f, center: types.Vec3f, up: types.Vec3f) void {
    var f: [3]GLfloat = .{
        center.x - eye.x,
        center.y - eye.y,
        center.z - eye.z,
    };
    normalize(&f);

    var u: [3]GLfloat = .{ up.x, up.y, up.z };
    normalize(&u);

    var s: [3]GLfloat = undefined;
    crossProduct(&f, &u, &s);
    normalize(&s);

    crossProduct(&s, &f, &u);

    const matrix: [16]GLfloat = .{
        s[0],  u[0],  -f[0], 0.0,
        s[1],  u[1],  -f[1], 0.0,
        s[2],  u[2],  -f[2], 0.0,
        -dot3(&s, &.{ eye.x, eye.y, eye.z }),
        -dot3(&u, &.{ eye.x, eye.y, eye.z }),
        dot3(&f, &.{ eye.x, eye.y, eye.z }),
        1.0,
    };

    c.glLoadMatrixf(&matrix);
}

// =============================================================================
// Math Utilities
// =============================================================================

/// Cross product of two 3D vectors
pub fn crossProduct(a: *const [3]GLfloat, b: *const [3]GLfloat, out: *[3]GLfloat) void {
    out[0] = a[1] * b[2] - a[2] * b[1];
    out[1] = a[2] * b[0] - a[0] * b[2];
    out[2] = a[0] * b[1] - a[1] * b[0];
}

/// Normalize a 3D vector in place
pub fn normalize(vec: *[3]GLfloat) void {
    const norm_sq = vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2];
    if (norm_sq > 0.0) {
        const inv_norm = 1.0 / @sqrt(norm_sq);
        vec[0] *= inv_norm;
        vec[1] *= inv_norm;
        vec[2] *= inv_norm;
    }
}

/// Dot product of two 3D vectors
pub fn dot3(a: *const [3]GLfloat, b: *const [3]GLfloat) GLfloat {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

/// Multiply two 4x4 matrices
pub fn multiplyMatrix4f(m0: *[16]f32, m1: *const [16]f32) *[16]f32 {
    var result: [16]f32 = undefined;

    for (0..4) |i| {
        for (0..4) |j| {
            var sum: f32 = 0.0;
            for (0..4) |k| {
                sum += m0[i * 4 + k] * m1[k * 4 + j];
            }
            result[i * 4 + j] = sum;
        }
    }

    m0.* = result;
    return m0;
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Convert texture unit name to index
pub inline fn texunitIndexFromName(name: GLenum) usize {
    return @as(usize, name - GL_TEXTURE0);
}

/// Check if sampler objects are enabled
pub inline fn samplerObjectsEnabled() bool {
    return r_usesamplerobjects != 0;
}

// =============================================================================
// Tests
// =============================================================================

test "texunit index conversion" {
    try std.testing.expectEqual(@as(usize, 0), texunitIndexFromName(GL_TEXTURE0));
    try std.testing.expectEqual(@as(usize, 1), texunitIndexFromName(GL_TEXTURE1));
    try std.testing.expectEqual(@as(usize, 15), texunitIndexFromName(GL_TEXTURE15));
}

test "vector normalize" {
    var v: [3]GLfloat = .{ 3.0, 0.0, 4.0 };
    normalize(&v);
    try std.testing.expectApproxEqAbs(@as(GLfloat, 0.6), v[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(GLfloat, 0.0), v[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(GLfloat, 0.8), v[2], 0.001);
}

test "cross product" {
    const a: [3]GLfloat = .{ 1.0, 0.0, 0.0 };
    const b: [3]GLfloat = .{ 0.0, 1.0, 0.0 };
    var result: [3]GLfloat = undefined;
    crossProduct(&a, &b, &result);
    try std.testing.expectApproxEqAbs(@as(GLfloat, 0.0), result[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(GLfloat, 0.0), result[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(GLfloat, 1.0), result[2], 0.001);
}
