//! OpenGL C Bindings
//! This module provides the C function declarations for OpenGL.
//! These are linked at runtime via the system GL library.

// =============================================================================
// Type Definitions
// =============================================================================

pub const GLuint = c_uint;
pub const GLint = c_int;
pub const GLsizei = c_int;
pub const GLenum = c_uint;
pub const GLfloat = f32;
pub const GLboolean = u8;
pub const GLubyte = u8;
pub const GLbitfield = c_uint;
pub const GLclampf = f32;
pub const GLdouble = f64;
pub const GLvoid = anyopaque;
pub const GLchar = u8;
pub const GLsizeiptr = isize;
pub const GLintptr = isize;

// =============================================================================
// OpenGL Function Declarations
// =============================================================================

pub extern fn glActiveTexture(texture: GLenum) void;
pub extern fn glAlphaFunc(func: GLenum, ref: GLfloat) void;
pub extern fn glBindBuffer(target: GLenum, buffer: GLuint) void;
pub extern fn glBindSampler(unit: GLuint, sampler: GLuint) void;
pub extern fn glBindTexture(target: GLenum, texture: GLuint) void;
pub extern fn glBindVertexArray(array: GLuint) void;
pub extern fn glBlendFunc(sfactor: GLenum, dfactor: GLenum) void;
pub extern fn glBufferData(target: GLenum, size: GLsizeiptr, data: ?*const GLvoid, usage: GLenum) void;
pub extern fn glBufferSubData(target: GLenum, offset: GLintptr, size: GLsizeiptr, data: ?*const GLvoid) void;
pub extern fn glClear(mask: GLbitfield) void;
pub extern fn glClearColor(red: GLclampf, green: GLclampf, blue: GLclampf, alpha: GLclampf) void;
pub extern fn glClearDepth(depth: GLdouble) void;
pub extern fn glColorMask(red: GLboolean, green: GLboolean, blue: GLboolean, alpha: GLboolean) void;
pub extern fn glCompileShader(shader: GLuint) void;
pub extern fn glCreateProgram() GLuint;
pub extern fn glCreateShader(shaderType: GLenum) GLuint;
pub extern fn glCullFace(mode: GLenum) void;
pub extern fn glDeleteBuffers(n: GLsizei, buffers: [*]const GLuint) void;
pub extern fn glDeleteProgram(program: GLuint) void;
pub extern fn glDeleteSamplers(count: GLsizei, samplers: [*]const GLuint) void;
pub extern fn glDeleteShader(shader: GLuint) void;
pub extern fn glDeleteTextures(n: GLsizei, textures: [*]const GLuint) void;
pub extern fn glDeleteVertexArrays(n: GLsizei, arrays: [*]const GLuint) void;
pub extern fn glDepthFunc(func: GLenum) void;
pub extern fn glDepthMask(flag: GLboolean) void;
pub extern fn glDisable(cap: GLenum) void;
pub extern fn glDisableVertexAttribArray(index: GLuint) void;
pub extern fn glDrawArrays(mode: GLenum, first: GLint, count: GLsizei) void;
pub extern fn glDrawElements(mode: GLenum, count: GLsizei, @"type": GLenum, indices: ?*const GLvoid) void;
pub extern fn glEnable(cap: GLenum) void;
pub extern fn glEnableVertexAttribArray(index: GLuint) void;
pub extern fn glFinish() void;
pub extern fn glFlush() void;
pub extern fn glFrontFace(mode: GLenum) void;
pub extern fn glGenBuffers(n: GLsizei, buffers: [*]GLuint) void;
pub extern fn glGenSamplers(count: GLsizei, samplers: [*]GLuint) void;
pub extern fn glGenTextures(n: GLsizei, textures: [*]GLuint) void;
pub extern fn glGenVertexArrays(n: GLsizei, arrays: [*]GLuint) void;
pub extern fn glGetAttribLocation(program: GLuint, name: [*:0]const GLchar) GLint;
pub extern fn glGetError() GLenum;
pub extern fn glGetIntegerv(pname: GLenum, params: [*]GLint) void;
pub extern fn glGetProgramInfoLog(program: GLuint, maxLength: GLsizei, length: ?*GLsizei, infoLog: [*]GLchar) void;
pub extern fn glGetProgramiv(program: GLuint, pname: GLenum, params: [*]GLint) void;
pub extern fn glGetShaderInfoLog(shader: GLuint, maxLength: GLsizei, length: ?*GLsizei, infoLog: [*]GLchar) void;
pub extern fn glGetShaderiv(shader: GLuint, pname: GLenum, params: [*]GLint) void;
pub extern fn glGetString(name: GLenum) ?[*:0]const GLubyte;
pub extern fn glGetUniformLocation(program: GLuint, name: [*:0]const GLchar) GLint;
pub extern fn glLinkProgram(program: GLuint) void;
pub extern fn glLoadIdentity() void;
pub extern fn glLoadMatrixf(m: *const [16]GLfloat) void;
pub extern fn glMatrixMode(mode: GLenum) void;
pub extern fn glPixelStorei(pname: GLenum, param: GLint) void;
pub extern fn glPolygonOffset(factor: GLfloat, units: GLfloat) void;
pub extern fn glReadPixels(x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, data: ?*GLvoid) void;
pub extern fn glSamplerParameteri(sampler: GLuint, pname: GLenum, param: GLint) void;
pub extern fn glScissor(x: GLint, y: GLint, width: GLsizei, height: GLsizei) void;
pub extern fn glShaderSource(shader: GLuint, count: GLsizei, string: [*]const [*:0]const GLchar, length: ?[*]const GLint) void;
pub extern fn glTexImage2D(target: GLenum, level: GLint, internalFormat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, @"type": GLenum, data: ?*const GLvoid) void;
pub extern fn glTexParameterf(target: GLenum, pname: GLenum, param: GLfloat) void;
pub extern fn glTexParameteri(target: GLenum, pname: GLenum, param: GLint) void;
pub extern fn glTexSubImage2D(target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, data: ?*const GLvoid) void;
pub extern fn glUniform1f(location: GLint, v0: GLfloat) void;
pub extern fn glUniform1i(location: GLint, v0: GLint) void;
pub extern fn glUniform2f(location: GLint, v0: GLfloat, v1: GLfloat) void;
pub extern fn glUniform2fv(location: GLint, count: GLsizei, value: [*]const GLfloat) void;
pub extern fn glUniform3f(location: GLint, v0: GLfloat, v1: GLfloat, v2: GLfloat) void;
pub extern fn glUniform3fv(location: GLint, count: GLsizei, value: [*]const GLfloat) void;
pub extern fn glUniform4f(location: GLint, v0: GLfloat, v1: GLfloat, v2: GLfloat, v3: GLfloat) void;
pub extern fn glUniform4fv(location: GLint, count: GLsizei, value: [*]const GLfloat) void;
pub extern fn glUniformMatrix4fv(location: GLint, count: GLsizei, transpose: GLboolean, value: [*]const GLfloat) void;
pub extern fn glUseProgram(program: GLuint) void;
pub extern fn glValidateProgram(program: GLuint) void;
pub extern fn glVertexAttribPointer(index: GLuint, size: GLint, @"type": GLenum, normalized: GLboolean, stride: GLsizei, pointer: ?*const GLvoid) void;
pub extern fn glViewport(x: GLint, y: GLint, width: GLsizei, height: GLsizei) void;

