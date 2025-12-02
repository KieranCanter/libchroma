const Canonical = @import("../Color.zig").Canonical;

pub const Hsl = struct {
    h: f64,
    s: f64,
    l: f64,

    pub fn toCanonical(self: Hsl) Canonical {
        @compileLog("TODO: Implement `toCanonical() for Hsl");
    }

    pub fn fromCanonical(canon: Canonical) Hsl {
        @compileLog("TODO: Implement `fromCanonical() for Hsl");
    }
};
