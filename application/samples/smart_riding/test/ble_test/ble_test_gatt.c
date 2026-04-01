/**
 * @file ble_test_gatt.c
 * @brief BLE GATT Server implementation for smart riding test
 */
#include "ble_test_gatt.h"
#include "soc_osal.h"
#include "uapi_uart.h"
#include "securec.h"

#define BLE_TEST_GATT_LOG "[BLE_TEST_GATT]"

#define UART16_LEN 2

/* Server ID */
uint8_t g_ble_test_server_id = BLE_TEST_SERVER_ID_INVALID;

/* Characteristic value handles */
uint16_t g_ble_test_uart_tx_handle = 0;
uint16_t g_ble_test_uart_rx_handle = 0;
uint16_t g_ble_test_battery_handle = 0;
uint16_t g_ble_test_aio_light_handle = 0;
uint16_t g_ble_test_aio_car_state_handle = 0;

/* Convert uint16 UUID to bt_uuid_t */
void ble_test_uuid_to_uuid16(uint16_t uuid_data, bt_uuid_t *out_uuid)
{
    out_uuid->uuid_len = UART16_LEN;
    out_uuid->uuid[0] = (uint8_t)(uuid_data >> 8);
    out_uuid->uuid[1] = (uint8_t)(uuid_data);
}

/* Add UART Service */
static void ble_test_add_uart_service(void)
{
    bt_uuid_t uart_service_uuid = { 0 };
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_UART_SERVICE, &uart_service_uuid);
    gatts_add_service(g_ble_test_server_id, &uart_service_uuid, true);
}

/* Add Battery Service */
static void ble_test_add_battery_service(void)
{
    bt_uuid_t battery_service_uuid = { 0 };
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_BATTERY_SERVICE, &battery_service_uuid);
    gatts_add_service(g_ble_test_server_id, &battery_service_uuid, true);
}

/* Add Automation IO Service */
static void ble_test_add_aio_service(void)
{
    bt_uuid_t aio_service_uuid = { 0 };
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_AIO_SERVICE, &aio_service_uuid);
    gatts_add_service(g_ble_test_server_id, &aio_service_uuid, true);
}

/* Add UART TX characteristic with CCCD */
static void ble_test_add_uart_tx_char(uint8_t server_id, uint16_t srvc_handle)
{
    bt_uuid_t characters_uuid = { 0 };
    uint8_t characters_value[] = { 0x00 };
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_UART_TX, &characters_uuid);

    gatts_add_chara_info_t character = { 0 };
    character.chara_uuid = characters_uuid;
    character.properties = GATT_CHARACTER_PROPERTY_BIT_NOTIFY | GATT_CHARACTER_PROPERTY_BIT_READ;
    character.permissions = GATT_ATTRIBUTE_PERMISSION_READ | GATT_ATTRIBUTE_PERMISSION_WRITE;
    character.value_len = sizeof(characters_value);
    character.value = characters_value;
    gatts_add_characteristic(server_id, srvc_handle, &character);

    /* Add CCCD descriptor */
    static uint8_t ccc_val[] = { 0x00, 0x00 };
    bt_uuid_t ccc_uuid = { 0 };
    ble_test_uuid_to_uuid16(BLE_TEST_CLIENT_CHARACTERISTIC_CONFIGURATION, &ccc_uuid);
    gatts_add_desc_info_t descriptor = { 0 };
    descriptor.desc_uuid = ccc_uuid;
    descriptor.permissions = GATT_ATTRIBUTE_PERMISSION_READ | GATT_ATTRIBUTE_PERMISSION_WRITE;
    descriptor.value_len = sizeof(ccc_val);
    descriptor.value = ccc_val;
    gatts_add_descriptor(server_id, srvc_handle, &descriptor);
}

/* Add UART RX characteristic */
static void ble_test_add_uart_rx_char(uint8_t server_id, uint16_t srvc_handle)
{
    bt_uuid_t characters_uuid = { 0 };
    uint8_t characters_value[] = { 0x00 };
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_UART_RX, &characters_uuid);

    gatts_add_chara_info_t character = { 0 };
    character.chara_uuid = characters_uuid;
    character.properties = GATT_CHARACTER_PROPERTY_BIT_READ | GATT_CHARACTER_PROPERTY_BIT_WRITE_NO_RSP;
    character.permissions = GATT_ATTRIBUTE_PERMISSION_READ | GATT_ATTRIBUTE_PERMISSION_WRITE;
    character.value_len = sizeof(characters_value);
    character.value = characters_value;
    gatts_add_characteristic(server_id, srvc_handle, &character);
}

