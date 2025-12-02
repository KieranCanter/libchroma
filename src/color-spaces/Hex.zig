const Xyz = @import("Xyz.zig").Xyz;

pub const Hex = struct {
    value: u24,

    pub fn toXyz(self: Hex) Xyz {
        @compileLog("TODO: Implement `toXyz() for Hex");
    }

    pub fn fromXyz(xyz: Xyz) Hex {
        @compileLog("TODO: Implement `fromXyz() for Hex");
    }
};
