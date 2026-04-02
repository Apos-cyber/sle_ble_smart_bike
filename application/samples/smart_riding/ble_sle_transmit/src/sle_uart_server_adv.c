/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: sle adv config for sle uart server. \n
 *
 * History: \n
 * 2023-07-17, Create file. \n
 */
#include "securec.h"
#include "errcode.h"
#include "osal_addr.h"
#include "product.h"
#include "sle_common.h"
#include "sle_uart_server.h"
#include "sle_device_manager.h"
#include "sle_device_discovery.h"
#include "sle_errcode.h"
#include "osal_debug.h"
#include "osal_task.h"
#include "string.h"
#include "sle_uart_server_adv.h"

/* sle device name */
#define NAME_MAX_LENGTH 16
/* 连接调度间隔12.5ms，单位125us */
#define SLE_CONN_INTV_MIN_DEFAULT                 0x64
/* 连接调度间隔12.5ms，单位125us */
#define SLE_CONN_INTV_MAX_DEFAULT                 0x64
/* 连接调度间隔25ms，单位125us */
#define SLE_ADV_INTERVAL_MIN_DEFAULT              0xC8
/* 连接调度间隔25ms，单位125us */
#define SLE_ADV_INTERVAL_MAX_DEFAULT              0xC8
/* 超时时间5000ms，单位10ms */
#define SLE_CONN_SUPERVISION_TIMEOUT_DEFAULT      0x1F4
/* 超时时间4990ms，单位10ms */
#define SLE_CONN_MAX_LATENCY                      0x1F3
/* 广播发送功率 */
#define SLE_ADV_TX_POWER                          6
/* 广播ID */
#define SLE_ADV_HANDLE_DEFAULT                    1
#define SLE_ADV_HANDLE_DEVICE                     2 
/* 最大广播数据长度 */
#define SLE_ADV_DATA_LEN_MAX                      251
/* 广播名称 */
#define SLE_SERVER_INIT_DELAY_MS    1000
#define sample_at_log_print(fmt, args...) osal_printk(fmt, ##args)
#define SLE_UART_SERVER_LOG "[sle uart server]"


static uint8_t g_sle_adv_data[] = {
    /* SLE ADV TYPE DISCOVERY LEVEL */
    SLE_ADV_DATA_TYPE_DISCOVERY_LEVEL,                          /* type:支持的设备发现等级 */
    0x01,                                                       /* length:1 Byte */
    SLE_ANNOUNCE_LEVEL_NORMAL,                                  /* value: 一般可发现 */
    /* SLE ADV UUID TYPE */
    SLE_ADV_DATA_TYPE_COMPLETE_LIST_OF_16BIT_SERVICE_UUIDS,     /* type:支持的UUID列表 */
    0x02,                                 /* length:2 Byte */
    0x22, 0x22,                         /* value:UUID 0x2222 */
};

#define SLE_ADV_DATA_TYPE_TX_POWER_LEN      1
#define SLE_ADV_DATA_LOCAL_NAME_LEN         8

uint8_t g_sle_adv_rsp_data[] = {
    /* SLE ADV TX POWER LEVEL */
    SLE_ADV_DATA_TYPE_TX_POWER_LEVEL,                           /* type:设置的广播功率等级 */
    SLE_ADV_DATA_TYPE_TX_POWER_LEN,                             /* length:1 Byte */
    SLE_ADV_TX_POWER,
    /* SLE ADV LOCAL NAME */
    SLE_ADV_DATA_TYPE_COMPLETE_LOCAL_NAME,                      /* type:设备广播名称 */
    SLE_ADV_DATA_LOCAL_NAME_LEN,                                /* length:8 Byte */
    's','l','e', '_', 'b','i','k','e'
};

