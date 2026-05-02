/*
 * libchroma - Color space conversion library
 * https://github.com/kicanter/libchroma
 *
 * Conventions:
 *   - All channel values are float (f32). RGB spaces use [0,1] internally; use srgb8/hex helpers for 0-255 or packed.
 *   - Achromatic colors (greys) have no meaningful hue. The hue field is set to NaN. Use chroma_hue_is_null() to test.
 *   - Alpha is always [0,1] where 0 = transparent, 1 = opaque.
 *   - Gamut mapping uses OKLCH chroma reduction per CSS Color Level 5.
 *   - All conversions route through CIE XYZ (D65) as the interchange space.
 */

#ifndef CHROMA_H
#define CHROMA_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

/*
 * Color spaces
 * Enum values match the internal Zig `color_spaces` order. Do not reorder, this would be ABI breakage.
 */
typedef enum {
    CHROMA_XYZ,               /* CIE XYZ (D65)                              */
    CHROMA_YXY,               /* CIE Yxy                                    */
    CHROMA_SRGB,              /* sRGB (gamma-encoded)                       */
    CHROMA_LINEAR_SRGB,       /* Linear sRGB                                */
    CHROMA_DISPLAY_P3,        /* Display P3 (gamma-encoded)                 */
    CHROMA_LINEAR_DISPLAY_P3, /* Linear Display P3                          */
    CHROMA_REC2020,           /* Rec. 2020 display-referred (Rec. 1886)     */
    CHROMA_REC2020_SCENE,     /* Rec. 2020 scene-referred (Rec. 2020 OETF)  */
    CHROMA_LINEAR_REC2020,    /* Linear Rec. 2020                           */
    CHROMA_HSL,               /* HSL (hue, saturation, lightness)           */
    CHROMA_HSV,               /* HSV (hue, saturation, value)               */
    CHROMA_HSI,               /* HSI (hue, saturation, intensity)           */
    CHROMA_HWB,               /* HWB (hue, whiteness, blackness)            */
    CHROMA_CMYK,              /* CMYK (cyan, magenta, yellow, black)        */
    CHROMA_LAB,               /* CIE L*a*b* (D65)                           */
    CHROMA_LCH,               /* CIE LCH(ab) (D65)                          */
    CHROMA_OKLAB,             /* OKLab                                      */
    CHROMA_OKLCH,             /* OKLCH                                      */
} chroma_space_t;

/*
 * Channel structs
 * Each maps to one or more color spaces. Fields are f32. Hues are [0, 360) or NaN when achromatic.
 */

/*
 * `r`: red in [0, 1]
 * `g`: green in [0, 1]
 * `b`: blue in [0, 1]
 * Shared by all RGB spaces (sRGB, P3, Rec. 2020, etc.)
 */
typedef struct {
    float r;
    float g;
    float b;
} chroma_rgb_t;

/*
 * `h`: hue in [0, 360) or NaN
 * `s`: saturation in [0, 1]
 * `l`: lightness in [0, 1]
 */
typedef struct {
    float h;
    float s;
    float l;
} chroma_hsl_t;

/*
 * `h`: hue in [0, 360) or NaN
 * `s`: saturation in [0, 1]
 * `v`: value in [0, 1]
 */
typedef struct {
    float h;
    float s;
    float v;
} chroma_hsv_t;

/*
 * `h`: hue in [0, 360) or NaN
 * `w`: whiteness in [0, 1]
 * `b`: blackness in [0, 1]
 */
typedef struct {
    float h;
    float w;
    float b;
} chroma_hwb_t;

/*
 * `h`: hue in [0, 360) or NaN
 * `s`: saturation in [0, 1]
 * `i`: intensity in [0, 1]
 */
typedef struct {
    float h;
    float s;
    float i;
} chroma_hsi_t;

/*
 * `c`: cyan in [0, 1]
 * `m`: magenta in [0, 1]
 * `y`: yellow in [0, 1]
 * `k`: black in [0, 1]
 */
typedef struct {
    float c;
    float m;
    float y;
    float k;
} chroma_cmyk_t;

/*
 * `x`: mix of CIE RGB curves in [0, inf)
 * `y`: luminance in [0, inf)
 * `z`: quasi-blue in [0, inf)
 */
typedef struct {
    float x;
    float y;
    float z;
} chroma_xyz_t;

/*
 * `luma`: luminance in [0, 1]
 * `x`: chromaticity-x in [0, 1]
 * `y`: chromaticity-y in [0, 1]
 */
typedef struct {
    float luma;
    float x;
    float y;
} chroma_yxy_t;

/*
 * `l`: lightness
 * `a`: green-red axis
 * `b`: blue-yellow axis
 * Shared by CIE L*a*b* and OKLab (different ranges).
 */
typedef struct {
    float l;
    float a;
    float b;
} chroma_lab_t;

/*
 * `l`: lightness
 * `c`: chroma
 * `h`: hue in [0, 360) or NaN
 * Shared by CIE LCH and OKLCH (different ranges).
 */
typedef struct {
    float l;
    float c;
    float h;
} chroma_lch_t;

/* Per-space type aliases */
typedef chroma_xyz_t chroma_cie_xyz_t;
typedef chroma_yxy_t chroma_cie_yxy_t;
typedef chroma_rgb_t chroma_srgb_t;
typedef chroma_rgb_t chroma_linear_srgb_t;
typedef chroma_rgb_t chroma_display_p3_t;
typedef chroma_rgb_t chroma_linear_display_p3_t;
typedef chroma_rgb_t chroma_rec2020_t;
typedef chroma_rgb_t chroma_rec2020scene_t;
typedef chroma_rgb_t chroma_linear_rec2020_t;
typedef chroma_lab_t chroma_cie_lab_t;
typedef chroma_lch_t chroma_cie_lch_t;
typedef chroma_lab_t chroma_oklab_t;
typedef chroma_lch_t chroma_oklch_t;

