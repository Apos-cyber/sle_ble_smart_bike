/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: SLE UART Sample Source. \
 *
 * History:
 * 2023-07-17, Create file.
 */
#include "common_def.h"
#include "soc_osal.h"
#include "app_init.h"
#include "uart.h"
#include "pm_clock.h"
#include "securec.h"
#include "sle_uart_server.h"
#include "sle_uart_server_adv.h"
#include "sle_device_discovery.h"
#include "sle_connection_manager.h"
#include "sle_ssap_client.h"
#include "sle_errcode.h"
#include "sle_uart.h"
#include "sle_client.h"

#include "ble_uart_server.h"
#include "bike_ctrl.h"

#include "ble_uart_server.h"
#include "bts_device_manager.h"
#include "sle_device_manager.h"

#define CONFIG_SLE_UART_BUS 0

#define SLE_UART_TASK_PRIO                  28
#define SLE_UART_TASK_DURATION_MS           2000
#define SLE_UART_TASK_STACK_SIZE            0x800
#define SLE_ADV_HANDLE_DEFAULT              1
#define SLE_UART_SERVER_MSG_QUEUE_LEN       5
#define SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE  32
#define SLE_UART_SERVER_QUEUE_DELAY         0xFFFFFFFF
#define SLE_UART_SERVER_BUFF_MAX_SIZE       800
#define SLE_UART_SERVER_SEND_BUFF_MAX_LEN   40
#define SLE_UART_SSAPC_PRINTF_LOG_INTERVAL 50

// static uint16_t g_ssapc_recv_pkts = 0;
unsigned long g_sle_uart_server_msgqueue_id;
#define SLE_UART_SERVER_LOG                 "[sle uart server]"
uint8_t target_sle_scan_addr[6] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
static volatile uint8_t g_sle_msgqueue_ready = 0;

/* BLE/SLE 同步标志：BLE初始化完成置1 */
extern volatile uint8_t g_ble_init_done;

/* SLE Server functions */
static void ssaps_server_read_request_cbk(uint8_t server_id, uint16_t conn_id, ssaps_req_read_cb_t *read_cb_para,
    errcode_t status)
{
    osal_printk("%s ssaps read request cbk callback server_id:0x%x, conn_id:0x%x, handle:0x%x, status:0x%x\r\n",
        SLE_UART_SERVER_LOG, server_id, conn_id, read_cb_para->handle, status);
}

static void ssaps_server_write_request_cbk(uint8_t server_id, uint16_t conn_id, ssaps_req_write_cb_t *write_cb_para,
    errcode_t status)
{
    osal_printk("%s ssaps write request callback cbk server_id:0x%x, conn_id:0x%x, handle:0x%x, status:0x%x\r\n",
        SLE_UART_SERVER_LOG, server_id, conn_id, write_cb_para->handle, status);
    if ((write_cb_para->length > 0) && write_cb_para->value) {
        uapi_uart_write(CONFIG_SLE_UART_BUS, (uint8_t *)write_cb_para->value, write_cb_para->length, 0);
    }
}


static void process_sle_queue_data(uint8_t *buffer_addr, uint32_t buffer_size)
{
    bike_ctrl_dispatch(buffer_addr, buffer_size, BIKE_CTRL_SOURCE_SLE);
}

static void sle_uart_client_sample_seek_cbk_register(void)
{
    sle_announce_seek_callbacks_t sle_uart_seek_cbk = { 0 };
    // sle_uart_seek_cbk.seek_result_cb = sle_uart_client_sample_seek_result_info_cbk;
    sle_announce_seek_register_callbacks(&sle_uart_seek_cbk);
}


static void sle_uart_server_create_msgqueue(void)
{
    if (osal_msg_queue_create("sle_uart_server_msgqueue", SLE_UART_SERVER_MSG_QUEUE_LEN, \
        (unsigned long *)&g_sle_uart_server_msgqueue_id, 0, SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE) != OSAL_SUCCESS) {
        osal_printk("^%s sle_uart_server_create_msgqueue message queue create failed!\n", SLE_UART_SERVER_LOG);
        g_sle_msgqueue_ready = 0;
        return;
    }
    g_sle_msgqueue_ready = 1;
}

