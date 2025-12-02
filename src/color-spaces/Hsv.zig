const Xyz = @import("Xyz.zig").Xyz;

pub const Hsv = struct {
    h: f64,
    s: f64,
    v: f64,

    pub fn toXyz(self: Hsv) Xyz {
        @compileLog("TODO: Implement `toXyz() for Hsv");
    }

    pub fn fromXyz(xyz: Xyz) Hsv {
        @compileLog("TODO: Implement `fromXyz() for Hsv");
    }
};
