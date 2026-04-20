/* examples/basic.c -- libchroma C API overview */

#include "chroma.h"

#include <stdio.h>
#include <string.h>

/* Helper: unpack a color's channels into a float array and return the count. */
static void print_color(const char *label, chroma_color_t c) {
    float v[4];
    int n = chroma_unpack(c, v);
    printf("%s: (", label);
    for (int i = 0; i < n; i++) printf("%s%.4f", i ? ", " : "", v[i]);
    printf(")\n");
}

int main(void) {
    /* --- hex init + conversion --- */
    printf("--- hex init + conversion ---\n");
    chroma_color_t orange = chroma_init_hex(0xC86432);
    printf("input:   #%06X\n", chroma_unpack_hex(orange));
    print_color("srgb", orange);
    print_color("oklch", chroma_convert(orange, CHROMA_OKLCH));
    print_color("hsl", chroma_convert(orange, CHROMA_HSL));

    /* --- gamut mapping --- */
    printf("\n--- gamut mapping ---\n");
    chroma_color_t p3_green = chroma_init(CHROMA_DISPLAY_P3, (float[]){0.0f, 1.0f, 0.0f});
    print_color("input", p3_green);
    printf("in srgb gamut: %s\n", chroma_is_in_gamut(p3_green, CHROMA_SRGB) ? "yes" : "no");
    chroma_color_t mapped = chroma_gamut_map(p3_green, CHROMA_SRGB);
    print_color("mapped", mapped);
    uint8_t r, g, b;
    chroma_unpack_srgb8(mapped, &r, &g, &b);
    printf("srgb8:   (%d, %d, %d)\n", r, g, b);
    printf("hex:     #%06X\n", chroma_unpack_hex(mapped));

    /* --- alpha --- */
    printf("\n--- alpha ---\n");
    chroma_alpha_color_t semi = chroma_init_hexa(0xC8643280);
    float alpha_vals[4];
    float alpha;
    chroma_unpack_alpha(semi, alpha_vals, &alpha);
    printf("input:   #C8643280\n");
    printf("rgb:     (%.4f, %.4f, %.4f)\n", alpha_vals[0], alpha_vals[1], alpha_vals[2]);
    printf("alpha:   %.2f\n", alpha);

    /* --- null hue --- */
    printf("\n--- null hue ---\n");
    chroma_color_t grey = chroma_init_hex(0x808080);
    chroma_color_t grey_hsl = chroma_convert(grey, CHROMA_HSL);
    float hsl[4];
    chroma_unpack(grey_hsl, hsl);
    printf("input:   #808080 (grey)\n");
    printf("hsl:     (h=%s, s=%.4f, l=%.4f)\n",
        chroma_hue_is_null(hsl[0]) ? "null" : "???", hsl[1], hsl[2]);

    /* --- interactive prompt --- */
    printf("\n--- interactive ---\n");
    char buf[64];

    int count = chroma_space_count();
    printf("space (");
    for (int i = 0; i < count; i++) {
        if (i > 0) printf(", ");
        printf("%s", chroma_space_name(i));
    }
    printf("): ");
    if (!fgets(buf, sizeof(buf), stdin)) return 1;
    buf[strcspn(buf, "\n")] = '\0';

    int space_val = chroma_space_from_name(buf);
    if (space_val < 0) { fprintf(stderr, "unknown space: %s\n", buf); return 1; }
    chroma_space_t space = (chroma_space_t)space_val;

    int n = chroma_field_count(space);
    float vals[4];
    for (int i = 0; i < n; i++) {
        printf("value %d: ", i + 1);
        if (scanf("%f", &vals[i]) != 1) return 1;
    }

    chroma_color_t clr = chroma_init(space, vals);

    printf("\nhex:     #%06X\n", chroma_unpack_hex(clr));
    print_color("srgb", chroma_convert(clr, CHROMA_SRGB));
    print_color("oklch", chroma_convert(clr, CHROMA_OKLCH));

    return 0;
}
