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
#include "buzzer.h"
#include "light.h"
#include "gpio.h"
#include "pinctrl.h"

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

/* 车锁定时器 (避免任务栈阻塞) */
static osal_timer g_lock_timer;
static uint8_t g_lock_final_state = 0; /* 0=LOW, 1=HIGH */

static void lock_timer_callback(unsigned long data)
{
    g_lock_final_state = (uint8_t)data;
    uapi_gpio_set_val(LOCK_GPIO_PIN1, g_lock_final_state ? GPIO_LEVEL_HIGH : GPIO_LEVEL_LOW);
    uapi_gpio_set_val(LOCK_GPIO_PIN2, g_lock_final_state ? GPIO_LEVEL_HIGH : GPIO_LEVEL_LOW);
    osal_printk("%s lock auto reset to %s\r\n", SLE_UART_SERVER_LOG,
                g_lock_final_state ? "HIGH" : "LOW");
}

static void lock_timer_init(void)
{
    g_lock_timer.handler = lock_timer_callback;
    g_lock_timer.data = 0;
    g_lock_timer.interval = 5000; /* 5秒 */
    osal_timer_init(&g_lock_timer);
}

static void lock_timer_start(uint8_t final_state)
{
    g_lock_timer.data = final_state;
    osal_timer_mod(&g_lock_timer, 5000);
}

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
    if (buffer_addr == NULL || buffer_size < 5) {
        osal_printk("%s invalid buffer\r\n", SLE_UART_SERVER_LOG);
        return;
    }

    // 解析协议头
    uint8_t head = buffer_addr[0];
    if (head != 0xAA) {
        osal_printk("%s invalid head: 0x%02x\r\n", SLE_UART_SERVER_LOG, head);
        return;
    }

    uint8_t flag = buffer_addr[1];
    uint8_t type = buffer_addr[2];
    uint8_t len = buffer_addr[3];

    if (buffer_size < (uint32_t)(5 + len)) {
        osal_printk("%s invalid length: buffer_size=%u, expected=%u\r\n", SLE_UART_SERVER_LOG, buffer_size, 5 + len);
        return;
    }

    // 校验帧尾
    if (buffer_addr[4 + len] != 0xBB) {
        osal_printk("%s invalid end\r\n", SLE_UART_SERVER_LOG);
        return;
    }

    // 动态分配Value数据
    uint8_t *value = (uint8_t *)osal_vmalloc(len);
    if (value == NULL) {
        osal_printk("%s malloc failed\r\n", SLE_UART_SERVER_LOG);
        return;
    }
    if (len > 0) {
        memcpy_s(value, len, &buffer_addr[4], len);
    }

    osal_printk("%s protocol: flag=0x%02x, type=0x%02x, len=%u\r\n", SLE_UART_SERVER_LOG, flag, type, len);

    // 处理命令
    switch (flag) {
        case 0x01: // 车锁
            if (len < 1) break;
            osal_printk("%s bike lock: value[0]=0x%02x\r\n", SLE_UART_SERVER_LOG, value[0]);
            if (value[0] == 0x01) {
                /* 关锁：拉低 GPIO9 GPIO10，5秒后自动恢复高 */
                osal_printk("%s lock closing (low for 5s)\r\n", SLE_UART_SERVER_LOG);
                uapi_gpio_set_val(LOCK_GPIO_PIN1, GPIO_LEVEL_LOW);
                uapi_gpio_set_val(LOCK_GPIO_PIN2, GPIO_LEVEL_LOW);
                lock_timer_start(1); /* 5秒后拉高 */
            } else if (value[0] == 0x00) {
                /* 开锁：拉高 GPIO9 GPIO10，5秒后自动恢复低 */
                osal_printk("%s lock opening (high for 5s)\r\n", SLE_UART_SERVER_LOG);
                uapi_gpio_set_val(LOCK_GPIO_PIN1, GPIO_LEVEL_HIGH);
                uapi_gpio_set_val(LOCK_GPIO_PIN2, GPIO_LEVEL_HIGH);
                lock_timer_start(0); /* 5秒后拉低 */
            }
            break;
        case 0x02: // 车灯
            osal_printk("%s bike light: value[0]=0x%02x\r\n", SLE_UART_SERVER_LOG, value[0]);
            if (len < 1) break;
            switch (value[0]) {
                case 0x00: // 关闭
                    light_off();
                    break;
                case 0x01: // 开启 - 默认橙色
                    light_on(LIGHT_COLOR_ORANGE);
                    break;
                case 0x02: // 左转灯
                    light_turn_left(LIGHT_COLOR_YELLOW);
                    break;
                case 0x03: // 右转灯
                    light_turn_right(LIGHT_COLOR_YELLOW);
                    break;
                default:
                    osal_printk("%s unknown light mode: 0x%02x\r\n", SLE_UART_SERVER_LOG, value[0]);
                    break;
            }
            break;
        case 0x03: // 寻车
            osal_printk("%s find bike\r\n", SLE_UART_SERVER_LOG);
            if(value[0] == 0x01) {
                buzzer_play_alarm();
            } else if(value[0] == 0x00) {
                buzzer_stop_alarm();
            }
            // TODO: 执行寻车操作
            break;
        case 0x04: // 重命名
            osal_printk("%s rename device\r\n", SLE_UART_SERVER_LOG);
            if (len > 0) {
                sle_set_device_name(value, len);
            }
            break;
        case 0x05: // 解绑
            osal_printk("%s unbind device\r\n", SLE_UART_SERVER_LOG);
            // TODO: 执行解绑操作
            break;
        default:
            osal_printk("%s unknown flag: 0x%02x\r\n", SLE_UART_SERVER_LOG, flag);
            break;
    }

    osal_vfree(value);
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

    lock_timer_init();

    errcode_t ret;
    ret = uapi_uart_register_rx_callback(CONFIG_SLE_UART_BUS,
                                                   UART_RX_CONDITION_FULL_OR_SUFFICIENT_DATA_OR_IDLE,
                                                   1, sle_uart_server_read_int_handler);
    if (ret != ERRCODE_SUCC) {
        osal_printk("%s Register uart callback fail.[%x]\r\n", SLE_UART_SERVER_LOG, ret);
        return NULL;
    }

    /* 等待系统完全就绪后再开始广播扫描，避免初始化未完成时连接导致崩溃 */
    osal_msleep(1000);

    sle_uart_start_scan();
    sle_uart_server_adv_init();

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
        else {
            osal_printk("%s receive uart data from msgqueue: %s\r\n", SLE_UART_SERVER_LOG, rx_buf);
            process_sle_queue_data(rx_buf, rx_length);
        }

        sle_read_remote_device_rssi(get_connect_id());
        osal_msleep(SLE_UART_TASK_DURATION_MS);
    }
    sle_uart_server_delete_msgqueue();
    return NULL;
}