/* Add Battery Level characteristic */
static void ble_test_add_battery_char(uint8_t server_id, uint16_t srvc_handle)
{
    bt_uuid_t characters_uuid = { 0 };
    uint8_t characters_value[] = { 0x64 }; /* 100% initial */
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_BATTERY_LEVEL, &characters_uuid);

    gatts_add_chara_info_t character = { 0 };
    character.chara_uuid = characters_uuid;
    character.properties = GATT_CHARACTER_PROPERTY_BIT_READ | GATT_CHARACTER_PROPERTY_BIT_NOTIFY;
    character.permissions = GATT_ATTRIBUTE_PERMISSION_READ;
    character.value_len = sizeof(characters_value);
    character.value = characters_value;
    gatts_add_characteristic(server_id, srvc_handle, &character);

    /* Add CCCD descriptor */
    static uint8_t ccc_val[] = { 0x00, 0x00 };
    bt_uuid_t ccc_uuid = { 0 };
    ble_test_uuid_to_uuid16(BLE_TEST_CLIENT_CHARACTERISTIC_CONFIGURATION, &ccc_uuid);
    gatts_add_desc_info_t descriptor = { 0 };
    descriptor.desc_uuid = ccc_uuid;
    descriptor.permissions = GATT_ATTRIBUTE_PERMISSION_READ | GATT_ATTRIBUTE_PERMISSION_WRITE;
    descriptor.value_len = sizeof(ccc_val);
    descriptor.value = ccc_val;
    gatts_add_descriptor(server_id, srvc_handle, &descriptor);
}

/* Add AIO Light characteristic */
static void ble_test_add_aio_light_char(uint8_t server_id, uint16_t srvc_handle)
{
    bt_uuid_t characters_uuid = { 0 };
    uint8_t characters_value[] = { 0x00 }; /* off */
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_AIO_LIGHT, &characters_uuid);

    gatts_add_chara_info_t character = { 0 };
    character.chara_uuid = characters_uuid;
    character.properties = GATT_CHARACTER_PROPERTY_BIT_READ | GATT_CHARACTER_PROPERTY_BIT_WRITE_NO_RSP;
    character.permissions = GATT_ATTRIBUTE_PERMISSION_READ | GATT_ATTRIBUTE_PERMISSION_WRITE;
    character.value_len = sizeof(characters_value);
    character.value = characters_value;
    gatts_add_characteristic(server_id, srvc_handle, &character);
}

/* Add AIO Car State characteristic */
static void ble_test_add_aio_car_state_char(uint8_t server_id, uint16_t srvc_handle)
{
    bt_uuid_t characters_uuid = { 0 };
    uint8_t characters_value[] = { 0x00 }; /* idle */
    ble_test_uuid_to_uuid16(BLE_TEST_UUID_AIO_CAR_STATE, &characters_uuid);

    gatts_add_chara_info_t character = { 0 };
    character.chara_uuid = characters_uuid;
    character.properties = GATT_CHARACTER_PROPERTY_BIT_READ | GATT_CHARACTER_PROPERTY_BIT_WRITE_NO_RSP;
    character.permissions = GATT_ATTRIBUTE_PERMISSION_READ | GATT_ATTRIBUTE_PERMISSION_WRITE;
    character.value_len = sizeof(characters_value);
    character.value = characters_value;
    gatts_add_characteristic(server_id, srvc_handle, &character);
}

/* Write request callback - handles data from phone */
static void ble_test_receive_write_req_cbk(uint8_t server_id, gatts_read_req_cb_t *p_read_req,
                                           gatts_write_req_cb_t *p_write_req)
{
    if (p_write_req == NULL) {
        return;
    }

    uint16_t handle = p_write_req->handle;
    uint16_t len = p_write_req->len;
    uint8_t *p_data = p_write_req->value;

    osal_printk("%s Write req: handle=%d, len=%d, data=", BLE_TEST_GATT_LOG, handle, len);

    /* Print data to log */
    uint32_t print_len = (len > 16) ? 16 : len;
    for (uint32_t i = 0; i < print_len; i++) {
        osal_printk("%02X ", p_data[i]);
    }
    if (len > 16) {
        osal_printk("...");
    }
    osal_printk("\r\n");

    /* Also write to UART bus 0 for debugging */
    char uart_buf[64] = {0};
    uint32_t uart_len = (len > 58) ? 58 : len;
    uart_buf[0] = 'W';
    uart_buf[1] = ':';
    memcpy(&uart_buf[2], p_data, uart_len);
    uapi_uart_write(0, (uint8_t *)uart_buf, uart_len + 2);

    (void)server_id;
    (void)p_read_req;
}

