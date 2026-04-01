/**
 * @file ble_test.c
 * @brief BLE GATT Server test application entry
 */
#include "app_init.h"
#include "soc_osal.h"
#include "osal_task.h"
#include "securec.h"
#include "bts_device_manager.h"
#include "bts_gatt_server.h"
#include "ble_test_gatt.h"
#include "ble_test_adv.h"

#define BLE_TEST_TASK_STACK_SIZE 2048

/* BLE enable callback */
static void ble_test_ble_enable_cbk(uint8_t status)
{
    osal_printk("[BLE_TEST] BLE enable: status=%d\r\n", status);

    if (status == 0)
    { /* success */
        osal_printk("[BLE_TEST] BLE stack ready, registering GATT server...\r\n");
        errcode_t ret;

        /* Register GATT callbacks */
        ret = ble_test_gatt_register_callbacks();
        if (ret != ERRCODE_BT_SUCCESS)
        {
            osal_printk("[BLE_TEST] Failed to register GATT callbacks: %d\r\n", ret);
            return;
        }

        /* Register GAP callbacks */
        ble_test_adv_register_callbacks();

        /* Register GATT server */
        uint8_t app_uuid[] = {0x12, 0x34, 0x56, 0x78};
        bt_uuid_t server_uuid = {0};
        server_uuid.uuid_len = sizeof(app_uuid);
        if (memcpy_s(server_uuid.uuid, server_uuid.uuid_len, app_uuid, sizeof(app_uuid)) != EOK)
        {
            osal_printk("[BLE_TEST] Failed to copy UUID\r\n");
            return;
        }

        ret = gatts_register_server(&server_uuid, &g_ble_test_server_id);
        if ((ret != ERRCODE_BT_SUCCESS) || (g_ble_test_server_id == BLE_TEST_SERVER_ID_INVALID))
        {
            osal_printk("[BLE_TEST] Failed to register GATT server: %d, id=%d\r\n",
                        ret, g_ble_test_server_id);
            return;
        }

        osal_printk("[BLE_TEST] GATT server registered, id=%d\r\n", g_ble_test_server_id);

        /* Add services */
        ble_test_add_services();
    }
}

/* Device manager power on callback */
static void ble_test_power_on_cbk(uint8_t status)
{
    osal_printk("[BLE_TEST] Device manager power on: status=%d\r\n", status);
    enable_ble();
}

/* BLE test task entry */
static int ble_test_task_entry(const char *arg)
{
    UNUSED(arg);
    osal_printk("[BLE_TEST] Task started\r\n");

    /* Register device manager callbacks */
    bts_dev_manager_callbacks_t dev_mgr_cb = {0};
    dev_mgr_cb.power_on_cb = ble_test_power_on_cbk;
    dev_mgr_cb.ble_enable_cb = ble_test_ble_enable_cbk;
    errcode_t ret = bts_dev_manager_register_callbacks(&dev_mgr_cb);
    if (ret != ERRCODE_BT_SUCCESS)
    {
        osal_printk("[BLE_TEST] Failed to register dev manager callbacks: %d\r\n", ret);
        return -1;
    }

    osal_printk("[BLE_TEST] Waiting for BLE enable...\r\n");

    /* Task runs forever */
    while (1)
    {
        osal_msleep(1000);
    }

    return 0;
}

/* BLE test entry point */
static void ble_test_entry(void)
{
    osal_printk("[BLE_TEST] Entry, creating task...\r\n");

    osal_task *task_handle = osal_kthread_create(
        ble_test_task_entry,
        NULL,
        "ble_test",
        BLE_TEST_TASK_STACK_SIZE);

    if (task_handle == NULL)
    {
        osal_printk("[BLE_TEST] Failed to create task\r\n");
        return;
    }

    osal_printk("[BLE_TEST] Task created: 0x%08X\r\n", (uint32_t)(uintptr_t)task_handle);
}

/* Register BLE test entry using app_run macro */
app_run(ble_test_entry);
