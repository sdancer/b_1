//! SDL2 Platform Layer
//! Provides SDL2 bindings and window management for the BUILD engine.

const std = @import("std");

// =============================================================================
// SDL2 C Bindings
// =============================================================================

pub const SDL_Window = opaque {};
pub const SDL_GLContext = ?*anyopaque;

// SDL Init flags
pub const SDL_INIT_VIDEO: u32 = 0x00000020;
pub const SDL_INIT_EVENTS: u32 = 0x00004000;

// SDL Window flags
pub const SDL_WINDOW_OPENGL: u32 = 0x00000002;
pub const SDL_WINDOW_SHOWN: u32 = 0x00000004;
pub const SDL_WINDOW_RESIZABLE: u32 = 0x00000020;

// SDL GL Attributes
pub const SDL_GL_CONTEXT_MAJOR_VERSION: c_int = 17;
pub const SDL_GL_CONTEXT_MINOR_VERSION: c_int = 18;
pub const SDL_GL_DOUBLEBUFFER: c_int = 5;
pub const SDL_GL_DEPTH_SIZE: c_int = 6;
pub const SDL_GL_RED_SIZE: c_int = 0;
pub const SDL_GL_GREEN_SIZE: c_int = 1;
pub const SDL_GL_BLUE_SIZE: c_int = 2;
pub const SDL_GL_ALPHA_SIZE: c_int = 3;

// SDL Event types
pub const SDL_QUIT: u32 = 0x100;
pub const SDL_KEYDOWN: u32 = 0x300;
pub const SDL_KEYUP: u32 = 0x301;
pub const SDL_MOUSEMOTION: u32 = 0x400;
pub const SDL_MOUSEBUTTONDOWN: u32 = 0x401;
pub const SDL_MOUSEBUTTONUP: u32 = 0x402;
pub const SDL_WINDOWEVENT: u32 = 0x200;

// SDL Scancode values
pub const SDL_SCANCODE_W: c_int = 26;
pub const SDL_SCANCODE_A: c_int = 4;
pub const SDL_SCANCODE_S: c_int = 22;
pub const SDL_SCANCODE_D: c_int = 7;
pub const SDL_SCANCODE_Q: c_int = 20;
pub const SDL_SCANCODE_E: c_int = 8;
pub const SDL_SCANCODE_UP: c_int = 82;
pub const SDL_SCANCODE_DOWN: c_int = 81;
pub const SDL_SCANCODE_LEFT: c_int = 80;
pub const SDL_SCANCODE_RIGHT: c_int = 79;
pub const SDL_SCANCODE_LSHIFT: c_int = 225;
pub const SDL_SCANCODE_RSHIFT: c_int = 229;
pub const SDL_SCANCODE_ESCAPE: c_int = 41;
pub const SDL_SCANCODE_SPACE: c_int = 44;

// SDL Key states
pub const SDL_PRESSED: u8 = 1;
pub const SDL_RELEASED: u8 = 0;

// SDL Event union (simplified - only what we need)
pub const SDL_Keysym = extern struct {
    scancode: c_int,
    sym: i32,
    mod: u16,
    unused: u32,
};

pub const SDL_KeyboardEvent = extern struct {
    type: u32,
    timestamp: u32,
    windowID: u32,
    state: u8,
    repeat: u8,
    padding2: u8,
    padding3: u8,
    keysym: SDL_Keysym,
};

pub const SDL_MouseMotionEvent = extern struct {
    type: u32,
    timestamp: u32,
    windowID: u32,
    which: u32,
    state: u32,
    x: i32,
    y: i32,
    xrel: i32,
    yrel: i32,
};

pub const SDL_Event = extern union {
    type: u32,
    key: SDL_KeyboardEvent,
    motion: SDL_MouseMotionEvent,
    padding: [56]u8,
};