/*
 * Color data union
 * Access the field matching the color's space tag. Reading the wrong field is undefined behavior.
 */
typedef union {
    chroma_cie_xyz_t cie_xyz;
    chroma_cie_yxy_t cie_yxy;
    chroma_srgb_t srgb;
    chroma_linear_srgb_t linear_srgb;
    chroma_display_p3_t display_p3;
    chroma_linear_display_p3_t linear_display_p3;
    chroma_rec2020_t rec2020;
    chroma_rec2020scene_t rec2020scene;
    chroma_linear_rec2020_t linear_rec2020;
    chroma_hsl_t hsl;
    chroma_hsv_t hsv;
    chroma_hsi_t hsi;
    chroma_hwb_t hwb;
    chroma_cmyk_t cmyk;
    chroma_cie_lab_t cie_lab;
    chroma_cie_lch_t cie_lch;
    chroma_oklab_t oklab;
    chroma_oklch_t oklch;
} chroma_color_data_t;

/* A color tagged union: space tag + channel data. */
typedef struct {
    chroma_space_t space;
    chroma_color_data_t data;
} chroma_color_t;

/* A color with an alpha channel, `alpha` is [0, 1] (0 = transparent). */
typedef struct {
    chroma_color_t color;
    float alpha;
} chroma_alpha_color_t;

/*
 * Conversion
 */

/* Convert `src` to the given destination space `dst`. */
chroma_color_t chroma_convert(chroma_color_t src, chroma_space_t dst);

/*
 * Gamut
 */

/* Check whether `src` is within the gamut of the given space. Only meaningful for RGB spaces; non-RGB returns true. */
bool chroma_is_in_gamut(chroma_color_t src, chroma_space_t gamut);

/* Map `src` into gamut of `target` via OKLCH chroma reduction (CSS Color Level 4). `target` must be an RGB space. */
chroma_color_t chroma_gamut_map(chroma_color_t src, chroma_space_t target);

/*
 * Meta utilities
 */

/* Parse a space name into a `chroma_space_t`. Returns -1 if unknown. */
int chroma_space_from_name(const char *name);

/* Return the number of supported color spaces. */
int chroma_space_count();

/* Return the name of a color space by index (0 to chroma_space_count()-1), or NULL if out of range. */
const char *chroma_space_name(int index);

/* Return the number of channel fields for a space (3 or 4). */
int chroma_field_count(chroma_space_t space);

/*
 * Format a color as "space(v1, v2, v3)" into buf. Returns bytes written (excluding null),
 * or -1 if the buffer is too small. buf is null-terminated on success.
 */
int chroma_format(chroma_color_t color, char *buf, int buf_size);

/*
 * Generic init / unpack
 * `vals` must point to 3 floats for most spaces, or 4 for CMYK.
 */

/* Build a color from a space tag and float channel values. */
chroma_color_t chroma_init(chroma_space_t space, const float *vals);

/* Copy channel values out of a color. Returns the number of channels. */
int chroma_unpack(chroma_color_t clr, float *vals);

/* Build an alpha color from a space tag, float channel values, and alpha. */
chroma_alpha_color_t chroma_init_alpha(chroma_space_t space, const float *vals, float alpha);

/* Copy channel values and alpha out of an alpha color. Returns channel count. */
int chroma_unpack_alpha(chroma_alpha_color_t aclr, float *vals, float *alpha);

/*
 * Hex helpers (0xRRGGBB / 0xRRGGBBAA)
 */

/* Build an sRGB color from a 24-bit hex value. Most significant 8 bits are ignored. */
chroma_color_t chroma_init_hex(uint32_t hex);

/* Convert any color to sRGB and return a 24-bit hex value (0x00RRGGBB). Most significant 8 bits are always 0. */
uint32_t chroma_unpack_hex(chroma_color_t clr);

/* Build an sRGB+alpha color from a 32-bit 0xRRGGBBAA value. */
chroma_alpha_color_t chroma_init_hexa(uint32_t rgba);

/* Convert any alpha color to sRGB and return a 32-bit 0xRRGGBBAA value. */
uint32_t chroma_unpack_hexa(chroma_alpha_color_t aclr);

/*
 * 8-bit sRGB helpers
 */

/* Build an sRGB color from 0-255 channel values. */
chroma_color_t chroma_init_srgb8(uint8_t r, uint8_t g, uint8_t b);

/* Convert any color to sRGB and write 0-255 channel values. */
void chroma_unpack_srgb8(chroma_color_t clr, uint8_t *r, uint8_t *g, uint8_t *b);

/* Build an sRGB+alpha color from 0-255 channel values. */
chroma_alpha_color_t chroma_init_srgba8(uint8_t r, uint8_t g, uint8_t b, uint8_t a);

/* Convert any alpha color to sRGB and write 0-255 channel values. */
void chroma_unpack_srgba8(chroma_alpha_color_t aclr, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a);

/*
 * Null hue utilities
 * Achromatic colors (pure greys) have no hue. The hue field is `NaN`.
 */

/* Returns nonzero if `h` is a null hue (`NaN`). */
static inline int chroma_hue_is_null(float h) {
    return __builtin_isnan(h);
}

/* Null hue sentinel value. Use when constructing achromatic colors manually. */
#define CHROMA_HUE_NONE __builtin_nanf("")

#ifdef __cplusplus
}
#endif

#endif /* CHROMA_H */
