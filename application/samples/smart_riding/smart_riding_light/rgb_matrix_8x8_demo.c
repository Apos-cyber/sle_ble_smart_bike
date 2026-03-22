/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: RGB Matrix 8x8 (WS2812B) Driver Sample using SPI. \n
 *
 * History:
 * 2023-04-03, Create file.
 * 2026-03-20, Rewrite to use SPI driver for accurate timing.
 */
#include "pinctrl.h"
#include "spi.h"
#include "soc_osal.h"
#include "app_init.h"
#include "osal_debug.h"
#include "rgb_matrix_patterns.h"
#include "rgb_matrix_8x8.h"

/*============================================================================
 * WS2812B SPI 配置
 *
 * SPI 8MHz, 每个bit对应 WS2812B 的一个bit:
 *   WS2812B "0" = 0xC0 (11000000b) - 高电平时间短
 *   WS2812B "1" = 0xFC (11111100b) - 高电平时间长
 *============================================================================*/

/* RGB Matrix 配置 */
#define RGB_MATRIX_SPI_BUS SPI_BUS_1
#define RGB_MATRIX_SPI_CLK_PIN 25 /* IO0 - SPI1_CLK */
#define RGB_MATRIX_SPI_CS_PIN 26  /* IO1 - SPI1_CS (GPIO模拟) */
#define RGB_MATRIX_SPI_MOSI_PIN 1 /* IO2 - SPI1_TXD -> WS2812B DIN */

#define RGB_MATRIX_SPI_FREQ_MHZ 8                      /* SPI 8MHz */
#define SPI_BUFFER_SIZE (RGB_MATRIX_PIXELS * 24 + 100) /* 64像素 * 24bit + 复位 */

#define WS2812_BIT_0 0xC0 /* 0位: 高电平时间短 */
#define WS2812_BIT_1 0xFC /* 1位: 高电平时间长 */
#define WS2812_RESET 0x00 /* 复位 */

/* 任务参数 */
#define RGB_MATRIX_TASK_PRIO 24
#define RGB_MATRIX_TASK_STACK_SIZE 0x1000

/* 全局像素数据缓冲区 (G-R-B顺序) - 供图案文件使用 */
uint8_t g_pixels[RGB_MATRIX_PIXELS][3] = {{0}};
static uint8_t g_spi_buffer[SPI_BUFFER_SIZE];

/* 分块发送，每块最大 bytes */
#define SPI_CHUNK_SIZE 800

/*============================================================================
 * SPI 初始化
 *============================================================================*/
static errcode_t rgb_matrix_spi_init(void)
{
    errcode_t ret;

    /* 配置SPI引脚 */
    ret = uapi_pin_set_mode(RGB_MATRIX_SPI_CLK_PIN, HAL_PIO_SPI1_CLK);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[RGB] CLK pin failed: %d\r\n", ret);
        return ret;
    }

    ret = uapi_pin_set_mode(RGB_MATRIX_SPI_CS_PIN, HAL_PIO_SPI1_CS1);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[RGB] CS pin failed: %d\r\n", ret);
        return ret;
    }

    ret = uapi_pin_set_mode(RGB_MATRIX_SPI_MOSI_PIN, HAL_PIO_SPI1_TXD);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[RGB] MOSI pin failed: %d\r\n", ret);
        return ret;
    }

    /* 设置MOSI引脚驱动强度 */
    uapi_pin_set_ds(RGB_MATRIX_SPI_MOSI_PIN, 3);

    /* SPI配置 */
    spi_attr_t config = {0};
    spi_extra_attr_t ext_config = {0};

    config.is_slave = false;
    config.slave_num = 1;
    config.bus_clk = 32000000;                 /* 32MHz 总线时钟 */
    config.freq_mhz = RGB_MATRIX_SPI_FREQ_MHZ; /* 8MHz SPI */
    config.clk_polarity = SPI_CFG_CLK_CPOL_0;  /* 时钟极性 */
    config.clk_phase = SPI_CFG_CLK_CPHA_0;     /* 时钟相位 */
    config.frame_format = SPI_CFG_FRAME_FORMAT_MOTOROLA_SPI;
    config.spi_frame_format = HAL_SPI_FRAME_FORMAT_STANDARD;
    config.frame_size = HAL_SPI_FRAME_SIZE_8; /* 8位数据 */
    config.tmod = HAL_SPI_TRANS_MODE_TX;      /* 只发送 */
    config.sste = 0;
    ext_config.qspi_param.wait_cycles = 0x10;

    ret = uapi_spi_init(RGB_MATRIX_SPI_BUS, &config, &ext_config);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[RGB] SPI init failed: %d\r\n", ret);
        return ret;
    }

    osal_printk("[RGB] SPI init success\r\n");
    return ERRCODE_SUCC;
}