// SDL function declarations
pub extern fn SDL_Init(flags: u32) c_int;
pub extern fn SDL_Quit() void;
pub extern fn SDL_CreateWindow(title: [*:0]const u8, x: c_int, y: c_int, w: c_int, h: c_int, flags: u32) ?*SDL_Window;
pub extern fn SDL_DestroyWindow(window: *SDL_Window) void;
pub extern fn SDL_GL_CreateContext(window: *SDL_Window) SDL_GLContext;
pub extern fn SDL_GL_DeleteContext(context: SDL_GLContext) void;
pub extern fn SDL_GL_MakeCurrent(window: *SDL_Window, context: SDL_GLContext) c_int;
pub extern fn SDL_GL_SetAttribute(attr: c_int, value: c_int) c_int;
pub extern fn SDL_GL_SwapWindow(window: *SDL_Window) void;
pub extern fn SDL_PollEvent(event: *SDL_Event) c_int;
pub extern fn SDL_GetTicks() u32;
pub extern fn SDL_GetTicks64() u64;
pub extern fn SDL_GetKeyboardState(numkeys: ?*c_int) [*]const u8;
pub extern fn SDL_GetError() [*:0]const u8;
pub extern fn SDL_SetRelativeMouseMode(enabled: c_int) c_int;
pub extern fn SDL_GetRelativeMouseState(x: ?*c_int, y: ?*c_int) u32;
pub extern fn SDL_WarpMouseInWindow(window: ?*SDL_Window, x: c_int, y: c_int) void;
pub extern fn SDL_ShowCursor(toggle: c_int) c_int;
pub extern fn SDL_SetWindowGrab(window: *SDL_Window, grabbed: c_int) void;
pub extern fn SDL_Delay(ms: u32) void;

// Window position constants
pub const SDL_WINDOWPOS_CENTERED: c_int = 0x2FFF0000;

// =============================================================================
// Window Wrapper
// =============================================================================

pub const Window = struct {
    handle: *SDL_Window,
    gl_context: SDL_GLContext,
    width: i32,
    height: i32,

    pub fn init(width: i32, height: i32, title: [:0]const u8) !Window {
        // Initialize SDL
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0) {
            std.debug.print("SDL_Init failed: {s}\n", .{SDL_GetError()});
            return error.SDLInitFailed;
        }
        errdefer SDL_Quit();

        // Set GL attributes
        _ = SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
        _ = SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
        _ = SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        _ = SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
        _ = SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
        _ = SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
        _ = SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);

        // Create window
        const window = SDL_CreateWindow(
            title.ptr,
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            width,
            height,
            SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE,
        ) orelse {
            std.debug.print("SDL_CreateWindow failed: {s}\n", .{SDL_GetError()});
            return error.WindowCreationFailed;
        };
        errdefer SDL_DestroyWindow(window);

        // Create GL context
        const gl_context = SDL_GL_CreateContext(window);
        if (gl_context == null) {
            std.debug.print("SDL_GL_CreateContext failed: {s}\n", .{SDL_GetError()});
            return error.GLContextCreationFailed;
        }

        // Make context current
        if (SDL_GL_MakeCurrent(window, gl_context) != 0) {
            return error.GLMakeCurrentFailed;
        }

        return Window{
            .handle = window,
            .gl_context = gl_context,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Window) void {
        SDL_GL_DeleteContext(self.gl_context);
        SDL_DestroyWindow(self.handle);
        SDL_Quit();
    }

    pub fn swapBuffers(self: *Window) void {
        SDL_GL_SwapWindow(self.handle);
    }

    pub fn setMouseCapture(self: *Window, captured: bool) void {
        _ = SDL_SetRelativeMouseMode(if (captured) 1 else 0);
        SDL_SetWindowGrab(self.handle, if (captured) 1 else 0);
        _ = SDL_ShowCursor(if (captured) 0 else 1);
    }
};

// =============================================================================
// Event Handling
// =============================================================================

pub const EventResult = struct {
    quit: bool = false,
    mouse_dx: i32 = 0,
    mouse_dy: i32 = 0,
};

/// Process all pending SDL events
pub fn processEvents() EventResult {
    var result = EventResult{};
    var event: SDL_Event = undefined;

    while (SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            SDL_QUIT => {
                result.quit = true;
            },
            SDL_KEYDOWN => {
                if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE) {
                    result.quit = true;
                }
            },
            SDL_MOUSEMOTION => {
                result.mouse_dx += event.motion.xrel;
                result.mouse_dy += event.motion.yrel;
            },
            else => {},
        }
    }

    return result;
}

// =============================================================================
// Timing
// =============================================================================

/// Get milliseconds since SDL init
pub fn getTicks() u32 {
    return SDL_GetTicks();
}

/// Get milliseconds since SDL init (64-bit)
pub fn getTicks64() u64 {
    return SDL_GetTicks64();
}

/// Delay for specified milliseconds
pub fn delay(ms: u32) void {
    SDL_Delay(ms);
}

// =============================================================================
// Tests
// =============================================================================

test "SDL constants" {
    try std.testing.expect(SDL_INIT_VIDEO != 0);
    try std.testing.expect(SDL_WINDOW_OPENGL != 0);
}
