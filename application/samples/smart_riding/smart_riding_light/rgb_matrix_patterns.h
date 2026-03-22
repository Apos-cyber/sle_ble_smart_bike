/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: RGB Matrix 8x8 Patterns Header. \n
 */

#ifndef RGB_MATRIX_PATTERNS_H
#define RGB_MATRIX_PATTERNS_H

#include <stdint.h>

/* RGB Matrix 尺寸 */
#define RGB_MATRIX_WIDTH 8
#define RGB_MATRIX_HEIGHT 8

/* 颜色定义 */
#define COLOR_RED 0xFF0000
#define COLOR_GREEN 0x00FF00
#define COLOR_BLUE 0x0000FF
#define COLOR_WHITE 0xFFFFFF
#define COLOR_YELLOW 0xFFFF00
#define COLOR_CYAN 0x00FFFF
#define COLOR_MAGENTA 0xFF00FF
#define COLOR_ORANGE 0xFFA500
#define COLOR_PURPLE 0x800080
#define COLOR_BLACK 0x000000

/* 图案显示函数 */
void rgb_matrix_show_heart(uint32_t color);
void rgb_matrix_show_smiley(uint32_t color);
void rgb_matrix_show_rainbow(void);
void rgb_matrix_show_ring(uint32_t color);
void rgb_matrix_show_circle(uint32_t color);
void rgb_matrix_show_arrow_up(uint32_t color);
void rgb_matrix_show_arrow_down(uint32_t color);
void rgb_matrix_show_arrow_left(uint32_t color);
void rgb_matrix_show_arrow_right(uint32_t color);

#endif /* RGB_MATRIX_PATTERNS_H */
