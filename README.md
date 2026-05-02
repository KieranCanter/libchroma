# libchroma

Color conversion library for native Zig or your favorite language via C ABI libs.

No runtime dependencies. No allocations. Just raw math.

## Color Spaces

### RGB
* sRGB
* Linear sRGB
* Display-P3
* Linear Display-P3
* Rec.2020
* Rec.2020 Scene
* Linear Rec.2020

### HSM
* HSL
* HSV
* HWB
* HSI

### LAB
* CIE LAB
* OKLAB

### LCH
* CIE LCH
* OKLCH

### XYZ Reference Spaces
* XYZ (D65)
* Yxy

### Miscellaneous
* CMYK

_More color space/model support to be added in the future._

## Features

- Static and dynamic libraries for Linux & MacOS, dependency-free (not even `libc`)
- Comptime-generic color types (`Srgb(f32)`, `Oklch(f64)`, etc.)
- Runtime `Color` tagged union for dynamic dispatch
- Alpha channel support via `Alpha(T)` wrapper
- Gamut mapping (OKLCH chroma reduction, CSS Color Level 4 algorithm)
- `chroma` CLI tool for basic executable usage
- Single C header (`chroma.h`)

## Building

Requires Zig 0.16.0+.

```bash
zig build          # lib + CLI
zig build test     # run tests
zig build examples # compile examples
```

Outputs:
- `zig-out/lib/libchroma.a` (static)
- `zig-out/lib/libchroma.so`/`.dylib` (dynamic)
- `zig-out/include/chroma.h`
- `zig-out/bin/chroma` (CLI)
- `zig-out/bin/examples/` (example executables)

## Zig Package

The easiest way to add libchroma is with `zig fetch`:

```bash
# From a release tag
zig fetch --save https://github.com/kicanter/libchroma/archive/refs/tags/<version-tag>.tar.gz

# Or from a specific commit
zig fetch --save https://github.com/kicanter/libchroma/archive/<commit-sha>.tar.gz
```

This writes the dependency (with the correct hash) into your `build.zig.zon` automatically.

Or add it manually to `build.zig.zon`:

```zig
.dependencies = .{
    .libchroma = .{
        .url = "https://github.com/kicanter/libchroma/archive/refs/tags/<version-tag>.tar.gz",
        .hash = "...",
    },
},
```

Put any placeholder for `.hash`. Zig will error on first build and tell you the correct value.

Then in `build.zig`:

```zig
const libchroma = b.dependency("libchroma", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("libchroma", libchroma.module("libchroma"));
```

## CLI

```bash
# Convert a color
chroma convert "#C86432" oklch
# oklch(0.61, 0.14, 45.08)

# Show in all spaces
chroma info "#C86432"
#   hex:       #C86432
#   srgb:      (0.78, 0.39, 0.2)
#   oklch:     (0.61, 0.14, 45.08)
#   ...

# JSON output
chroma info "#C86432" --json

# Control precision
chroma convert "oklch(0.7, 0.15, 180)" srgb --precision 4
```

Input formats: `[#]RRGGBB`, `[#]RRGGBBAA`, `space(v1, v2, v3)`.

## Zig API

```zig
const chroma = @import("libchroma");

// Comptime conversion
// Pass in your source color (comptime type) and the destination as a comptime type
const orange_srgb = chroma.Srgb(f32).initFromHex(0xC86432);
const orange_oklch = chroma.convert(orange, chroma.Oklch(f32));

// Alpha is preserved through conversion
const semi_srgb = chroma.Alpha(chroma.Srgb(f32)).init(orange, 0.5);
const semi_oklch = chroma.convert(semi, chroma.Alpha(chroma.Oklch(f32)));

// Gamut mapping
const p3_green = chroma.DisplayP3(f32).init(0, 1, 0);
const in_srgb = chroma.gamut.gamutMap(p3_green, chroma.Srgb(f32));

// Runtime conversion
// Pass in your source color (tagged union) and the destination as an enum tag
const color = chroma.Color{ .srgb = orange_srgb };
const result = chroma.color.convert(color, .oklch);
```

## C API

Link against `libchroma.a` (or `.so`/`.dylib` for dynamic linking) and include `chroma.h`.

```c
#include "chroma.h"

// Init from hex
chroma_color_t hex = chroma_init_hex(0xC86432);

// Convert
chroma_color_t oklch = chroma_convert(hex, CHROMA_OKLCH);

// Extract values
float oklch_vals[4];
int num_vals = chroma_unpack(oklch, vals);
// oklch_vals = {0.61, 0.14, 45.08}
// num_vals = 3

// Format to string
char buf[64];
chroma_format(oklch, buf, sizeof(buf));
// buf = "oklch(0.6100, 0.1400, 45.0800)"

// Gamut mapping
chroma_color_t p3 = chroma_init(CHROMA_DISPLAY_P3, (float[]){0, 1, 0});
chroma_color_t mapped = chroma_gamut_map(p3, CHROMA_SRGB);

// Alpha
chroma_alpha_color_t semi = chroma_init_alpha(CHROMA_SRGB, (float[]){0.78, 0.39, 0.2}, 0.5);
```