static void sle_uart_server_write_msgqueue(uint8_t *buffer_addr, uint16_t buffer_size)
{
    if (g_sle_msgqueue_ready == 0) {
        osal_printk("%s msg queue not ready, drop msg.\r\n", SLE_UART_SERVER_LOG);
        osal_vfree(buffer_addr);
        return;
    }

    int msg_ret = osal_msg_queue_write_copy(g_sle_uart_server_msgqueue_id, (void *)buffer_addr,
        (uint32_t)buffer_size, 0);
    if (msg_ret != OSAL_SUCCESS) {
        osal_printk("msg queue write copy fail.");
        osal_vfree(buffer_addr);
    }
}

void init_sle(void)
{
    static uint8_t sle_registered = 0;

    if (sle_registered == 0) {
        sle_dev_register_cbks();
        sle_uart_server_init(ssaps_server_read_request_cbk, ssaps_server_write_request_cbk);
        sle_uart_client_sample_seek_cbk_register();
        sle_registered = 1;
    } else {
        enable_sle();
    }

    if (g_sle_msgqueue_ready == 0) {
        sle_uart_server_create_msgqueue();
    }
    sle_uart_server_register_msg(sle_uart_server_write_msgqueue);
    sle_uart_server_adv_init();
}


typedef enum {
    SWITCH_NONE = 0,
    SWITCH_TO_BLE,
    SWITCH_TO_SLE
} switch_mode_t;

typedef enum {
    RUN_MODE_NONE = 0,
    RUN_MODE_BLE,
    RUN_MODE_SLE
} run_mode_t;

volatile switch_mode_t g_switch_mode = SWITCH_NONE;
static volatile run_mode_t g_current_mode = RUN_MODE_NONE;

static void sle_uart_server_read_int_handler(const void *buffer, uint16_t length, bool error)
{
    unused(error);

    if (buffer == NULL || length == 0) {
        return;
    }

    char *buffer_cpy = (char *)osal_vmalloc(length + 1);
    if (buffer_cpy == NULL) {
        osal_printk("malloc failed\r\n");
        return;
    }

    if (memcpy_s(buffer_cpy, length + 1, buffer, length) != EOK) {
        osal_vfree(buffer_cpy);
        return;
    }
    buffer_cpy[length] = '\0';

    osal_printk("buffer_cpy:%s\r\n",buffer_cpy);

    if (length >= 3 && strncmp(buffer_cpy, "ble", 3) == 0) {
        osal_printk("ble_mode\r\n");
        if (g_current_mode != RUN_MODE_BLE) {
            g_switch_mode = SWITCH_TO_BLE;
        }
    } else if (length >= 3 && strncmp(buffer_cpy, "sle", 3) == 0) {
        osal_printk("sle_mode\r\n");
        if (g_current_mode != RUN_MODE_SLE) {
            g_switch_mode = SWITCH_TO_SLE;
        }
    } else {
        osal_printk("invalid uart data\r\n");
    }

    osal_vfree(buffer_cpy);
}



static void sle_uart_server_delete_msgqueue(void)
{
    if (g_sle_msgqueue_ready == 0) {
        return;
    }
    osal_msg_queue_delete(g_sle_uart_server_msgqueue_id);
    g_sle_msgqueue_ready = 0;
}



static int32_t sle_uart_server_receive_msgqueue(uint8_t *buffer_addr, uint32_t *buffer_size)
{
    return osal_msg_queue_read_copy(g_sle_uart_server_msgqueue_id, (void *)buffer_addr, \
                                    buffer_size, SLE_UART_SERVER_QUEUE_DELAY);
}

static void sle_uart_server_rx_buf_init(uint8_t *buffer_addr, uint32_t *buffer_size)
{
    *buffer_size = SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE;
    (void)memset_s(buffer_addr, *buffer_size, 0, *buffer_size);
}



