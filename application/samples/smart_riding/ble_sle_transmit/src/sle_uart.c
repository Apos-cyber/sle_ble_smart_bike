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

#define CONFIG_SLE_UART_BUS 0

#define SLE_UART_TASK_PRIO                  28
#define SLE_UART_TASK_DURATION_MS           2000
#define SLE_UART_TASK_STACK_SIZE            0x1200
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

static void sle_uart_server_read_int_handler(const void *buffer, uint16_t length, bool error)
{
    unused(error);
    char* buffer_cpy = (char*)osal_vmalloc(length + 1);
    if (memcpy_s(buffer_cpy, length + 1, buffer, length) != EOK) {
        osal_vfree(buffer_cpy);
        return;
    }
    buffer_cpy[length] = '\0'; // 确保字符串以 null 结尾
    if(strncmp((const char *)buffer_cpy, "ble", 3) == 0)//匹配开头
    {
        osal_printk("%s receive uart data for ble : %s\r\n", SLE_UART_SERVER_LOG, buffer_cpy);
        ble_uart_server_send_input_report((uint8_t *)buffer_cpy+4, length-4);
    }
    else if(strncmp((const char *)buffer_cpy, "sle", 3) == 0)
    {
        if(buffer_cpy[4]=='1') 
        {
            osal_printk("start seek!!!\r\n");
            sle_start_seek();
        } 
        else if(buffer_cpy[4]=='0') 
        {
            osal_printk("stop seek!!!\r\n");
            sle_stop_seek();
        }
        osal_printk("%s receive uart data for sle : %s\r\n", SLE_UART_SERVER_LOG, buffer_cpy);
        if (sle_uart_client_is_connected()) {
            sle_uart_server_send_report_by_handle((uint8_t *)buffer_cpy+4, length-4);
        } else {
            osal_printk("%s sle client is not connected! \r\n", SLE_UART_SERVER_LOG);
        }
    }
    else
    {
        osal_printk("%s invalid uart data! \r\n", SLE_UART_SERVER_LOG);
        osal_printk("please input data start with \"ble\" or \"sle\"! \r\n");
    }
    osal_vfree(buffer_cpy);
}

static void sle_uart_server_create_msgqueue(void)
{
    if (osal_msg_queue_create("sle_uart_server_msgqueue", SLE_UART_SERVER_MSG_QUEUE_LEN, \
        (unsigned long *)&g_sle_uart_server_msgqueue_id, 0, SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE) != OSAL_SUCCESS) {
        osal_printk("^%s sle_uart_server_create_msgqueue message queue create failed!\n", SLE_UART_SERVER_LOG);
    }
}

static void sle_uart_server_delete_msgqueue(void)
{
    osal_msg_queue_delete(g_sle_uart_server_msgqueue_id);
}

static void sle_uart_server_write_msgqueue(uint8_t *buffer_addr, uint16_t buffer_size)
{
    int msg_ret = osal_msg_queue_write_copy(g_sle_uart_server_msgqueue_id, (void *)buffer_addr,
        (uint32_t)buffer_size, 0);
    if (msg_ret != OSAL_SUCCESS) {
        osal_printk("msg queue write copy fail.");
        osal_vfree(buffer_addr);
    }
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


static void sle_uart_client_sample_seek_result_info_cbk(sle_seek_result_info_t *seek_result_data)
{
    if (seek_result_data == NULL || seek_result_data->data == NULL) {
        osal_printk("status error\r\n");
    } else if (strncmp((const char *)seek_result_data->addr.addr, (const char *)target_sle_scan_addr, SLE_ADDR_LEN) == 0) {
        for(uint8_t i = 0; i < seek_result_data->data_length; i++) {
            osal_printk("%02x ", seek_result_data->data[i]);
        }
        osal_printk("\n");
        // sle_stop_seek();
    }
}

static void sle_uart_client_sample_seek_cbk_register(void)
{
    sle_announce_seek_callbacks_t sle_uart_seek_cbk = { 0 };
    sle_uart_seek_cbk.seek_result_cb = sle_uart_client_sample_seek_result_info_cbk;
    sle_announce_seek_register_callbacks(&sle_uart_seek_cbk);
}




/* SLE Server Task */
void *sle_uart_server_task(const char *arg)
{
    unused(arg);
    sle_dev_register_cbks();

    uint8_t rx_buf[SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE] = {0};
    uint32_t rx_length = SLE_UART_SERVER_MSG_QUEUE_MAX_SIZE;
    uint8_t sle_connect_state[] = "sle_dis_connect";

    sle_uart_server_create_msgqueue();
    sle_uart_server_register_msg(sle_uart_server_write_msgqueue);
    sle_uart_server_init(ssaps_server_read_request_cbk, ssaps_server_write_request_cbk);

    sle_uart_client_sample_seek_cbk_register();

    sle_uart_start_scan();

    sle_uart_server_adv_init();

    uint8_t control_led_open[] = CTRL_LED_OPEN;
    uint8_t open_addr[6] = { 0x22, 0x00, 0x00, 0x00, 0x00, 0x00 };
    uint8_t control_led_close[] = CTRL_LED_CLOSE;
    uint8_t close_addr[6] = { 0x33, 0x00, 0x00, 0x00, 0x00, 0x00 };
    sle_control_device_adv(open_addr, control_led_open, 2);
    sle_control_device_adv(close_addr, control_led_close, 3);
    errcode_t ret;
    ret = uapi_uart_register_rx_callback(CONFIG_SLE_UART_BUS,
                                                   UART_RX_CONDITION_FULL_OR_SUFFICIENT_DATA_OR_IDLE,
                                                   1, sle_uart_server_read_int_handler);
    if (ret != ERRCODE_SUCC) {
        osal_printk("%s Register uart callback fail.[%x]\r\n", SLE_UART_SERVER_LOG, ret);
        return NULL;
    }

    while (1) {
        sle_uart_server_rx_buf_init(rx_buf, &rx_length);
        sle_uart_server_receive_msgqueue(rx_buf, &rx_length);
        if (strncmp((const char *)rx_buf, (const char *)sle_connect_state, sizeof(sle_connect_state)) == 0) {
            ret = sle_start_announce(SLE_ADV_HANDLE_DEFAULT);
            if (ret != ERRCODE_SLE_SUCCESS) {
                osal_printk("%s sle_connect_state_changed_cbk,sle_start_announce fail :%02x\r\n",
                    SLE_UART_SERVER_LOG, ret);
            }
        }

        sle_read_remote_device_rssi(get_connect_id());
        osal_msleep(SLE_UART_TASK_DURATION_MS);
    }
    sle_uart_server_delete_msgqueue();
    return NULL;
}
