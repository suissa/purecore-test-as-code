const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const executable = b.addExecutable(.{
        .name = "test-as-code-compiler",
        .root_module = module,
    });
    b.installArtifact(executable);

    const run_step = b.step("run", "Generate canonical test JSON");
    run_step.dependOn(&b.addRunArtifact(executable).step);

    const tests = b.addTest(.{ .root_module = module });
    const test_step = b.step("test", "Run compiler tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