## FFI Examples

Since libchroma exposes a C ABI, you can call it from pretty much any language. Link against `libchroma.so` (or `.dylib` / `.a`) and load the functions.

### Rust

```rust
#[repr(C)]
#[derive(Copy, Clone)]
struct ChromaColor {
    space: i32,
    data: [f32; 4],
}

extern "C" {
    fn chroma_init_hex(hex: u32) -> ChromaColor;
    fn chroma_convert(color: ChromaColor, space: i32) -> ChromaColor;
    fn chroma_unpack(color: ChromaColor, vals: *mut f32) -> i32;
}

fn main() {
    let color = unsafe { chroma_init_hex(0xC86432) };
    let oklch = unsafe { chroma_convert(color, 17) }; // CHROMA_OKLCH
    let mut vals = [0f32; 4];
    unsafe { chroma_unpack(oklch, vals.as_mut_ptr()) };
    println!("oklch({:.2}, {:.2}, {:.2})", vals[0], vals[1], vals[2]);
}
```

### Go (cgo)

```go
/*
#cgo LDFLAGS: -L. -lchroma
#include "chroma.h"
*/
import "C"
import "fmt"

func main() {
    color := C.chroma_init_hex(0xC86432)
    oklch := C.chroma_convert(color, C.CHROMA_OKLCH)

    var vals [4]C.float
    C.chroma_unpack(oklch, &vals[0])
    fmt.Printf("oklch(%.2f, %.2f, %.2f)\n", vals[0], vals[1], vals[2])
}
```

### Odin

```odin
foreign import chroma "libchroma.so"

Chroma_Color :: struct #packed {
    space: i32,
    data:  [4]f32,
}

@(default_calling_convention = "c")
foreign chroma {
    chroma_init_hex :: proc(hex: u32) -> Chroma_Color ---
    chroma_convert :: proc(color: Chroma_Color, space: i32) -> Chroma_Color ---
    chroma_unpack :: proc(color: Chroma_Color, vals: [^]f32) -> i32 ---
}

main :: proc() {
    color := chroma_init_hex(0xC86432)
    oklch := chroma_convert(color, 17) // CHROMA_OKLCH

    vals: [4]f32
    chroma_unpack(oklch, &vals[0])
    fmt.printf("oklch(%.2f, %.2f, %.2f)\n", vals[0], vals[1], vals[2])
}
```

### Python (ctypes)

```python
import ctypes

class ChromaColor(ctypes.Structure):
    _fields_ = [("space", ctypes.c_int), ("data", ctypes.c_float * 4)]

lib = ctypes.CDLL("./libchroma.so")
lib.chroma_init_hex.restype = ChromaColor
lib.chroma_convert.restype = ChromaColor

color = lib.chroma_init_hex(0xC86432)
oklch = lib.chroma_convert(color, 17)  # CHROMA_OKLCH

vals = (ctypes.c_float * 4)()
lib.chroma_unpack(oklch, vals)
print(f"oklch({vals[0]:.2f}, {vals[1]:.2f}, {vals[2]:.2f})")
```

### Bun

```js
import { dlopen, FFIType, ptr, toBuffer } from "bun:ffi";

// chroma_color_t is 20 bytes: i32 space + 4x f32 data
const lib = dlopen("./libchroma.so", {
  chroma_init_hex: { args: [FFIType.u32], returns: FFIType.ptr },
  chroma_convert: { args: [FFIType.ptr, FFIType.i32], returns: FFIType.ptr },
  chroma_unpack: { args: [FFIType.ptr, FFIType.ptr], returns: FFIType.i32 },
});

const color = lib.symbols.chroma_init_hex(0xc86432);
const oklch = lib.symbols.chroma_convert(color, 17); // CHROMA_OKLCH

const vals = new Float32Array(4);
lib.symbols.chroma_unpack(oklch, ptr(vals));
console.log(`oklch(${vals[0].toFixed(2)}, ${vals[1].toFixed(2)}, ${vals[2].toFixed(2)})`);
```

## Architecture

All conversions route through CIE XYZ (D65) as the interchange space. Direct shortcuts exist where efficient (e.g., sRGB ↔ HSL skips XYZ).

Individual color types are comptime-generic over their backing float type (with RGB types also accepting `u8`s instead of floats). The runtime `Color` union and `Space` enum are generated at comptime from a single source-of-truth tuple, adding a new color space is one line.

Every color type must satisfy the color interface contract (enforced at comptime):

- `toCieXyz()`: convert to the XYZ
- `fromCieXyz()`: construct from XYZ
- `pub const Backing = T`: expose the backing numeric type

This is validated by `assertColorInterface()`, which is also exported for anyone implementing custom color types against the library.
