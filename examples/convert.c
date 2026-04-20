/* examples/convert.c -- conversion chain across color spaces */

#include <stdio.h>
#include "chroma.h"

static void print_color(const char *label, chroma_color_t c) {
    float v[4];
    int n = chroma_unpack(c, v);
    printf("  %-8s", label);
    for (int i = 0; i < n; i++) printf("%s%.4f", i ? ", " : "", v[i]);
    printf("\n");
}

int main(void) {
    chroma_color_t c = chroma_init_hex(0xE8A259);

    printf("conversion chain: #E8A259 -> srgb -> hsl -> oklch -> hex\n\n");

    printf("  hex     #%06X\n", chroma_unpack_hex(c));
    c = chroma_convert(c, CHROMA_SRGB);
    print_color("srgb", c);
    c = chroma_convert(c, CHROMA_HSL);
    print_color("hsl", c);
    c = chroma_convert(c, CHROMA_OKLCH);
    print_color("oklch", c);
    printf("  hex     #%06X (round-trip)\n", chroma_unpack_hex(c));

    return 0;
}
