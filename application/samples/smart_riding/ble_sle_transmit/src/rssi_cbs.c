#include "sle_uart_server.h"
#include "sle_uart_server_adv.h"
#include "sle_connection_manager.h"
#include "errcode.h"
#include "osal_debug.h"
#include "osal_addr.h"
#include "product.h"
#include "securec.h"
#include "uart.h"
#include "soc_osal.h"
#include "rssi_cbs.h"

void sle_server_print_rssi_cbk(uint16_t conn_id, int8_t rssi, errcode_t status)
{
    osal_printk("%s read rssi cbk conn_id: %d, rssi: %d, status: %d\n",
                "SLE!!!", conn_id, rssi, status);
}


void ble_server_print_rssi_cbk(uint16_t conn_id, int8_t rssi, errcode_t status)
{
    osal_printk("%s read rssi cbk conn_id: %d, rssi: %d, status: %d\n",
                "BLE!!!", conn_id, rssi, status);
}
