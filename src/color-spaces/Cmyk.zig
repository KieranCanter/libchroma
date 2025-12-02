const Canonical = @import("../Color.zig").Canonical;

pub const Cmyk = struct {
    c: f64,
    m: f64,
    y: f64,
    k: f64,

    pub fn toCanonical(self: Cmyk) Canonical {
        @compileLog("TODO: Implement `toCanonical() for Cmyk");
    }

    pub fn fromCanonical(canon: Canonical) Cmyk {
        @compileLog("TODO: Implement `fromCanonical() for Cmyk");
    }
};