void sle_control_device_adv(uint8_t *adv_addr,uint8_t* adv_data,uint8_t adv_handle)
{
    errno_t ret;
    sle_announce_param_t param = {0};
    unsigned char local_addr[SLE_ADDR_LEN];
    memcpy_s(local_addr, SLE_ADDR_LEN, adv_addr, SLE_ADDR_LEN);
    param.announce_mode = SLE_ANNOUNCE_MODE_NONCONN_SCANABLE;//不可连接
    param.announce_handle = adv_handle;
    param.announce_gt_role = SLE_ANNOUNCE_ROLE_T_CAN_NEGO;
    param.announce_level = SLE_ANNOUNCE_LEVEL_NORMAL;
    param.announce_channel_map = SLE_ADV_CHANNEL_MAP_DEFAULT;
    param.announce_interval_min = 0x7D;
    param.announce_interval_max = 0x7D;
    param.conn_interval_min = SLE_CONN_INTV_MIN_DEFAULT;
    param.conn_interval_max = SLE_CONN_INTV_MAX_DEFAULT;
    param.conn_max_latency = SLE_CONN_MAX_LATENCY;
    param.conn_supervision_timeout = SLE_CONN_SUPERVISION_TIMEOUT_DEFAULT;
    param.own_addr.type = 0;
    memcpy_s(param.own_addr.addr, SLE_ADDR_LEN, local_addr, SLE_ADDR_LEN);
    sle_set_announce_param(param.announce_handle, &param);

    sle_announce_data_t data = {0};
    uint8_t data_index = 0;

    data.announce_data = adv_data;
    data.announce_data_len = sizeof(adv_data);
    sample_at_log_print("%s data.announce_data_len = %d\r\n", SLE_UART_SERVER_LOG, data.announce_data_len);
    sample_at_log_print("%s data.announce_data: ", SLE_UART_SERVER_LOG);
    for (data_index = 0; data_index<data.announce_data_len; data_index++) {
        sample_at_log_print("0x%02x ", data.announce_data[data_index]);
    }
    sample_at_log_print("\r\n");

    data.seek_rsp_data = g_sle_adv_rsp_data;
    data.seek_rsp_data_len = sizeof(g_sle_adv_rsp_data);

    sample_at_log_print("%s data.seek_rsp_data_len = %d\r\n", SLE_UART_SERVER_LOG, data.seek_rsp_data_len);
    sample_at_log_print("%s data.seek_rsp_data: ", SLE_UART_SERVER_LOG);
    for (data_index = 0; data_index<data.seek_rsp_data_len; data_index++) {
        sample_at_log_print("0x%02x ", data.seek_rsp_data[data_index]);
    }
    sample_at_log_print("\r\n");

    ret = sle_set_announce_data(adv_handle, &data);
    if (ret == ERRCODE_SLE_SUCCESS) {
        sample_at_log_print("%s set announce data success.\r\n", SLE_UART_SERVER_LOG);
    } else {
        sample_at_log_print("%s set adv param fail.\r\n", SLE_UART_SERVER_LOG);
    }

    ret = sle_start_announce(adv_handle);
       if (ret != ERRCODE_SLE_SUCCESS) {
       sample_at_log_print("%s sle_start_announce fail, handle:%d, ret:0x%x\r\n", SLE_UART_SERVER_LOG, adv_handle, ret);
       sle_control_device_adv(adv_addr, adv_data, adv_handle);
    }
    sle_stop_announce(adv_handle);
}

















































