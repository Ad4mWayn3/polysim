const std = @import("std");

fn makeMod(b: *std.Build, path: []const u8, name: []const u8,
    target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import
) *std.Build.Module {
    return b.addModule(name, .{
        .root_source_file = b.path(path),
        .target = target, .optimize = optimize,
        .imports = imports
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const mod = b.addModule("polysim", .{
    //     .root_source_file = b.path("src/root.zig"),
 
    //     .target = target,
    // });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const interface = makeMod(b, "thirdparty/interface.zig", "interface",
        target, optimize, &.{});

    const polysim = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target, .optimize = optimize,
        .imports = &.{
            .{ .name = "raylib", .module = raylib },
            .{ .name = "raygui", .module = raygui },
            .{ .name = "interface", .module = interface },
        }
    });

    const Polygon2D = b.addModule("Polygon2D", .{
        .root_source_file = b.path("Polygon2D.zig"),
        .target = target, .optimize = optimize,
        .imports = &.{.{.name = "polysim", .module = polysim}}
    });

    const geometry = makeMod(b, "geometry.zig", "geometry", target, optimize,
        &.{.{.name = "polysim", .module = polysim},
            .{.name = "Polygon2D", .module = Polygon2D},});

    const Sim = makeMod(b, "Sim.zig", "Sim", target, optimize,
        &.{.{.name = "polysim", .module = polysim},
            .{.name = "Polygon2D", .module = Polygon2D},
            .{.name = "geometry", .module = geometry},});

    const exe = b.addExecutable(.{
        .name = "polysim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
               .{ .name = "polysim", .module = polysim},
               .{ .name = "Polygon2D", .module = Polygon2D },
               .{ .name = "Sim", .module = Sim },
            },
        }),
    });
        

    exe.root_module.linkLibrary(raylib_artifact);
   
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