// Legacy OpenGL functions (for compatibility with BUILD engine)
pub extern fn glBegin(mode: GLenum) void;
pub extern fn glEnd() void;
pub extern fn glVertex2f(x: GLfloat, y: GLfloat) void;
pub extern fn glVertex3f(x: GLfloat, y: GLfloat, z: GLfloat) void;
pub extern fn glTexCoord2f(s: GLfloat, t: GLfloat) void;
pub extern fn glColor3f(red: GLfloat, green: GLfloat, blue: GLfloat) void;
pub extern fn glColor4f(red: GLfloat, green: GLfloat, blue: GLfloat, alpha: GLfloat) void;
pub extern fn glColor4ub(red: GLubyte, green: GLubyte, blue: GLubyte, alpha: GLubyte) void;
pub extern fn glNormal3f(nx: GLfloat, ny: GLfloat, nz: GLfloat) void;
pub extern fn glPushMatrix() void;
pub extern fn glPopMatrix() void;
pub extern fn glTranslatef(x: GLfloat, y: GLfloat, z: GLfloat) void;
pub extern fn glRotatef(angle: GLfloat, x: GLfloat, y: GLfloat, z: GLfloat) void;
pub extern fn glScalef(x: GLfloat, y: GLfloat, z: GLfloat) void;
pub extern fn glMultMatrixf(m: *const [16]GLfloat) void;
pub extern fn glOrtho(left: GLdouble, right: GLdouble, bottom: GLdouble, top: GLdouble, nearVal: GLdouble, farVal: GLdouble) void;
pub extern fn glFrustum(left: GLdouble, right: GLdouble, bottom: GLdouble, top: GLdouble, nearVal: GLdouble, farVal: GLdouble) void;
pub extern fn glFogf(pname: GLenum, param: GLfloat) void;
pub extern fn glFogfv(pname: GLenum, params: [*]const GLfloat) void;
pub extern fn glFogi(pname: GLenum, param: GLint) void;
pub extern fn glTexEnvf(target: GLenum, pname: GLenum, param: GLfloat) void;
pub extern fn glTexEnvi(target: GLenum, pname: GLenum, param: GLint) void;
pub extern fn glEnableClientState(cap: GLenum) void;
pub extern fn glDisableClientState(cap: GLenum) void;
pub extern fn glVertexPointer(size: GLint, @"type": GLenum, stride: GLsizei, pointer: ?*const GLvoid) void;
pub extern fn glTexCoordPointer(size: GLint, @"type": GLenum, stride: GLsizei, pointer: ?*const GLvoid) void;

