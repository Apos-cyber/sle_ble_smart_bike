/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: Bike Light Control Interface. \n
 */

#ifndef LIGHT_H
#define LIGHT_H

#include <stdint.h>
#include "errcode.h"

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif
#endif

/* 车灯模式枚举 */
typedef enum {
    LIGHT_MODE_OFF = 0,      /* 关闭 */
    LIGHT_MODE_ON = 1,       /* 常亮 */
    LIGHT_MODE_LEFT = 2,     /* 左转灯 */
    LIGHT_MODE_RIGHT = 3,    /* 右转灯 */
    LIGHT_MODE_RAINBOW = 4,  /* 彩虹模式 */
    LIGHT_MODE_HEART = 5,    /* 爱心 */
    LIGHT_MODE_CIRCLE = 6,   /* 圆形 */
} light_mode_t;

/**
 * @brief 车灯初始化 (SPI初始化)
 * @return 成功返回 ERRCODE_SUCC
 */
errcode_t light_init(void);

/**
 * @brief 设置车灯模式
 * @param mode 车灯模式 (light_mode_t)
 * @param color 颜色值 (如 COLOR_RED, COLOR_ORANGE 等)
 */
void light_set_mode(light_mode_t mode, uint32_t color);

/**
 * @brief 车灯开启
 * @param color 颜色值
 */
void light_on(uint32_t color);

/**
 * @brief 车灯关闭
 */
void light_off(void);

/**
 * @brief 左转灯
 * @param color 颜色值
 */
void light_turn_left(uint32_t color);

/**
 * @brief 右转灯
 * @param color 颜色值
 */
void light_turn_right(uint32_t color);

/* 预定义颜色 */
#define LIGHT_COLOR_RED      0xFF0000
#define LIGHT_COLOR_GREEN    0x00FF00
#define LIGHT_COLOR_BLUE     0x0000FF
#define LIGHT_COLOR_WHITE    0xFFFFFF
#define LIGHT_COLOR_YELLOW   0xFFFF00
#define LIGHT_COLOR_CYAN     0x00FFFF
#define LIGHT_COLOR_MAGENTA  0xFF00FF
#define LIGHT_COLOR_ORANGE   0xFFA500
#define LIGHT_COLOR_PURPLE   0x800080

/* RGB Matrix 像素数量 */
#define RGB_MATRIX_PIXELS 64

/* 像素缓冲区 - 在 light.c 中定义，图案文件使用 */
extern uint8_t g_pixels[RGB_MATRIX_PIXELS][3];

/* 刷新函数 - 在 light.c 中实现，图案文件调用 */
extern void rgb_matrix_refresh(void);

#ifdef __cplusplus
#if __cplusplus
}
#endif
#endif

#endif /* LIGHT_H */
