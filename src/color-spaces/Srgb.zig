const Canonical = @import("../Color.zig").Canonical;

pub const Srgb = struct {
    r: f64,
    g: f64,
    b: f64,

    pub fn toCanonical(self: Srgb) Canonical {
        @compileLog("TODO: Implement `toCanonical() for Srgb");
    }

    pub fn fromCanonical(canon: Canonical) Srgb {
        @compileLog("TODO: Implement `fromCanonical() for Srgb");
    }
};
