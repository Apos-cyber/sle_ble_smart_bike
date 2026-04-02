/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: RGB Matrix 8x8 Patterns. \n
 */

#include "rgb_matrix_patterns.h"
#include "light.h"

/* 亮度控制: 0-255, 255为最亮 */
#ifndef RGB_MATRIX_BRIGHTNESS
#define RGB_MATRIX_BRIGHTNESS 100
#endif

/* 像素缓冲区 (由主文件提供) */
extern uint8_t g_pixels[RGB_MATRIX_WIDTH * RGB_MATRIX_HEIGHT][3];

/*============================================================================
 * 设置单个像素颜色 (带亮度控制)
 *============================================================================*/
static void set_pixel(uint8_t x, uint8_t y, uint8_t r, uint8_t g, uint8_t b)
{
    if (x >= RGB_MATRIX_WIDTH || y >= RGB_MATRIX_HEIGHT) {
        return;
    }
#if RGB_MATRIX_BRIGHTNESS < 255
    r = (r * RGB_MATRIX_BRIGHTNESS) / 255;
    g = (g * RGB_MATRIX_BRIGHTNESS) / 255;
    b = (b * RGB_MATRIX_BRIGHTNESS) / 255;
#endif
    int index = y * RGB_MATRIX_WIDTH + x;
    g_pixels[index][0] = g;
    g_pixels[index][1] = r;
    g_pixels[index][2] = b;
}

static void set_pixel_color(uint8_t x, uint8_t y, uint32_t color)
{
    uint8_t r = (color >> 16) & 0xFF;
    uint8_t g = (color >> 8) & 0xFF;
    uint8_t b = color & 0xFF;
    set_pixel(x, y, r, g, b);
}

static void clear_pixels(void)
{
    for (int i = 0; i < RGB_MATRIX_WIDTH * RGB_MATRIX_HEIGHT; i++) {
        g_pixels[i][0] = 0;
        g_pixels[i][1] = 0;
        g_pixels[i][2] = 0;
    }
}

/*============================================================================
 * 图案显示函数
 *============================================================================*/
void rgb_matrix_show_heart(uint32_t color)
{
    clear_pixels();

    static const uint8_t heart[RGB_MATRIX_HEIGHT][RGB_MATRIX_WIDTH] = {
        {0, 1, 1, 0, 0, 1, 1, 0},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {0, 1, 1, 1, 1, 1, 1, 0},
        {0, 0, 1, 1, 1, 1, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 0, 0, 0, 0, 0}};

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            if (heart[y][x]) {
                set_pixel_color(x, y, color);
            }
        }
    }
    rgb_matrix_refresh();
}

void rgb_matrix_show_smiley(uint32_t color)
{
    clear_pixels();

    static const uint8_t smiley[RGB_MATRIX_HEIGHT][RGB_MATRIX_WIDTH] = {
        {0, 0, 1, 1, 1, 1, 0, 0},
        {0, 1, 0, 0, 0, 0, 1, 0},
        {1, 0, 1, 0, 1, 0, 0, 1},
        {1, 0, 0, 0, 0, 0, 0, 1},
        {1, 0, 1, 0, 1, 0, 0, 1},
        {1, 0, 0, 1, 0, 0, 0, 1},
        {0, 1, 0, 0, 0, 0, 1, 0},
        {0, 0, 1, 1, 1, 1, 0, 0}};

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            if (smiley[y][x]) {
                set_pixel_color(x, y, color);
            }
        }
    }
    rgb_matrix_refresh();
}

void rgb_matrix_show_rainbow(void)
{
    clear_pixels();

    uint32_t colors[] = {
        COLOR_RED, COLOR_ORANGE, COLOR_YELLOW, COLOR_GREEN,
        COLOR_CYAN, COLOR_BLUE, COLOR_MAGENTA, COLOR_PURPLE};

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            uint32_t color = colors[(x + y) % 8];
            set_pixel_color(x, y, color);
        }
    }
    rgb_matrix_refresh();
}

