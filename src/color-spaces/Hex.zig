const Canonical = @import("../Color.zig").Canonical;

pub const Hex = struct {
    value: u24,

    pub fn toCanonical(self: Hex) Canonical {
        @compileLog("TODO: Implement `toCanonical() for Hex");
    }

    pub fn fromCanonical(canon: Canonical) Hex {
        @compileLog("TODO: Implement `fromCanonical() for Hex");
    }
};
