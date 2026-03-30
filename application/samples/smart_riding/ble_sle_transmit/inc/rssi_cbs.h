#ifndef RSSI_CBS_H
#define RSSI_CBS_H

#include <stdint.h>
#include "sle_ssap_server.h"
#include "sle_connection_manager.h"
#include "errcode.h"

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif /* __cplusplus */
#endif /* __cplusplus */

void ble_server_print_rssi_cbk(uint16_t conn_id, int8_t rssi, errcode_t status);
void sle_server_print_rssi_cbk(uint16_t conn_id, int8_t rssi, errcode_t status);

#ifdef __cplusplus
#if __cplusplus
}
#endif /* __cplusplus */
#endif /* __cplusplus */

#endif /* RSSI_CBS_H */