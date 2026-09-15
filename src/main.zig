const std = @import("std");
const compiler = @import("compiler.zig");

pub const generated_json = compiler.compile(
    @embedFile("declarations/purecore.pct"),
    @embedFile("config/purecore.yaml"),
);

pub fn main() !void {
    try std.fs.File.stdout().writeAll(generated_json);
    try std.fs.File.stdout().writeAll("\n");
}

test "comptime compiler emits canonical schemas for every type" {
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.unit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.load.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.stress.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.chaos.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.security.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"runtime-owned\"") != null);
}