// =============================================================================
// GL Constants
// =============================================================================

// Capabilities (for glEnable/glDisable)
pub const GL_DEPTH_TEST: GLenum = 0x0B71;
pub const GL_BLEND: GLenum = 0x0BE2;
pub const GL_ALPHA_TEST: GLenum = 0x0BC0;
pub const GL_SCISSOR_TEST: GLenum = 0x0C11;
pub const GL_STENCIL_TEST: GLenum = 0x0B90;
pub const GL_CULL_FACE: GLenum = 0x0B44;
pub const GL_FOG: GLenum = 0x0B60;
pub const GL_LIGHTING: GLenum = 0x0B50;
pub const GL_POLYGON_OFFSET_FILL: GLenum = 0x8037;

// Depth functions
pub const GL_NEVER: GLenum = 0x0200;
pub const GL_LESS: GLenum = 0x0201;
pub const GL_EQUAL: GLenum = 0x0202;
pub const GL_LEQUAL: GLenum = 0x0203;
pub const GL_GREATER: GLenum = 0x0204;
pub const GL_NOTEQUAL: GLenum = 0x0205;
pub const GL_GEQUAL: GLenum = 0x0206;
pub const GL_ALWAYS: GLenum = 0x0207;

// Front face
pub const GL_CW: GLenum = 0x0900;
pub const GL_CCW: GLenum = 0x0901;

// Face selection
pub const GL_FRONT: GLenum = 0x0404;
pub const GL_BACK: GLenum = 0x0405;
pub const GL_FRONT_AND_BACK: GLenum = 0x0408;

// Client state arrays
pub const GL_VERTEX_ARRAY: GLenum = 0x8074;
pub const GL_NORMAL_ARRAY: GLenum = 0x8075;
pub const GL_COLOR_ARRAY: GLenum = 0x8076;
pub const GL_TEXTURE_COORD_ARRAY: GLenum = 0x8078;

// Primitive types
pub const GL_POINTS: GLenum = 0x0000;
pub const GL_LINES: GLenum = 0x0001;
pub const GL_LINE_LOOP: GLenum = 0x0002;
pub const GL_LINE_STRIP: GLenum = 0x0003;
pub const GL_TRIANGLES: GLenum = 0x0004;
pub const GL_POLYGON: GLenum = 0x0009;
pub const GL_TRIANGLE_STRIP: GLenum = 0x0005;
pub const GL_TRIANGLE_FAN: GLenum = 0x0006;
pub const GL_QUADS: GLenum = 0x0007;

// Buffer targets
pub const GL_ARRAY_BUFFER: GLenum = 0x8892;
pub const GL_ELEMENT_ARRAY_BUFFER: GLenum = 0x8893;

// Buffer usage
pub const GL_STATIC_DRAW: GLenum = 0x88E4;
pub const GL_DYNAMIC_DRAW: GLenum = 0x88E8;
pub const GL_STREAM_DRAW: GLenum = 0x88E0;

// Texture targets
pub const GL_TEXTURE_1D: GLenum = 0x0DE0;
pub const GL_TEXTURE_2D: GLenum = 0x0DE1;
pub const GL_TEXTURE_3D: GLenum = 0x806F;
pub const GL_TEXTURE_CUBE_MAP: GLenum = 0x8513;

// Texture environment
pub const GL_TEXTURE_ENV: GLenum = 0x2300;
pub const GL_TEXTURE_ENV_MODE: GLenum = 0x2200;
pub const GL_TEXTURE_ENV_COLOR: GLenum = 0x2201;
pub const GL_MODULATE: GLenum = 0x2100;
pub const GL_DECAL: GLenum = 0x2101;
pub const GL_REPLACE: GLenum = 0x1E01;

