const Canonical = @import("../Color.zig").Canonical;

pub const LinearRgb = struct {
    r: f64,
    g: f64,
    b: f64,

    pub fn toCanonical(self: LinearRgb) Canonical {
        @compileLog("TODO: Implement `toCanonical() for LinearRgb");
    }

    pub fn fromCanonical(canon: Canonical) LinearRgb {
        @compileLog("TODO: Implement `fromCanonical() for LinearRgb");
    }
};
