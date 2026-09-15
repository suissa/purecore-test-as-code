const std = @import("std");
const compiler = @import("compiler.zig");

pub const generated = compiler.compile(
    @embedFile("declarations/actions.tdsl"),
    @embedFile("config/tests.yaml"),
);
pub const generated_json = generated.slice();

pub fn main() void {
    std.debug.print("{s}\n", .{generated_json});
}

test "comptime generator emits dynamic contracts and standard benchmarks" {
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"test.dynamic.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"test.benchmark.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"valid_cases\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"invalid_case_count\":71") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"test.load.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"test.stress.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"test.chaos.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"test.security.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"pcore.") == null);
    try std.testing.expect(std.mem.indexOf(u8, generated_json, "\"unit\"") == null);
}
