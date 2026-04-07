/*
 * libchroma - Color space conversion library
 * C ABI header
 *
 * Null hue values (achromatic colors) are represented as NaN.
 */

#ifndef CHROMA_H
#define CHROMA_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <math.h>

/* ------------------------------------------------------------------ */
/* Types                                                               */
/* ------------------------------------------------------------------ */

typedef enum {
    CHROMA_SRGB,
    CHROMA_SRGB_U8,
    CHROMA_LINEAR_SRGB,
    CHROMA_DISPLAY_P3,
    CHROMA_LINEAR_DISPLAY_P3,
    CHROMA_REC2020,
    CHROMA_REC2020_SCENE,
    CHROMA_LINEAR_REC2020,
    CHROMA_HSL,
    CHROMA_HSV,
    CHROMA_HWB,
    CHROMA_HSI,
    CHROMA_CMYK,
    CHROMA_XYZ,
    CHROMA_YXY,
    CHROMA_LAB,
    CHROMA_LCH,
    CHROMA_OKLAB,
    CHROMA_OKLCH,
} chroma_space_t;

typedef struct { float r, g, b; }          chroma_srgb_t;
typedef struct { uint8_t r, g, b; }        chroma_srgb_u8_t;
typedef struct { float r, g, b; }          chroma_linear_srgb_t;
typedef struct { float r, g, b; }          chroma_display_p3_t;
typedef struct { float r, g, b; }          chroma_linear_display_p3_t;
typedef struct { float r, g, b; }          chroma_rec2020_t;
typedef struct { float r, g, b; }          chroma_rec2020_scene_t;
typedef struct { float r, g, b; }          chroma_linear_rec2020_t;
typedef struct { float h, s, l; }          chroma_hsl_t;
typedef struct { float h, s, v; }          chroma_hsv_t;
typedef struct { float h, w, b; }          chroma_hwb_t;
typedef struct { float h, s, i; }          chroma_hsi_t;
typedef struct { float c, m, y, k; }       chroma_cmyk_t;
typedef struct { float x, y, z; }          chroma_xyz_t;
typedef struct { float luma, x, y; }       chroma_yxy_t;
typedef struct { float l, a, b; }          chroma_lab_t;
typedef struct { float l, c, h; }          chroma_lch_t;
typedef struct { float l, a, b; }          chroma_oklab_t;
typedef struct { float l, c, h; }          chroma_oklch_t;

typedef struct {
    chroma_space_t space;
    float alpha;
    union {
        chroma_srgb_t              srgb;
        chroma_srgb_u8_t           srgb_u8;
        chroma_linear_srgb_t       linear_srgb;
        chroma_display_p3_t        display_p3;
        chroma_linear_display_p3_t linear_display_p3;
        chroma_rec2020_t           rec2020;
        chroma_rec2020_scene_t     rec2020_scene;
        chroma_linear_rec2020_t    linear_rec2020;
        chroma_hsl_t               hsl;
        chroma_hsv_t               hsv;
        chroma_hwb_t               hwb;
        chroma_hsi_t               hsi;
        chroma_cmyk_t              cmyk;
        chroma_xyz_t               xyz;
        chroma_yxy_t               yxy;
        chroma_lab_t               lab;
        chroma_lch_t               lch;
        chroma_oklab_t             oklab;
        chroma_oklch_t             oklch;
    };
} chroma_color_t;

/* ------------------------------------------------------------------ */
/* API                                                                 */
/* ------------------------------------------------------------------ */

/* Convert a color from one space to another. Alpha is preserved. */
chroma_color_t chroma_convert(chroma_color_t src, chroma_space_t dst);

/* Helper: check if a hue value represents "no hue" (achromatic). */
static inline int chroma_hue_is_null(float h) { return isnan(h); }

/* Helper: the "no hue" sentinel value. */
#define CHROMA_HUE_NONE NAN

#ifdef __cplusplus
}
#endif

#endif /* CHROMA_H */