void sle_uart_start_scan(void)
{
    sle_seek_param_t param = { 0 };
    param.own_addr_type = 0;
    param.filter_duplicates = 0;
    param.seek_filter_policy = 0;
    param.seek_phys = 1;
    param.seek_type[0] = 1;
    param.seek_interval[0] = 100;
    param.seek_window[0] = 100;
    sle_set_seek_param(&param);
    sle_start_seek();
}


// static void sle_uart_client_sample_seek_result_info_cbk(sle_seek_result_info_t *seek_result_data)
// {
//     if (seek_result_data == NULL || seek_result_data->data == NULL) {
//         osal_printk("status error\r\n");
//     } else if (strncmp((const char *)seek_result_data->addr.addr, (const char *)target_sle_scan_addr, SLE_ADDR_LEN) == 0) {
//     // } else {
//         for(uint8_t i = 0; i < seek_result_data->data_length; i++) {
//             osal_printk("%02x ", seek_result_data->data[i]);
//         }
//         osal_printk("\n");
//         sle_stop_seek();
//     }
// }


void *mode_change_task(void)
{
    g_switch_mode = SWITCH_TO_BLE;

    while(1)
    {
        if (g_switch_mode == SWITCH_TO_BLE) {
            g_switch_mode = SWITCH_NONE;
            if (g_current_mode == RUN_MODE_BLE) {
                osal_msleep(10);
                continue;
            }

            if (g_current_mode == RUN_MODE_SLE) {
                sle_uart_server_delete_msgqueue();
                disable_sle();
                osal_printk("disable_sle\r\n");
                osal_msleep(500);
            }
            ble_uart_server_init();
            g_current_mode = RUN_MODE_BLE;
        } else if (g_switch_mode == SWITCH_TO_SLE) {
            g_switch_mode = SWITCH_NONE;
            if (g_current_mode == RUN_MODE_SLE) {
                osal_msleep(10);
                continue;
            }

            if (g_current_mode == RUN_MODE_BLE) {
                ble_uart_server_deinit();
                disable_ble();
                osal_printk("disable_ble\r\n");
                osal_msleep(500);
            }
            init_sle();
            g_current_mode = RUN_MODE_SLE;
        }
        osal_msleep(10);
    }
}


/* SLE Server Task */
void *sle_uart_server_task(const char *arg)
{
    unused(arg);

    // init_sle();

    uint8_t rx_buf[SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE] = {0};
    uint32_t rx_length = SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE;
    uint8_t sle_connect_state[] = "sle_dis_connect";

    errcode_t ret;
    ret = uapi_uart_register_rx_callback(CONFIG_SLE_UART_BUS,
                                                   UART_RX_CONDITION_FULL_OR_SUFFICIENT_DATA_OR_IDLE,
                                                   1, sle_uart_server_read_int_handler);
    if (ret != ERRCODE_SUCC) {
        osal_printk("%s Register uart callback fail.[%x]\r\n", SLE_UART_SERVER_LOG, ret);
        return NULL;
    }


    while (1) {
        if ((g_current_mode != RUN_MODE_SLE) || (g_sle_msgqueue_ready == 0)) {
            osal_msleep(20);
            continue;
        }

        sle_uart_server_rx_buf_init(rx_buf, &rx_length);
        if (sle_uart_server_receive_msgqueue(rx_buf, &rx_length) != OSAL_SUCCESS) {
            osal_msleep(20);
            continue;
        }
        if (strncmp((const char *)rx_buf, (const char *)sle_connect_state, sizeof(sle_connect_state)) == 0) {
            // ret = sle_start_announce(SLE_ADV_HANDLE_DEFAULT);
            if (ret != ERRCODE_SLE_SUCCESS) {
                osal_printk("%s sle_connect_state_changed_cbk,sle_start_announce fail :%02x\r\n",
                    SLE_UART_SERVER_LOG, ret);
            }
        }
        else {
            osal_printk("%s receive uart data from msgqueue: %s\r\n", SLE_UART_SERVER_LOG, rx_buf);
            process_sle_queue_data(rx_buf, rx_length);
        }

        // sle_read_remote_device_rssi(get_connect_id());
        // osal_msleep(SLE_UART_TASK_DURATION_MS);
    }
    sle_uart_server_delete_msgqueue();
    return NULL;
}
