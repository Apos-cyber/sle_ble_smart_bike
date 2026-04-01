/**
 * @file ble_test_adv.c
 * @brief BLE Advertising implementation
 */
#include "ble_test_adv.h"
#include "soc_osal.h"
#include "securec.h"
#include "errcode.h"
#include "bts_def.h"
#include "bts_le_gap.h"
#include "ble_test_gatt.h"

#define BLE_TEST_ADV_LOG "[BLE_TEST_ADV]"

#define BLE_TEST_ADV_HANDLE_DEFAULT 0x01
#define BLE_TEST_ADV_MIN_INTERVAL 0x30
#define BLE_TEST_ADV_MAX_INTERVAL 0x60
#define BLE_TEST_ADV_FOREVER_DURATION 0

static uint8_t g_ble_test_adv_enabled = 0;

/* Connection state change callback */
static void ble_test_connect_change_cbk(uint16_t conn_id, bd_addr_t *addr,
                                        gap_ble_conn_state_t conn_state,
                                        gap_ble_pair_state_t pair_state,
                                        gap_ble_disc_reason_t disc_reason)
{
    (void)addr;
    (void)pair_state;
    (void)disc_reason;

    osal_printk("%s Conn state changed: conn_id=%d, state=%d\r\n",
                BLE_TEST_ADV_LOG, conn_id, conn_state);

    if (conn_state == GAP_BLE_STATE_CONNECTED) {
        osal_printk("%s Device connected\r\n", BLE_TEST_ADV_LOG);
    } else if (conn_state == GAP_BLE_STATE_DISCONNECTED) {
        osal_printk("%s Device disconnected, restart adv\r\n", BLE_TEST_ADV_LOG);
        ble_test_adv_start();
    }
}

/* Advertising enable callback */
static void ble_test_adv_enable_cbk(uint8_t adv_id, adv_status_t status)
{
    (void)adv_id;
    (void)status;
    g_ble_test_adv_enabled = 1;
    osal_printk("%s Advertising enabled, status=%d\r\n", BLE_TEST_ADV_LOG, status);
}

/* Advertising disable callback */
static void ble_test_adv_disable_cbk(uint8_t adv_id, adv_status_t status)
{
    (void)adv_id;
    (void)status;
    g_ble_test_adv_enabled = 0;
    osal_printk("%s Advertising disabled, status=%d\r\n", BLE_TEST_ADV_LOG, status);
}

/* Register GAP callbacks */
void ble_test_adv_register_callbacks(void)
{
    gap_ble_callbacks_t gap_cb = { 0 };
    gap_cb.conn_state_change_cb = ble_test_connect_change_cbk;
    gap_cb.start_adv_cb = ble_test_adv_enable_cbk;
    gap_cb.stop_adv_cb = ble_test_adv_disable_cbk;

    gap_ble_register_callbacks(&gap_cb);
}

/* Start advertising */
void ble_test_adv_start(void)
{
    if (g_ble_test_adv_enabled) {
        osal_printk("%s Already advertising\r\n", BLE_TEST_ADV_LOG);
        return;
    }

    errcode_t ret;
    uint8_t adv_id = BLE_TEST_ADV_HANDLE_DEFAULT;

    /* Set local device name */
    uint8_t device_name[] = BLE_TEST_DEVICE_NAME;
    ret = gap_ble_set_local_name(device_name, sizeof(device_name) - 1);
    if (ret != ERRCODE_BT_SUCCESS) {
        osal_printk("%s Failed to set local name: %d\r\n", BLE_TEST_ADV_LOG, ret);
        return;
    }

    /* Set random BD address */
    bd_addr_t ble_addr = {
        .addr = { 0x11, 0x22, 0x33, 0x44, 0x55, 0x66 },
        .type = BT_ADDRESS_TYPE_PUBLIC_DEVICE_ADDRESS
    };
    ret = gap_ble_set_local_addr(&ble_addr);
    if (ret != ERRCODE_BT_SUCCESS) {
        osal_printk("%s Failed to set local addr: %d\r\n", BLE_TEST_ADV_LOG, ret);
        return;
    }

    /* Set advertising parameters */
    gap_ble_adv_params_t adv_para = {
        .min_interval = BLE_TEST_ADV_MIN_INTERVAL,
        .max_interval = BLE_TEST_ADV_MAX_INTERVAL,
        .duration = BLE_TEST_ADV_FOREVER_DURATION,
        .adv_type = GAP_BLE_ADV_CONN_SCAN_UNDIR,
        .peer_addr.type = BT_ADDRESS_TYPE_PUBLIC_DEVICE_ADDRESS,
        .channel_map = 0x07,
        .adv_filter_policy = GAP_BLE_ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY
    };

    (void)memset_s(&adv_para.peer_addr.addr, BD_ADDR_LEN, 0, BD_ADDR_LEN);

    ret = gap_ble_set_adv_param(adv_id, &adv_para);
    if (ret != ERRCODE_BT_SUCCESS) {
        osal_printk("%s Failed to set adv param: %d\r\n", BLE_TEST_ADV_LOG, ret);
        return;
    }

    /* Set advertising data - minimal */
    uint8_t adv_data[] = {
        0x02, 0x01, 0x06,  /* Flags: LE General Discoverable, BR/EDR not supported */
        0x09, 0xFF, 0x00, 0x00  /* Device name placeholder */
    };

    /* Override with device name in scan response - for now just use adv data */
    gap_ble_config_adv_data_t cfg_adv_data = { 0 };
    cfg_adv_data.adv_data = adv_data;
    cfg_adv_data.adv_length = sizeof(adv_data);
    cfg_adv_data.scan_rsp_data = NULL;
    cfg_adv_data.scan_rsp_length = 0;

    ret = gap_ble_set_adv_data(adv_id, &cfg_adv_data);
    if (ret != ERRCODE_BT_SUCCESS) {
        osal_printk("%s Failed to set adv data: %d\r\n", BLE_TEST_ADV_LOG, ret);
        return;
    }

    /* Start advertising */
    ret = gap_ble_start_adv(adv_id);
    if (ret == ERRCODE_BT_SUCCESS) {
        osal_printk("%s Advertising started\r\n", BLE_TEST_ADV_LOG);
    } else {
        osal_printk("%s Failed to start advertising: %d\r\n", BLE_TEST_ADV_LOG, ret);
    }
}

/* Stop advertising */
void ble_test_adv_stop(void)
{
    if (!g_ble_test_adv_enabled) {
        return;
    }

    uint8_t adv_id = BLE_TEST_ADV_HANDLE_DEFAULT;
    errcode_t ret = gap_ble_stop_adv(adv_id);
    if (ret == ERRCODE_BT_SUCCESS) {
        osal_printk("%s Advertising stopped\r\n", BLE_TEST_ADV_LOG);
    } else {
        osal_printk("%s Failed to stop advertising: %d\r\n", BLE_TEST_ADV_LOG, ret);
    }
}
