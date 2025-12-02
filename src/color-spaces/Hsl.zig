const Xyz = @import("Xyz.zig").Xyz;

pub const Hsl = struct {
    h: f64,
    s: f64,
    l: f64,

    pub fn toXyz(self: Hsl) Xyz {
        @compileLog("TODO: Implement `toXyz() for Hsl");
    }

    pub fn fromXyz(xyz: Xyz) Hsl {
        @compileLog("TODO: Implement `fromXyz() for Hsl");
    }
};
