const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main library module
    const lib_mod = b.addModule("build_engine", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // Option to skip OpenGL linking (for systems without GL)
    const skip_gl = b.option(bool, "skip-gl", "Skip OpenGL linking") orelse false;

    // Main library - Zig 0.15 API: use addLibrary with linkage and root_module
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "build_engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link OpenGL (optional)
    if (!skip_gl) {
        lib.linkSystemLibrary("GL");
    }
    lib.linkSystemLibrary("c");

    b.installArtifact(lib);

    // ==========================================================================
    // Demos (non-graphical)
    // ==========================================================================

    // Map Viewer Demo (2D output to BMP)
    const mapview_exe = b.addExecutable(.{
        .name = "mapview",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demos/mapview.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    mapview_exe.root_module.addImport("build_engine", lib_mod);
    b.installArtifact(mapview_exe);

    // Run step for mapview
    const run_mapview = b.addRunArtifact(mapview_exe);
    run_mapview.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_mapview.addArgs(args);
    }

    const run_mapview_step = b.step("run-mapview", "Run the map viewer demo");
    run_mapview_step.dependOn(&run_mapview.step);

    // RFF Lister Tool
    const rff_list_exe = b.addExecutable(.{
        .name = "rff_list",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demos/rff_list.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    rff_list_exe.root_module.addImport("build_engine", lib_mod);
    b.installArtifact(rff_list_exe);

    // Debug Map Tool
    const debug_map_exe = b.addExecutable(.{
        .name = "debug_map",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demos/debug_map.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    debug_map_exe.root_module.addImport("build_engine", lib_mod);
    b.installArtifact(debug_map_exe);

    // ==========================================================================
    // 3D Explorer (requires SDL2 and OpenGL)
    // ==========================================================================

    // 3D Map Explorer - only build if SDL2/GL are available
    const explore3d_exe = b.addExecutable(.{
        .name = "explore3d",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demos/explore3d.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    explore3d_exe.root_module.addImport("build_engine", lib_mod);
    explore3d_exe.linkSystemLibrary("SDL2");
    explore3d_exe.linkSystemLibrary("GL");
    explore3d_exe.linkSystemLibrary("c");

    // Separate install step for explore3d
    const install_explore3d = b.addInstallArtifact(explore3d_exe, .{});
    const explore3d_step = b.step("explore3d", "Build the 3D map explorer (requires SDL2 and OpenGL)");
    explore3d_step.dependOn(&install_explore3d.step);

    // Run step for explore3d
    const run_explore3d = b.addRunArtifact(explore3d_exe);
    run_explore3d.step.dependOn(&install_explore3d.step);
    if (b.args) |args| {
        run_explore3d.addArgs(args);
    }

    const run_explore3d_step = b.step("run-explore3d", "Run the 3D map explorer demo");
    run_explore3d_step.dependOn(&run_explore3d.step);

    // ==========================================================================
    // Polymost Texture Test (requires SDL2 and OpenGL)
    // ==========================================================================

    const test_polymost_exe = b.addExecutable(.{
        .name = "test_polymost",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demos/test_polymost.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_polymost_exe.root_module.addImport("build_engine", lib_mod);
    test_polymost_exe.linkSystemLibrary("SDL2");
    test_polymost_exe.linkSystemLibrary("GL");
    test_polymost_exe.linkSystemLibrary("c");

    // Separate install step for test_polymost
    const install_test_polymost = b.addInstallArtifact(test_polymost_exe, .{});
    const test_polymost_step = b.step("test-polymost", "Build the polymost texture test (requires SDL2 and OpenGL)");
    test_polymost_step.dependOn(&install_test_polymost.step);

    // Run step for test_polymost
    const run_test_polymost = b.addRunArtifact(test_polymost_exe);
    run_test_polymost.step.dependOn(&install_test_polymost.step);
    if (b.args) |args| {
        run_test_polymost.addArgs(args);
    }

    const run_test_polymost_step = b.step("run-test-polymost", "Run the polymost texture test");
    run_test_polymost_step.dependOn(&run_test_polymost.step);

    // ==========================================================================
    // WASM 3D Explorer (for browsers)
    // ==========================================================================

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // Create shared modules for WASM (using WASM-specific wrappers to avoid import conflicts)
    const wasm_types_mod = b.createModule(.{
        .root_source_file = b.path("src/types.zig"),
    });
    const wasm_constants_mod = b.createModule(.{
        .root_source_file = b.path("src/constants.zig"),
    });
    const wasm_webgl_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/webgl.zig"),
    });

    // WASM-specific globals (uses module imports)
    const wasm_globals_mod = b.createModule(.{
        .root_source_file = b.path("web/globals_wasm.zig"),
        .imports = &.{
            .{ .name = "types", .module = wasm_types_mod },
            .{ .name = "constants", .module = wasm_constants_mod },
        },
    });

    // WASM-specific map loader (uses module imports)
    const wasm_map_mod = b.createModule(.{
        .root_source_file = b.path("web/map_wasm.zig"),
        .imports = &.{
            .{ .name = "types", .module = wasm_types_mod },
            .{ .name = "constants", .module = wasm_constants_mod },
            .{ .name = "globals", .module = wasm_globals_mod },
        },
    });

    // Web platform module
    const wasm_web_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/web.zig"),
    });

    // WebGL renderer module
    const wasm_render_web_mod = b.createModule(.{
        .root_source_file = b.path("src/polymost/render_web.zig"),
        .imports = &.{
            .{ .name = "types", .module = wasm_types_mod },
            .{ .name = "constants", .module = wasm_constants_mod },
            .{ .name = "globals", .module = wasm_globals_mod },
            .{ .name = "webgl", .module = wasm_webgl_mod },
        },
    });

    const wasm_exe = b.addExecutable(.{
        .name = "explore3d",
        .root_module = b.createModule(.{
            .root_source_file = b.path("web/explore3d_wasm.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });

    // Add all module imports
    wasm_exe.root_module.addImport("types", wasm_types_mod);
    wasm_exe.root_module.addImport("constants", wasm_constants_mod);
    wasm_exe.root_module.addImport("globals", wasm_globals_mod);
    wasm_exe.root_module.addImport("map", wasm_map_mod);
    wasm_exe.root_module.addImport("webgl", wasm_webgl_mod);
    wasm_exe.root_module.addImport("web", wasm_web_mod);
    wasm_exe.root_module.addImport("render_web", wasm_render_web_mod);

    // WASM-specific settings
    wasm_exe.rdynamic = true;
    wasm_exe.entry = .disabled;

    // Install to web directory
    const install_wasm = b.addInstallArtifact(wasm_exe, .{
        .dest_dir = .{ .override = .{ .custom = "../web" } },
    });

    const wasm_step = b.step("wasm", "Build the WASM 3D map explorer for browsers");
    wasm_step.dependOn(&install_wasm.step);

    // ==========================================================================
    // Tests
    // ==========================================================================

    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
