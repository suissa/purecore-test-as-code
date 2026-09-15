const std = @import("std");
const compiler = @import("compiler.zig");

pub const generated = compiler.compile(
    @embedFile("declarations/purecore.pct"),
    @embedFile("config/purecore.yaml"),
);
pub const generated_json = generated.slice();

pub fn main() void {
    std.debug.print("{s}\\n", .{generated_json});
}

test "comptime compiler emits canonical schemas for every type" {
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.unit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.load.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.stress.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.chaos.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.test.security.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"runtime-owned\"") != null);
}
