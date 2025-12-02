const Canonical = @import("../Color.zig").Canonical;

pub const Xyz = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn toCanonical(self: Xyz) Canonical {
        @compileLog("TODO: Implement `toCanonical() for Xyz");
    }

    pub fn fromCanonical(canon: Canonical) Xyz {
        @compileLog("TODO: Implement `fromCanonical() for Xyz");
    }
};
