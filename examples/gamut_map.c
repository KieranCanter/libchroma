/* examples/gamut_map.c -- map a Display P3 palette into sRGB for web use */

#include <stdio.h>
#include "chroma.h"

int main(void) {
    const float palette[][3] = {
        {0.92f, 0.20f, 0.14f}, /* vivid red */
        {0.10f, 0.82f, 0.30f}, /* vivid green */
        {0.15f, 0.25f, 0.98f}, /* vivid blue */
    };
    const char *names[] = {"red", "green", "blue"};
    const int n = sizeof(palette) / sizeof(palette[0]);

    printf("mapping Display P3 colors into sRGB gamut:\n\n");

    for (int i = 0; i < n; i++) {
        chroma_color_t p3 = chroma_init(CHROMA_DISPLAY_P3, palette[i]);
        bool in_gamut = chroma_is_in_gamut(p3, CHROMA_SRGB);
        chroma_color_t srgb = chroma_gamut_map(p3, CHROMA_SRGB);

        float src[3], dst[3];
        chroma_unpack(p3, src);
        chroma_unpack(srgb, dst);

        printf("  %-6s p3(%.2f, %.2f, %.2f) -> srgb(%.2f, %.2f, %.2f)  #%06X  %s\n",
            names[i],
            src[0], src[1], src[2],
            dst[0], dst[1], dst[2],
            chroma_unpack_hex(srgb),
            in_gamut ? "(in gamut)" : "(mapped)");
    }

    return 0;
}