static int sle_set_default_announce_param(void)
{
    errno_t ret;
    sle_announce_param_t param = {0};
    uint8_t index;
    unsigned char local_addr[SLE_ADDR_LEN] = { 0x11, 0x00, 0x00, 0x00, 0x00, 0x00 };
    param.announce_mode = SLE_ANNOUNCE_MODE_CONNECTABLE_SCANABLE;
    param.announce_handle = SLE_ADV_HANDLE_DEFAULT;
    param.announce_gt_role = SLE_ANNOUNCE_ROLE_T_CAN_NEGO;
    param.announce_level = SLE_ANNOUNCE_LEVEL_NORMAL;
    param.announce_channel_map = SLE_ADV_CHANNEL_MAP_DEFAULT;
    param.announce_interval_min = SLE_ADV_INTERVAL_MIN_DEFAULT;
    param.announce_interval_max = SLE_ADV_INTERVAL_MAX_DEFAULT;
    param.conn_interval_min = SLE_CONN_INTV_MIN_DEFAULT;
    param.conn_interval_max = SLE_CONN_INTV_MAX_DEFAULT;
    param.conn_max_latency = SLE_CONN_MAX_LATENCY;
    param.conn_supervision_timeout = SLE_CONN_SUPERVISION_TIMEOUT_DEFAULT;
    param.own_addr.type = 0;
    ret = memcpy_s(param.own_addr.addr, SLE_ADDR_LEN, local_addr, SLE_ADDR_LEN);
    if (ret != EOK) {
        sample_at_log_print("%s sle_set_default_announce_param data memcpy fail\r\n", SLE_UART_SERVER_LOG);
        return 0;
    }
    sample_at_log_print("%s sle_uart_local addr: ", SLE_UART_SERVER_LOG);
    for (index = 0; index < SLE_ADDR_LEN; index++) {
        sample_at_log_print("0x%02x ", param.own_addr.addr[index]);
    }
    sample_at_log_print("\r\n");
    return sle_set_announce_param(param.announce_handle, &param);
}

static int sle_set_default_announce_data(void)
{
    errcode_t ret;
    sle_announce_data_t data = {0};
    uint8_t adv_handle = SLE_ADV_HANDLE_DEFAULT;
    uint8_t data_index = 0;

    data.announce_data = g_sle_adv_data;
    data.announce_data_len = sizeof(g_sle_adv_data);

    sample_at_log_print("%s data.announce_data_len = %d\r\n", SLE_UART_SERVER_LOG, data.announce_data_len);
    sample_at_log_print("%s data.announce_data: ", SLE_UART_SERVER_LOG);
    for (data_index = 0; data_index<data.announce_data_len; data_index++) {
        sample_at_log_print("0x%02x ", data.announce_data[data_index]);
    }
    sample_at_log_print("\r\n");

    data.seek_rsp_data = g_sle_adv_rsp_data;
    data.seek_rsp_data_len = sizeof(g_sle_adv_rsp_data);

    sample_at_log_print("%s data.seek_rsp_data_len = %d\r\n", SLE_UART_SERVER_LOG, data.seek_rsp_data_len);
    sample_at_log_print("%s data.seek_rsp_data: ", SLE_UART_SERVER_LOG);
    for (data_index = 0; data_index<data.seek_rsp_data_len; data_index++) {
        sample_at_log_print("0x%02x ", data.seek_rsp_data[data_index]);
    }
    sample_at_log_print("\r\n");

    ret = sle_set_announce_data(adv_handle, &data);
    if (ret == ERRCODE_SLE_SUCCESS) {
        sample_at_log_print("%s set announce data success.\r\n", SLE_UART_SERVER_LOG);
    } else {
        sample_at_log_print("%s set adv param fail.\r\n", SLE_UART_SERVER_LOG);
    }
    return ERRCODE_SLE_SUCCESS;
}

static void sle_announce_enable_cbk(uint32_t announce_id, errcode_t status)
{
    sample_at_log_print("%s sle announce enable callback id:0x%02x, state:0x%x\r\n", SLE_UART_SERVER_LOG, announce_id,
        status);
}

static void sle_announce_disable_cbk(uint32_t announce_id, errcode_t status)
{
    sample_at_log_print("%s sle announce disable callback id:0x%02x, state:0x%x\r\n", SLE_UART_SERVER_LOG, announce_id,
        status);
}

static void sle_announce_terminal_cbk(uint32_t announce_id)
{
    sample_at_log_print("%s sle announce terminal callback id:0x%02x\r\n", SLE_UART_SERVER_LOG, announce_id);
}

static void sle_power_on_cbk(uint8_t status)
{
    sample_at_log_print("sle power on: %d\r\n", status);
    enable_sle();
}

