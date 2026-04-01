/**
 * @file ble_test_adv.h
 * @brief BLE Advertising interface declarations
 */
#ifndef BLE_TEST_ADV_H
#define BLE_TEST_ADV_H

#include <stdint.h>

/* Advertising device name */
#define BLE_TEST_DEVICE_NAME "SmartBike_Test"

/* Start advertising */
void ble_test_adv_start(void);

/* Stop advertising */
void ble_test_adv_stop(void);

/* Register advertising callbacks */
void ble_test_adv_register_callbacks(void);

#endif /* BLE_TEST_ADV_H */
