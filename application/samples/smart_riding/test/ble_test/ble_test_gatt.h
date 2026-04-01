/**
 * @file ble_test_gatt.h
 * @brief BLE GATT definitions for smart riding test
 */
#ifndef BLE_TEST_GATT_H
#define BLE_TEST_GATT_H

#include <stdint.h>
#include "errcode.h"
#include "bts_gatt_server.h"

/* UART Service UUID: 0xABCD */
#define BLE_TEST_UUID_UART_SERVICE      0xABCD
#define BLE_TEST_UUID_UART_TX            0xCDEF  /* Server notify Phone */
#define BLE_TEST_UUID_UART_RX            0xEFEF  /* Phone write Server */

/* Battery Service UUID: 0x180F */
#define BLE_TEST_UUID_BATTERY_SERVICE    0x180F
#define BLE_TEST_UUID_BATTERY_LEVEL      0xCDEF  /* Battery level characteristic */

/* Automation IO Service UUID: 0x1815 */
#define BLE_TEST_UUID_AIO_SERVICE        0x1815
#define BLE_TEST_UUID_AIO_LIGHT          0xAAAA  /* Car light status */
#define BLE_TEST_UUID_AIO_CAR_STATE      0xAAAB  /* Car state */

/* Client Characteristic Configuration UUID */
#define BLE_TEST_CLIENT_CHARACTERISTIC_CONFIGURATION 0x2902

/* GATT server ID */
#define BLE_TEST_SERVER_ID_INVALID   0xFF
extern uint8_t g_ble_test_server_id;

/* Characteristic value handles */
extern uint16_t g_ble_test_uart_tx_handle;
extern uint16_t g_ble_test_uart_rx_handle;
extern uint16_t g_ble_test_battery_handle;
extern uint16_t g_ble_test_aio_light_handle;
extern uint16_t g_ble_test_aio_car_state_handle;

/* GATT callback registration */
errcode_t ble_test_gatt_register_callbacks(void);

/* Add all GATT services */
void ble_test_add_services(void);

/* Convert uint16 UUID to bt_uuid_t */
void ble_test_uuid_to_uuid16(uint16_t uuid_data, bt_uuid_t *out_uuid);

#endif /* BLE_TEST_GATT_H */
