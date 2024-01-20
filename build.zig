const std = @import("std");
const builtin = @import("builtin");
const Builder = std.Build;
const Pkg = std.Build.Pkg;

fn unwrapOptionalBool(optionalBool: ?bool) bool {
    if (optionalBool) |b| return b;
    return false;
}

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const win32exelink_mod: ?*std.Build.Module = blk: {
        if (target.result.os.tag == .windows) {
            const exe = b.addExecutable(.{
                .name = "win32exelink",
                .root_source_file = .{ .path = "src/win32exelink.zig" },
                .target = target,
                .optimize = optimize,
            });
            break :blk b.createModule(.{
                .root_source_file = exe.getEmittedBin(),
            });
        }
        break :blk null;
    };

    // TODO: Maybe add more executables with different ssl backends
    const exe = try addZigupExe(
        b,
        target,
        optimize,
        win32exelink_mod,
    );
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    addTest(b, exe, target, optimize);

    b.step("fmt", "format source").dependOn(
        &b.addFmt(.{
            .paths = &[_][]const u8{
                "build.zig",
                "build.zig.zon",
                "src",
            },
            .check = b.option(bool, "check", "check format") orelse false,
        }).step,
    );
}

fn addTest(b: *Builder, exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) void {
    const test_exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_cmd = b.addRunArtifact(test_exe);

    // TODO: make this work, add exe install path as argument to test
    //run_cmd.addArg(exe.getInstallPath());
    _ = exe;
    run_cmd.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "test the executable");
    test_step.dependOn(&run_cmd.step);
}

fn addZigupExe(
    b: *Builder,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    win32exelink_mod: ?*std.Build.Module,
) !*std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "zigup",
        .root_source_file = .{ .path = "src/zigup.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (target.result.os.tag == .windows) {
        exe.root_module.addImport("win32exelink", win32exelink_mod.?);
        const zarc_mod = b.dependency("zarc", .{}).module("zarc");
        exe.root_module.addImport("zarc", zarc_mod);
    }
    return exe;
}
