/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: BLE UART Sample Source. \
 *
 * History:
 * 2023-07-20, Create file.
 */
#include "securec.h"
#include "common_def.h"
#include "soc_osal.h"
#include "app_init.h"
#include "uart.h"
#include "bts_gatt_server.h"
#include "ble_uart_server.h"
#include "ble_uart.h"
#include "bts_le_gap.h"
#include "bts_device_manager.h"


#define BLE_UART_BT_STACK_POWER_MS      10000

typedef struct {
    uint8_t *value;
    uint16_t value_len;
} msg_data_t;
unsigned long mouse_msg_queue = 0;
unsigned int msg_rev_size = sizeof(msg_data_t);

void ble_uart_read_int_handler(const void *buffer, uint16_t length, bool error)
{
    osal_printk("ble_uart_read_int_handler server.\r\n");
    unused(error);
    if (ble_uart_get_connection_state() != 0) {
        msg_data_t msg_data = { 0 };
        void* buffer_cpy = osal_vmalloc(length);
        if (memcpy_s(buffer_cpy, length, buffer, length) != EOK) {
            osal_vfree(buffer_cpy);
            return;
        }
        msg_data.value = (uint8_t *)buffer_cpy;
        msg_data.value_len = length;
        int msg_ret = osal_msg_queue_write_copy(mouse_msg_queue, (void *)&msg_data, msg_rev_size, 0);
        if (msg_ret != OSAL_SUCCESS) {
            osal_printk("msg queue write copy fail.");
            osal_vfree(msg_data.value);
        }
    }
}

void *ble_uart_server_task(const char *arg)
{
    unused(arg);

    int msg_ret = osal_msg_queue_create("task_msg", msg_rev_size, &mouse_msg_queue, 0, msg_rev_size);
    if (msg_ret != OSAL_SUCCESS) {
        osal_printk("msg queue create fail.");
    }

    ble_uart_server_init();
    // errcode_t ret = uapi_uart_register_rx_callback(CONFIG_BLE_UART_BUS,
    //                                                UART_RX_CONDITION_FULL_OR_SUFFICIENT_DATA_OR_IDLE,
    //                                                1, ble_uart_read_int_handler);
    // if (ret != ERRCODE_SUCC) {
    //     osal_printk("Register uart callback fail.");
    //     return NULL;
    // }
    while (1) {
        msg_data_t msg_data = { 0 };
        int msg_ret = osal_msg_queue_read_copy(mouse_msg_queue, &msg_data, &msg_rev_size, OSAL_WAIT_FOREVER);
        if (msg_ret != OSAL_SUCCESS) {
            osal_printk("msg queue read copy fail.");
            if (msg_data.value != NULL) {
                osal_vfree(msg_data.value);
            }
            continue;
        }
        if (msg_data.value != NULL) {
            ble_uart_server_send_input_report(msg_data.value, msg_data.value_len);
            osal_vfree(msg_data.value);
        }
        // gap_ble_read_remote_device_rssi(ble_get_conn_id());
        // osal_msleep(5000);
    }
    return NULL;
}
