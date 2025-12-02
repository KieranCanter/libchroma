const Xyz = @import("Xyz.zig").Xyz;

pub const Cmyk = struct {
    c: f64,
    m: f64,
    y: f64,
    k: f64,

    pub fn toXyz(self: Cmyk) Xyz {
        @compileLog("TODO: Implement `toXyz() for Cmyk");
    }

    pub fn fromXyz(xyz: Xyz) Cmyk {
        @compileLog("TODO: Implement `fromXyz() for Cmyk");
    }
};