/*============================================================================
 * 刷新像素数据到LED矩阵 (分块传输)
 *============================================================================*/
void rgb_matrix_refresh(void)
{
    uint32_t pos = 0;

    /* 生成所有像素数据 */
    for (int i = 0; i < RGB_MATRIX_PIXELS; i++) {
        uint8_t g = g_pixels[i][0];
        uint8_t r = g_pixels[i][1];
        uint8_t b = g_pixels[i][2];

        /* WS2812B 要求 GRB 顺序 */
        uint8_t colors[3] = {g, r, b};

        for (int color_idx = 0; color_idx < 3; color_idx++) {
            uint8_t color_byte = colors[color_idx];

            for (int bit = 7; bit >= 0; bit--) {
                if ((color_byte >> bit) & 1) {
                    g_spi_buffer[pos] = WS2812_BIT_1;
                } else {
                    g_spi_buffer[pos] = WS2812_BIT_0;
                }
                pos++;
            }
        }
    }

    uint32_t total_data_bytes = pos;

    /* 分块发送数据 */
    uint32_t sent = 0;
    while (sent < total_data_bytes) {
        uint32_t chunk = total_data_bytes - sent;
        if (chunk > SPI_CHUNK_SIZE) {
            chunk = SPI_CHUNK_SIZE;
        }

        spi_xfer_data_t xfer = {.tx_buff = &g_spi_buffer[sent],
                                .tx_bytes = chunk,
                                .rx_buff = NULL,
                                .rx_bytes = 0};

        errcode_t ret = uapi_spi_master_write(RGB_MATRIX_SPI_BUS, &xfer, 1000);
        if (ret != ERRCODE_SUCC) {
            osal_printk("[RGB] Chunk failed at %d: 0x%x\r\n", sent, ret);
            return;
        }

        sent += chunk;

        /* 块之间短暂延时 */
        for (volatile int dly = 0; dly < 50; dly++) {
        }
    }

    /* 发送复位信号 */
    for (int i = 0; i < 50; i++) {
        g_spi_buffer[i] = WS2812_RESET;
    }
    spi_xfer_data_t xfer_reset = {.tx_buff = g_spi_buffer, .tx_bytes = 50, .rx_buff = NULL, .rx_bytes = 0};
    uapi_spi_master_write(RGB_MATRIX_SPI_BUS, &xfer_reset, 1000);
}

/*============================================================================
 * RGB Matrix 主任务
 *============================================================================*/
static int rgb_matrix_task(const char *arg)
{
    UNUSED(arg);

    errcode_t ret = rgb_matrix_spi_init();
    if (ret != ERRCODE_SUCC) {
        osal_printk("[RGB] Init failed: %d\r\n", ret);
        return -1;
    }

    osal_printk("[RGB] RGB Matrix 8x8 demo start, SPI Bus=%d, MOSI=IO%d\r\n", RGB_MATRIX_SPI_BUS,
                RGB_MATRIX_SPI_MOSI_PIN);

    rgb_matrix_refresh();
    osal_msleep(100);

    while (1) {
        osal_printk("[RGB] Show Circle (Orange)\r\n");
        rgb_matrix_show_circle(COLOR_ORANGE);
        osal_msleep(2000);

        osal_printk("[RGB] Show Arrow Up (Cyan)\r\n");
        rgb_matrix_show_arrow_up(COLOR_CYAN);
        osal_msleep(2000);

        osal_printk("[RGB] Show Arrow Down (Magenta)\r\n");
        rgb_matrix_show_arrow_down(COLOR_MAGENTA);
        osal_msleep(2000);

        osal_printk("[RGB] Show Arrow Left (Yellow)\r\n");
        rgb_matrix_show_arrow_left(COLOR_YELLOW);
        osal_msleep(2000);

        osal_printk("[RGB] Show Arrow Right (Purple)\r\n");
        rgb_matrix_show_arrow_right(COLOR_PURPLE);
        osal_msleep(2000);
    }

    return 0;
}

static void rgb_matrix_entry(void)
{
    osal_task *task_handle = NULL;

    osal_kthread_lock();
    task_handle =
        osal_kthread_create((osal_kthread_handler)rgb_matrix_task, 0, "RgbMatrixTask", RGB_MATRIX_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, RGB_MATRIX_TASK_PRIO);
    }
    osal_kthread_unlock();
}

app_run(rgb_matrix_entry);
