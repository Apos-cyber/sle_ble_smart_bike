/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: Buzzer Sample Source (Passive Buzzer with Timer). \n
 *
 * History: \n
 * 2023-04-03, Create file. \n
 */
#include "pinctrl.h"
#include "gpio.h"
#include "tcxo.h"
#include "soc_osal.h"
#include "app_init.h"
#include "timer.h"

/*============================================================================
 * 无源蜂鸣器驱动 - 硬件接口定义
 * 用户可根据实际硬件修改以下宏
 *===========================================================================*/

/* 蜂鸣器 GPIO 配置 - 可在 Kconfig 中配置 */
#ifndef CONFIG_SAMPLE_BUZZER_PIN
#define BUZZER_GPIO_PIN         24  /* 默认 GPIO24 */
#else
#define BUZZER_GPIO_PIN         CONFIG_SAMPLE_BUZZER_PIN
#endif

/*============================================================================
 * 旋律定义 - 音符频率 (Hz)
 * 无源蜂鸣器通过 GPIO 翻转产生不同频率
 *============================================================================*/

/* 音符频率定义 */
#define NOTE_REST       0
#define NOTE_G3         196     /* G3 */
#define NOTE_A3         220     /* A3 */
#define NOTE_B3         247     /* B3 */
#define NOTE_C4         262     /* C4 */
#define NOTE_D4         294     /* D4 */
#define NOTE_E4         330     /* E4 */
#define NOTE_F4         349     /* F4 */
#define NOTE_FS4        370     /* F#4 */
#define NOTE_G4         392     /* G4 */
#define NOTE_GS4        415     /* G#4 */
#define NOTE_A4         440     /* A4 */
#define NOTE_B4         494     /* B4 */
#define NOTE_C5         523     /* C5 */
#define NOTE_D5         587     /* D5 */
#define NOTE_E5         659     /* E5 */

/* 旋律选择 - 默认为0 */
#ifndef CONFIG_SAMPLE_BUZZER_MELODY
#define DEFAULT_MELODY  0
#else
#define DEFAULT_MELODY  CONFIG_SAMPLE_BUZZER_MELODY
#endif

/* 旋律1: 生日快乐 */
static const uint16_t g_happy_birthday[][2] = {
    {NOTE_G4, 200}, {NOTE_REST, 100}, {NOTE_G4, 200}, {NOTE_A4, 200},
    {NOTE_G4, 200}, {NOTE_REST, 100}, {NOTE_C4, 200}, {NOTE_B3, 400},
    {NOTE_G4, 200}, {NOTE_REST, 100}, {NOTE_G4, 200}, {NOTE_A4, 200},
    {NOTE_G4, 200}, {NOTE_REST, 100}, {NOTE_D4, 200}, {NOTE_C4, 400},
    {NOTE_G4, 200}, {NOTE_REST, 100}, {NOTE_G4, 200}, {NOTE_GS4, 200},
    {NOTE_E4, 200}, {NOTE_REST, 100}, {NOTE_C4, 200}, {NOTE_B3, 200},
    {NOTE_A4, 200}, {NOTE_REST, 100}, {NOTE_FS4, 200}, {NOTE_F4, 200},
    {NOTE_E4, 200}, {NOTE_REST, 100}, {NOTE_D4, 200}, {NOTE_C4, 800},
};

/* 旋律2: 玛丽有只小羊羔 */
static const uint16_t g_mary_lamb[][2] = {
    {NOTE_E4, 200}, {NOTE_D4, 200}, {NOTE_C4, 200}, {NOTE_D4, 200},
    {NOTE_E4, 200}, {NOTE_E4, 200}, {NOTE_E4, 400},
    {NOTE_D4, 200}, {NOTE_D4, 200}, {NOTE_D4, 400},
    {NOTE_E4, 200}, {NOTE_G4, 200}, {NOTE_G4, 400},
    {NOTE_E4, 200}, {NOTE_D4, 200}, {NOTE_C4, 200}, {NOTE_D4, 200},
    {NOTE_E4, 200}, {NOTE_E4, 200}, {NOTE_E4, 200}, {NOTE_E4, 400},
    {NOTE_D4, 200}, {NOTE_D4, 200}, {NOTE_E4, 200}, {NOTE_D4, 200},
    {NOTE_C4, 800},
};

