/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: BLE uart server Config. \n
 *
 * History: \n
 * 2023-07-26, Create file. \n
 */
#ifndef BLE_UART_SERVER_H
#define BLE_UART_SERVER_H

#include <stdint.h>
#include "errcode.h"

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif /* __cplusplus */
#endif /* __cplusplus */

/* Service UUID */
#define BLE_UART_UUID_SERVER_SERVICE 0xABCD

#define BLE_BATTERY_SERVICE          0x180F//电池电量检测

#define BLE_AUTOMATION_IO_SERVICE          0x1815//车锁相关的控制
/* Characteristic UUID */
#define BLE_UART_CHARACTERISTIC_UUID_TX 0xCDEF
/* Characteristic UUID */
#define BLE_UART_CHARACTERISTIC_UUID_RX 0xEFEF
/* Client Characteristic Configuration UUID */
#define BLE_UART_CLIENT_CHARACTERISTIC_CONFIGURATION 0x2902

#define CONFIG_BLE_UART_BUS 0   

void ble_uart_set_device_name_value(const uint8_t *name, const uint8_t len);
void ble_uart_set_device_appearance_value(uint16_t appearance);
void ble_uart_server_init(void);
errcode_t ble_uart_server_send_input_report(uint8_t *data, uint16_t len);
uint16_t ble_get_conn_id(void);
uint8_t ble_uart_get_connection_state(void);

#ifdef __cplusplus
#if __cplusplus
}
#endif  /* __cplusplus */
#endif  /* __cplusplus */
#endif