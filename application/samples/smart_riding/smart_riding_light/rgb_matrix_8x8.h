/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: RGB Matrix 8x8 Internal Header. \n
 */

#ifndef RGB_MATRIX_8X8_H
#define RGB_MATRIX_8X8_H

#include <stdint.h>

/* 像素缓冲区尺寸 */
#define RGB_MATRIX_PIXELS 64

/* 外部声明 - 由主文件定义，图案文件使用 */
extern uint8_t g_pixels[RGB_MATRIX_PIXELS][3];

/* 刷新函数 - 由主文件实现，图案文件调用 */
extern void rgb_matrix_refresh(void);

#endif /* RGB_MATRIX_8X8_H */
