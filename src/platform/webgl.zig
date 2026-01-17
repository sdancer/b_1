//! WebGL Bindings for WASM
//! These functions are imported from JavaScript and provide WebGL 1.0 functionality.

const std = @import("std");

// =============================================================================
// Type Definitions (matching OpenGL types)
// =============================================================================

pub const GLuint = u32;
pub const GLint = i32;
pub const GLsizei = i32;
pub const GLenum = u32;
pub const GLfloat = f32;
pub const GLboolean = u8;
pub const GLubyte = u8;
pub const GLbitfield = u32;
pub const GLclampf = f32;

// =============================================================================
// WebGL Functions (imported from JavaScript)
// =============================================================================

// These are provided by the JavaScript host
pub extern "webgl" fn glClear(mask: GLbitfield) void;
pub extern "webgl" fn glClearColor(r: GLclampf, g: GLclampf, b: GLclampf, a: GLclampf) void;
pub extern "webgl" fn glClearDepth(depth: GLclampf) void;
pub extern "webgl" fn glEnable(cap: GLenum) void;
pub extern "webgl" fn glDisable(cap: GLenum) void;
pub extern "webgl" fn glDepthFunc(func: GLenum) void;
pub extern "webgl" fn glDepthMask(flag: GLboolean) void;
pub extern "webgl" fn glBlendFunc(sfactor: GLenum, dfactor: GLenum) void;
pub extern "webgl" fn glCullFace(mode: GLenum) void;
pub extern "webgl" fn glFrontFace(mode: GLenum) void;
pub extern "webgl" fn glViewport(x: GLint, y: GLint, width: GLsizei, height: GLsizei) void;

// Matrix operations (we'll implement these in software since WebGL doesn't have fixed pipeline)
pub extern "webgl" fn glLoadIdentity() void;
pub extern "webgl" fn glMatrixMode(mode: GLenum) void;
pub extern "webgl" fn glLoadMatrixf(m: [*]const GLfloat) void;
pub extern "webgl" fn glRotatef(angle: GLfloat, x: GLfloat, y: GLfloat, z: GLfloat) void;
pub extern "webgl" fn glTranslatef(x: GLfloat, y: GLfloat, z: GLfloat) void;

// Immediate mode rendering (emulated in JS)
pub extern "webgl" fn glBegin(mode: GLenum) void;
pub extern "webgl" fn glEnd() void;
pub extern "webgl" fn glVertex3f(x: GLfloat, y: GLfloat, z: GLfloat) void;
pub extern "webgl" fn glColor3f(r: GLfloat, g: GLfloat, b: GLfloat) void;
pub extern "webgl" fn glColor4f(r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat) void;

// =============================================================================
// GL Constants
// =============================================================================

// Capabilities
pub const GL_DEPTH_TEST: GLenum = 0x0B71;
pub const GL_BLEND: GLenum = 0x0BE2;
pub const GL_CULL_FACE: GLenum = 0x0B44;
pub const GL_TEXTURE_2D: GLenum = 0x0DE1;

// Depth functions
pub const GL_LEQUAL: GLenum = 0x0203;
pub const GL_LESS: GLenum = 0x0201;

// Cull face
pub const GL_BACK: GLenum = 0x0405;
pub const GL_FRONT: GLenum = 0x0404;
pub const GL_CCW: GLenum = 0x0901;
pub const GL_CW: GLenum = 0x0900;

// Blend factors
pub const GL_SRC_ALPHA: GLenum = 0x0302;
pub const GL_ONE_MINUS_SRC_ALPHA: GLenum = 0x0303;

// Clear bits
pub const GL_COLOR_BUFFER_BIT: GLbitfield = 0x00004000;
pub const GL_DEPTH_BUFFER_BIT: GLbitfield = 0x00000100;

// Matrix modes
pub const GL_MODELVIEW: GLenum = 0x1700;
pub const GL_PROJECTION: GLenum = 0x1701;

// Primitive types
pub const GL_POINTS: GLenum = 0x0000;
pub const GL_LINES: GLenum = 0x0001;
pub const GL_LINE_LOOP: GLenum = 0x0002;
pub const GL_TRIANGLES: GLenum = 0x0004;
pub const GL_TRIANGLE_FAN: GLenum = 0x0006;
pub const GL_QUADS: GLenum = 0x0007; // Emulated as triangles

// Boolean
pub const GL_TRUE: GLboolean = 1;
pub const GL_FALSE: GLboolean = 0;
