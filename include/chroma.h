/*
 * libchroma - Color space conversion library (C ABI)
 * Null hues (achromatic colors) are represented as NaN.
 */

#ifndef CHROMA_H
#define CHROMA_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

/* Types */

/* Integer values must match color.zig color_spaces order. */
typedef enum {
    CHROMA_XYZ,
    CHROMA_YXY,
    CHROMA_SRGB,
    CHROMA_LINEAR_SRGB,
    CHROMA_DISPLAY_P3,
    CHROMA_LINEAR_DISPLAY_P3,
    CHROMA_REC2020,
    CHROMA_REC2020_SCENE,
    CHROMA_LINEAR_REC2020,
    CHROMA_HSL,
    CHROMA_HSV,
    CHROMA_HSI,
    CHROMA_HWB,
    CHROMA_CMYK,
    CHROMA_LAB,
    CHROMA_LCH,
    CHROMA_OKLAB,
    CHROMA_OKLCH,
} chroma_space_t;

typedef struct { float r, g, b; } chroma_rgb_t;
typedef struct { float h, s, l; } chroma_hsl_t;
typedef struct { float h, s, v; } chroma_hsv_t;
typedef struct { float h, w, b; } chroma_hwb_t;
typedef struct { float h, s, i; } chroma_hsi_t;
typedef struct { float c, m, y, k; } chroma_cmyk_t;
typedef struct { float x, y, z; } chroma_xyz_t;
typedef struct { float luma, x, y; } chroma_yxy_t;
typedef struct { float l, a, b; } chroma_lab_t;
typedef struct { float l, c, h; } chroma_lch_t;

typedef union {
    chroma_xyz_t cie_xyz;
    chroma_yxy_t cie_yxy;
    chroma_rgb_t srgb;
    chroma_rgb_t linear_srgb;
    chroma_rgb_t display_p3;
    chroma_rgb_t linear_display_p3;
    chroma_rgb_t rec2020;
    chroma_rgb_t rec2020scene;
    chroma_rgb_t linear_rec2020;
    chroma_hsl_t hsl;
    chroma_hsv_t hsv;
    chroma_hsi_t hsi;
    chroma_hwb_t hwb;
    chroma_cmyk_t cmyk;
    chroma_lab_t cie_lab;
    chroma_lch_t cie_lch;
    chroma_lab_t oklab;
    chroma_lch_t oklch;
} chroma_color_data_t;

typedef struct {
    chroma_space_t space;
    chroma_color_data_t data;
} chroma_color_t;

typedef struct {
    chroma_color_t color;
    float alpha;
} chroma_alpha_color_t;

/* API */

/* Convert a color to another space. */
chroma_color_t chroma_convert(chroma_color_t src, chroma_space_t dst);

/* Check if a color is within the gamut of the given RGB space. Non-RGB always returns true. */
bool chroma_is_in_gamut(chroma_color_t src, chroma_space_t gamut);

/* Map a color into gamut via OKLCH chroma reduction (CSS Color Level 4). */
chroma_color_t chroma_gamut_map(chroma_color_t src, chroma_space_t target);

/* Construct a color from float values (3 or 4 depending on space). */
chroma_color_t chroma_init(chroma_space_t space, const float *vals);

/* Extract float values. Returns field count (3 or 4). */
int chroma_unpack(chroma_color_t c, float *vals);

/* Construct an alpha color from float values and alpha. */
chroma_alpha_color_t chroma_init_alpha(chroma_space_t space, const float *vals, float alpha);

/* Extract float values and alpha. Returns field count. */
int chroma_unpack_alpha(chroma_alpha_color_t c, float *vals, float *alpha);

/* Construct sRGB from a 24-bit hex value (0xRRGGBB). */
chroma_color_t chroma_init_hex(uint32_t hex);

/* Extract a 24-bit hex value (0xRRGGBB), converting to sRGB if needed. */
uint32_t chroma_unpack_hex(chroma_color_t c);

/* Construct sRGB from 0-255 u8 values. */
chroma_color_t chroma_init_srgb8(uint8_t r, uint8_t g, uint8_t b);

/* Extract 0-255 u8 sRGB values, converting if needed. */
void chroma_unpack_srgb8(chroma_color_t c, uint8_t *r, uint8_t *g, uint8_t *b);

/* Construct sRGB+alpha from 0-255 u8 values. */
chroma_alpha_color_t chroma_init_srgba8(uint8_t r, uint8_t g, uint8_t b, uint8_t a);

/* Extract 0-255 u8 sRGBA values, converting if needed. */
void chroma_unpack_srgba8(chroma_alpha_color_t c, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a);

/* Construct sRGB+alpha from a 32-bit 0xRRGGBBAA value. */
chroma_alpha_color_t chroma_init_hexa(uint32_t rgba);

/* Extract a 32-bit 0xRRGGBBAA value, converting to sRGB if needed. */
uint32_t chroma_unpack_hexa(chroma_alpha_color_t c);

/* Check if a hue is null (achromatic). */
static inline int chroma_hue_is_null(float h) {
    return __builtin_isnan(h);
}

/* Null hue sentinel. */
#define CHROMA_HUE_NONE __builtin_nanf("")

#ifdef __cplusplus
}
#endif

#endif /* CHROMA_H */