/* 旋律3: 简单测试音阶 */
static const uint16_t g_simple_test[][2] = {
    {NOTE_C4, 300}, {NOTE_REST, 100},
    {NOTE_D4, 300}, {NOTE_REST, 100},
    {NOTE_E4, 300}, {NOTE_REST, 100},
    {NOTE_F4, 300}, {NOTE_REST, 100},
    {NOTE_G4, 300}, {NOTE_REST, 100},
    {NOTE_A4, 300}, {NOTE_REST, 100},
    {NOTE_B4, 300}, {NOTE_REST, 100},
    {NOTE_C5, 300}, {NOTE_REST, 100},
};

#define BUZZER_TASK_PRIO        24
#define BUZZER_TASK_STACK_SIZE  0x1000
#define MELODY_INTERVAL_MS      500   /* 旋律间隔时间 */

/* 当前播放状态 */
static volatile uint16_t g_current_freq = 0;
static volatile bool g_buzzer_on = false;
static uint8_t g_melody_sel = 0;

/* 获取旋律数据和长度 */
static void buzzer_get_melody(uint8_t melody_sel, const uint16_t **melody, uint16_t *len)
{
    switch (melody_sel) {
        case 1:
            *melody = &g_mary_lamb[0][0];
            *len = sizeof(g_mary_lamb) / sizeof(g_mary_lamb[0]);
            break;
        case 2:
            *melody = &g_simple_test[0][0];
            *len = sizeof(g_simple_test) / sizeof(g_simple_test[0]);
            break;
        case 0:
        default:
            *melody = &g_happy_birthday[0][0];
            *len = sizeof(g_happy_birthday) / sizeof(g_happy_birthday[0]);
            break;
    }
}

/* 播放单个音符 - 使用延时方式 */
static void buzzer_play_note(uint16_t freq, uint16_t duration)
{
    if (freq == NOTE_REST) {
        /* 停止蜂鸣器 */
        uapi_gpio_set_val(BUZZER_GPIO_PIN, GPIO_LEVEL_LOW);
        osal_msleep(duration);
        return;
    }

    /* 计算半周期延时 (us) = 1000000 / (freq * 2) */
    uint32_t half_period_us = 500000 / freq;

    /* 持续指定时长 */
    uint32_t loops = duration * 1000 / (half_period_us * 2);
    for (uint32_t i = 0; i < loops; i++) {
        uapi_gpio_set_val(BUZZER_GPIO_PIN, GPIO_LEVEL_HIGH);
        osal_udelay(half_period_us);
        uapi_gpio_set_val(BUZZER_GPIO_PIN, GPIO_LEVEL_LOW);
        osal_udelay(half_period_us);
    }

    /* 音符间隔 */
    osal_msleep(50);
}

/* 播放指定旋律 */
static void buzzer_play_melody(const uint16_t *melody, uint16_t len)
{
    uint16_t i;

    for (i = 0; i < len; i++) {
        buzzer_play_note(melody[i * 2], melody[i * 2 + 1]);
    }
}

static int buzzer_task(const char *arg)
{
    const uint16_t *melody = NULL;
    uint16_t len = 0;

    UNUSED(arg);

    /* 设置 GPIO 复用为 GPIO 功能 */
    uapi_pin_set_mode(BUZZER_GPIO_PIN, HAL_PIO_FUNC_GPIO);

    /* 设置 GPIO 方向为输出 */
    uapi_gpio_set_dir(BUZZER_GPIO_PIN, GPIO_DIRECTION_OUTPUT);

    /* 初始关闭蜂鸣器 */
    uapi_gpio_set_val(BUZZER_GPIO_PIN, GPIO_LEVEL_LOW);

    osal_printk("Buzzer demo start, GPIO=%d, melody=%d\r\n", BUZZER_GPIO_PIN, g_melody_sel);

    while (1) {
        /* 获取旋律数据 */
        buzzer_get_melody(g_melody_sel, &melody, &len);

        /* 播放旋律 */
        buzzer_play_melody(melody, len);

        /* 旋律间隔 */
        osal_msleep(MELODY_INTERVAL_MS);
    }

    return 0;
}

static void buzzer_entry(void)
{
    osal_task *task_handle = NULL;

    g_melody_sel = DEFAULT_MELODY;

    osal_kthread_lock();
    task_handle = osal_kthread_create((osal_kthread_handler)buzzer_task,
                                       0,
                                       "BuzzerTask",
                                       BUZZER_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, BUZZER_TASK_PRIO);
    }
    osal_kthread_unlock();
}

/* Run the buzzer_entry. */
app_run(buzzer_entry);
