#ifndef BUZZER_H
#define BUZZER_H

#include <stdint.h>
#include "errcode.h"

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif /* __cplusplus */
#endif /* __cplusplus */

/* 蜂鸣器旋律选择枚举 */
typedef enum {
    BUZZER_MELODY_HAPPY_BIRTHDAY = 0,  /* 生日快乐 */
    BUZZER_MELODY_MARY_LAMB = 1,       /* 玛丽有只小羊羔 */
    BUZZER_MELODY_SIMPLE_TEST = 2,     /* 简单测试音阶 */
    BUZZER_MELODY_ALARM = 3,           /* 警报音效 */
} buzzer_melody_t;

/**
 * @brief 播放指定旋律
 * @param melody 要播放的旋律 (buzzer_melody_t 枚举值)
 */
void buzzer_play_melody(buzzer_melody_t melody);

/**
 * @brief 播放警报音效 (便捷函数，等同于 buzzer_play_melody(BUZZER_MELODY_ALARM))
 */
void buzzer_play_alarm(void);

/**
 * @brief 停止当前播放的警报/旋律
 */
void buzzer_stop_alarm(void);

/**
 * @brief 蜂鸣器初始化 (默认GPIO24，如需修改在Kconfig或代码中配置)
 */
void buzzer_init(void);

/* 原有RSSI回调声明 */
void ble_server_print_rssi_cbk(uint16_t conn_id, int8_t rssi, errcode_t status);
void sle_server_print_rssi_cbk(uint16_t conn_id, int8_t rssi, errcode_t status);

#ifdef __cplusplus
#if __cplusplus
}
#endif /* __cplusplus */
#endif /* __cplusplus */

#endif /* BUZZER_H */