void rgb_matrix_show_ring(uint32_t color)
{
    clear_pixels();

    for (int i = 0; i < RGB_MATRIX_WIDTH; i++) {
        set_pixel_color(i, 0, color);
        set_pixel_color(i, RGB_MATRIX_HEIGHT - 1, color);
    }
    for (int i = 1; i < RGB_MATRIX_HEIGHT - 1; i++) {
        set_pixel_color(0, i, color);
        set_pixel_color(RGB_MATRIX_WIDTH - 1, i, color);
    }

    rgb_matrix_refresh();
}

/* 实心圆 */
void rgb_matrix_show_circle(uint32_t color)
{
    clear_pixels();

    static const uint8_t circle[RGB_MATRIX_HEIGHT][RGB_MATRIX_WIDTH] = {
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 1, 1, 1, 1, 0, 0},
        {0, 1, 1, 1, 1, 1, 1, 0},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {0, 1, 1, 1, 1, 1, 1, 0},
        {0, 0, 1, 1, 1, 1, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0}};

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            if (circle[y][x]) {
                set_pixel_color(x, y, color);
            }
        }
    }

    rgb_matrix_refresh();
}

/* 上箭头 */
void rgb_matrix_show_arrow_up(uint32_t color)
{
    clear_pixels();

    static const uint8_t arrow_up[RGB_MATRIX_HEIGHT][RGB_MATRIX_WIDTH] = {
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 1, 1, 1, 1, 0, 0},
        {0, 1, 0, 1, 1, 0, 1, 0},
        {1, 0, 0, 1, 1, 0, 0, 1},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0}};

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            if (arrow_up[y][x]) {
                set_pixel_color(x, y, color);
            }
        }
    }

    rgb_matrix_refresh();
}

/* 下箭头 */
void rgb_matrix_show_arrow_down(uint32_t color)
{
    clear_pixels();

    static const uint8_t arrow_down[RGB_MATRIX_HEIGHT][RGB_MATRIX_WIDTH] = {
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0},
        {1, 0, 0, 1, 1, 0, 0, 1},
        {0, 1, 0, 1, 1, 0, 1, 0},
        {0, 0, 1, 1, 1, 1, 0, 0},
        {0, 0, 0, 1, 1, 0, 0, 0}};

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            if (arrow_down[y][x]) {
                set_pixel_color(x, y, color);
            }
        }
    }

    rgb_matrix_refresh();
}

/* 左箭头 */
void rgb_matrix_show_arrow_left(uint32_t color)
{
    clear_pixels();

    static const uint8_t arrow_left[RGB_MATRIX_HEIGHT][RGB_MATRIX_WIDTH] = {
        {0, 0, 0, 1, 0, 0, 0, 0},
        {0, 0, 1, 0, 0, 0, 0, 0},
        {0, 1, 0, 0, 0, 0, 0, 0},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {0, 1, 0, 0, 0, 0, 0, 0},
        {0, 0, 1, 0, 0, 0, 0, 0},
        {0, 0, 0, 1, 0, 0, 0, 0}
    };

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            if (arrow_left[y][x]) {
                set_pixel_color(x, y, color);
            }
        }
    }

    rgb_matrix_refresh();
}

/* 右箭头 */
void rgb_matrix_show_arrow_right(uint32_t color)
{
    clear_pixels();

    static const uint8_t arrow_right[RGB_MATRIX_HEIGHT][RGB_MATRIX_WIDTH] = {
        {0, 0, 0, 0, 1, 0, 0, 0},
        {0, 0, 0, 0, 0, 1, 0, 0},
        {0, 0, 0, 0, 0, 0, 1, 0},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1, 1, 1, 1},
        {0, 0, 0, 0, 0, 0, 1, 0},
        {0, 0, 0, 0, 0, 1, 0, 0},
        {0, 0, 0, 0, 1, 0, 0, 0}
    };

    for (int y = 0; y < RGB_MATRIX_HEIGHT; y++) {
        for (int x = 0; x < RGB_MATRIX_WIDTH; x++) {
            if (arrow_right[y][x]) {
                set_pixel_color(x, y, color);
            }
        }
    }

    rgb_matrix_refresh();
}