/* Read request callback */
static void ble_test_receive_read_req_cbk(uint8_t server_id, gatts_read_req_cb_t *p_read_req,
                                           gatts_write_req_cb_t *p_write_req)
{
    (void)server_id;
    (void)p_read_req;
    (void)p_write_req;
}

/* Service add callback */
static void ble_test_service_add_cbk(uint8_t server_id, uint16_t srvc_handle, bt_uuid_t *srvc_uuid)
{
    if (srvc_uuid == NULL) {
        return;
    }

    uint16_t uuid = (srvc_uuid->uuid[0] << 8) | srvc_uuid->uuid[1];
    osal_printk("%s Service added: uuid=0x%04X, handle=%d\r\n", BLE_TEST_GATT_LOG, uuid, srvc_handle);

    if (uuid == BLE_TEST_UUID_UART_SERVICE) {
        ble_test_add_uart_tx_char(server_id, srvc_handle);
        ble_test_add_uart_rx_char(server_id, srvc_handle);
    } else if (uuid == BLE_TEST_UUID_BATTERY_SERVICE) {
        ble_test_add_battery_char(server_id, srvc_handle);
    } else if (uuid == BLE_TEST_UUID_AIO_SERVICE) {
        ble_test_add_aio_light_char(server_id, srvc_handle);
        ble_test_add_aio_car_state_char(server_id, srvc_handle);
    }

    (void)server_id;
}

/* Characteristic add callback */
static void ble_test_characteristic_add_cbk(uint8_t server_id, uint16_t srvc_handle,
                                             uint16_t char_handle, bt_uuid_t *chara_uuid)
{
    if (chara_uuid == NULL) {
        return;
    }

    uint16_t uuid = (chara_uuid->uuid[0] << 8) | chara_uuid->uuid[1];
    osal_printk("%s Characteristic added: uuid=0x%04X, handle=%d\r\n", BLE_TEST_GATT_LOG, uuid, char_handle);

    /* Save handles for later use */
    if (uuid == BLE_TEST_UUID_UART_TX) {
        g_ble_test_uart_tx_handle = char_handle;
    } else if (uuid == BLE_TEST_UUID_UART_RX) {
        g_ble_test_uart_rx_handle = char_handle;
    } else if (uuid == BLE_TEST_UUID_BATTERY_LEVEL) {
        g_ble_test_battery_handle = char_handle;
    } else if (uuid == BLE_TEST_UUID_AIO_LIGHT) {
        g_ble_test_aio_light_handle = char_handle;
    } else if (uuid == BLE_TEST_UUID_AIO_CAR_STATE) {
        g_ble_test_aio_car_state_handle = char_handle;
    }

    (void)server_id;
    (void)srvc_handle;
}

/* Descriptor add callback */
static void ble_test_descriptor_add_cbk(uint8_t server_id, uint16_t srvc_handle,
                                         uint16_t desc_handle, bt_uuid_t *desc_uuid)
{
    (void)server_id;
    (void)srvc_handle;
    (void)desc_handle;
    (void)desc_uuid;
}

/* Service start callback */
static void ble_test_service_start_cbk(uint8_t server_id, uint16_t srvc_handle)
{
    osal_printk("%s Service started: handle=%d\r\n", BLE_TEST_GATT_LOG, srvc_handle);
    (void)server_id;
}

/* MTU changed callback */
static void ble_test_mtu_changed_cbk(uint8_t server_id, uint16_t conn_handle, uint16_t mtu)
{
    osal_printk("%s MTU changed: conn=%d, mtu=%d\r\n", BLE_TEST_GATT_LOG, conn_handle, mtu);
    (void)server_id;
}

/* Register GATT callbacks */
errcode_t ble_test_gatt_register_callbacks(void)
{
    gatts_callbacks_t service_cb = { 0 };

    service_cb.add_service_cb = ble_test_service_add_cbk;
    service_cb.add_characteristic_cb = ble_test_characteristic_add_cbk;
    service_cb.add_descriptor_cb = ble_test_descriptor_add_cbk;
    service_cb.start_service_cb = ble_test_service_start_cbk;
    service_cb.read_request_cb = ble_test_receive_read_req_cbk;
    service_cb.write_request_cb = ble_test_receive_write_req_cbk;
    service_cb.mtu_changed_cb = ble_test_mtu_changed_cbk;

    return gatts_register_callbacks(&service_cb);
}

/* Add all services */
void ble_test_add_services(void)
{
    ble_test_add_uart_service();
    ble_test_add_battery_service();
    ble_test_add_aio_service();
}
