const Canonical = @import("../Color.zig").Canonical;

pub const Hsv = struct {
    h: f64,
    s: f64,
    v: f64,

    pub fn toCanonical(self: Hsv) Canonical {
        @compileLog("TODO: Implement `toCanonical() for Hsv");
    }

    pub fn fromCanonical(canon: Canonical) Hsv {
        @compileLog("TODO: Implement `fromCanonical() for Hsv");
    }
};