static void sle_enable_cbk(uint8_t status)
{
    sample_at_log_print("sle enable: %d\r\n", status);
    sle_enable_server_cbk();
}

errcode_t sle_dev_register_cbks(void)
{
    errcode_t ret = 0;
    sle_dev_manager_callbacks_t dev_mgr_cbks = {0};
    dev_mgr_cbks.sle_power_on_cb = sle_power_on_cbk;
    dev_mgr_cbks.sle_enable_cb = sle_enable_cbk;
    ret = sle_dev_manager_register_callbacks(&dev_mgr_cbks);
    if (ret != ERRCODE_SLE_SUCCESS) {
        sample_at_log_print("%s sle_dev_register_cbks,register_callbacks fail :%x\r\n",
            SLE_UART_SERVER_LOG, ret);
        return ret;
    }
#if (CORE_NUMS < 2)
    enable_sle();
#endif
    return ERRCODE_SLE_SUCCESS;
}

errcode_t sle_uart_announce_register_cbks(void)
{
    errcode_t ret = 0;
    sle_announce_seek_callbacks_t seek_cbks = {0};
    seek_cbks.announce_enable_cb = sle_announce_enable_cbk;
    seek_cbks.announce_disable_cb = sle_announce_disable_cbk;
    seek_cbks.announce_terminal_cb = sle_announce_terminal_cbk;
    ret = sle_announce_seek_register_callbacks(&seek_cbks);
    if (ret != ERRCODE_SLE_SUCCESS) {
        sample_at_log_print("%s sle_uart_announce_register_cbks,register_callbacks fail :%x\r\n",
            SLE_UART_SERVER_LOG, ret);
        return ret;
    }
    return ERRCODE_SLE_SUCCESS;
}

errcode_t sle_uart_server_adv_init(void)
{
    errcode_t ret;
    sle_set_default_announce_param();
    sle_set_default_announce_data();
    ret = sle_start_announce(SLE_ADV_HANDLE_DEFAULT);
    if (ret != ERRCODE_SLE_SUCCESS) {
        sample_at_log_print("%s sle_uart_server_adv_init,sle_start_announce fail :%x\r\n", SLE_UART_SERVER_LOG, ret);
        return ret;
    }
    return ERRCODE_SLE_SUCCESS;
}

void sle_set_device_name(const uint8_t *name, uint8_t len)
{
    if (name == NULL || len == 0) {
        sample_at_log_print("%s sle_set_device_name invalid param\r\n", SLE_UART_SERVER_LOG);
        return;
    }

    /* 名字在 g_sle_adv_rsp_data 中从 index 5 开始 (跳过 0x0C, 0x01, 0x06, 0x0B, 0x08) */
    uint8_t copy_len = len;
    if (copy_len > 8) {
        copy_len = 8;
        sample_at_log_print("%s sle_set_device_name too long, truncated to 8\r\n", SLE_UART_SERVER_LOG);
    }

    /* 更新名字部分 */
    errno_t ret = memcpy_s(&g_sle_adv_rsp_data[5], 8, name, copy_len);
    if (ret != EOK) {
        sample_at_log_print("%s sle_set_device_name memcpy failed\r\n", SLE_UART_SERVER_LOG);
        return;
    }

    /* 不足8字节的部分填充空格 */
    if (copy_len < 8) {
        (void)memset_s(&g_sle_adv_rsp_data[5 + copy_len], 8 - copy_len, ' ', 8 - copy_len);
    }

    sample_at_log_print("%s sle device name set: ", SLE_UART_SERVER_LOG);
    for (uint8_t i = 0; i < 8; i++) {
        sample_at_log_print("%c", g_sle_adv_rsp_data[5 + i]);
    }
    sample_at_log_print("\r\n");

    /* 重新设置广播数据并重启广播 */
    (void)sle_set_default_announce_data();
    (void)sle_start_announce(SLE_ADV_HANDLE_DEFAULT);
}