// Shader types
pub const GL_FRAGMENT_SHADER: GLenum = 0x8B30;
pub const GL_VERTEX_SHADER: GLenum = 0x8B31;

// Shader status
pub const GL_COMPILE_STATUS: GLenum = 0x8B81;
pub const GL_LINK_STATUS: GLenum = 0x8B82;
pub const GL_VALIDATE_STATUS: GLenum = 0x8B83;
pub const GL_INFO_LOG_LENGTH: GLenum = 0x8B84;

// Texture parameters
pub const GL_TEXTURE_MAG_FILTER: GLenum = 0x2800;
pub const GL_TEXTURE_MIN_FILTER: GLenum = 0x2801;
pub const GL_TEXTURE_WRAP_S: GLenum = 0x2802;
pub const GL_TEXTURE_WRAP_T: GLenum = 0x2803;
pub const GL_TEXTURE_MAX_ANISOTROPY: GLenum = 0x84FE;

// Texture filter modes
pub const GL_NEAREST: GLenum = 0x2600;
pub const GL_LINEAR: GLenum = 0x2601;
pub const GL_NEAREST_MIPMAP_NEAREST: GLenum = 0x2700;
pub const GL_LINEAR_MIPMAP_NEAREST: GLenum = 0x2701;
pub const GL_NEAREST_MIPMAP_LINEAR: GLenum = 0x2702;
pub const GL_LINEAR_MIPMAP_LINEAR: GLenum = 0x2703;

// Texture wrap modes
pub const GL_CLAMP: GLenum = 0x2900;
pub const GL_REPEAT: GLenum = 0x2901;
pub const GL_CLAMP_TO_EDGE: GLenum = 0x812F;
pub const GL_CLAMP_TO_BORDER: GLenum = 0x812D;

// Pixel formats
pub const GL_RED: GLenum = 0x1903;
pub const GL_RGB: GLenum = 0x1907;
pub const GL_RGBA: GLenum = 0x1908;
pub const GL_BGR: GLenum = 0x80E0;
pub const GL_BGRA: GLenum = 0x80E1;

// Data types
pub const GL_UNSIGNED_BYTE: GLenum = 0x1401;
pub const GL_UNSIGNED_SHORT: GLenum = 0x1403;
pub const GL_UNSIGNED_INT: GLenum = 0x1405;
pub const GL_FLOAT: GLenum = 0x1406;

// Clear bits
pub const GL_COLOR_BUFFER_BIT: GLbitfield = 0x00004000;
pub const GL_DEPTH_BUFFER_BIT: GLbitfield = 0x00000100;
pub const GL_STENCIL_BUFFER_BIT: GLbitfield = 0x00000400;

// Matrix modes
pub const GL_MODELVIEW: GLenum = 0x1700;
pub const GL_PROJECTION: GLenum = 0x1701;
pub const GL_TEXTURE: GLenum = 0x1702;

// Blend factors
pub const GL_ZERO: GLenum = 0;
pub const GL_ONE: GLenum = 1;
pub const GL_SRC_COLOR: GLenum = 0x0300;
pub const GL_ONE_MINUS_SRC_COLOR: GLenum = 0x0301;
pub const GL_SRC_ALPHA: GLenum = 0x0302;
pub const GL_ONE_MINUS_SRC_ALPHA: GLenum = 0x0303;
pub const GL_DST_ALPHA: GLenum = 0x0304;
pub const GL_ONE_MINUS_DST_ALPHA: GLenum = 0x0305;
pub const GL_DST_COLOR: GLenum = 0x0306;
pub const GL_ONE_MINUS_DST_COLOR: GLenum = 0x0307;

// Fog
pub const GL_FOG_MODE: GLenum = 0x0B65;
pub const GL_FOG_DENSITY: GLenum = 0x0B62;
pub const GL_FOG_START: GLenum = 0x0B63;
pub const GL_FOG_END: GLenum = 0x0B64;
pub const GL_FOG_COLOR: GLenum = 0x0B66;
pub const GL_EXP: GLenum = 0x0800;
pub const GL_EXP2: GLenum = 0x0801;
// GL_LINEAR is defined in texture filter modes (0x2601)

// Boolean
pub const GL_TRUE: GLboolean = 1;
pub const GL_FALSE: GLboolean = 0;

// Error codes
pub const GL_NO_ERROR: GLenum = 0;
pub const GL_INVALID_ENUM: GLenum = 0x0500;
pub const GL_INVALID_VALUE: GLenum = 0x0501;
pub const GL_INVALID_OPERATION: GLenum = 0x0502;
pub const GL_OUT_OF_MEMORY: GLenum = 0x0505;
