//! 12 equal temperament

const std = @import("std");

const Self = @This();

code: Code,
octave: usize,

pub fn add(self: Self, semitones: isize) Self {
    const self_midi_number: isize = @intCast(12 * (self.octave + 1) + @intFromEnum(self.code));
    const result_midi_number: isize = self_midi_number + semitones;

    const result_code: Code = @enumFromInt(@as(u8, @intCast(@mod(result_midi_number, 12))));
    const result_octave: usize = @intCast(@divTrunc(result_midi_number, 12) - 1);

    return Self{
        .code = result_code,
        .octave = result_octave,
    };
}

pub fn gen(scale: Self) f64 {
    const midi_number: isize = @intCast(12 * (scale.octave + 1) + @intFromEnum(scale.code));
    const exp: f64 = @floatFromInt(midi_number - 69);
    const result: f64 = 440.0 * std.math.pow(f64, 2.0, exp / 12.0);
    return result;
}

/// Codes written by English.
/// The `~s` code means the tone with sharp.
pub const Code = enum(u8) {
    c = 0,
    cs = 1,
    d = 2,
    ds = 3,
    e = 4,
    f = 5,
    fs = 6,
    g = 7,
    gs = 8,
    a = 9,
    as = 10,
    b = 11,
};

test "gen" {
    const a_4: f64 = 440.0;
    const result_a_4: f64 = Self.gen(.{ .code = .a, .octave = 4 });
    try std.testing.expectApproxEqRel(a_4, result_a_4, 0.0001);

    const g_3: f64 = 195.998;
    const result_g_3: f64 = Self.gen(.{ .code = .g, .octave = 3 });
    try std.testing.expectApproxEqRel(g_3, result_g_3, 0.0001);

    const c_7: f64 = 2093.005;
    const result_c_7: f64 = Self.gen(.{ .code = .c, .octave = 7 });
    try std.testing.expectApproxEqRel(c_7, result_c_7, 0.0001);
}

test "add" {
    const scale_a_4: Self = Self{ .code = .a, .octave = 4 };
    const result_a_4: Self = scale_a_4.add(3);
    try std.testing.expectEqual(result_a_4, Self{ .code = .c, .octave = 5 });
}
