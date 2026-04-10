#include "app_init.h"
#include "common_def.h"
#include "osal_debug.h"
#include "soc_osal.h"
#include "gpio.h"
#include "pinctrl.h"
#include "string.h"

#include "common_uart.h"
#include "L610.h"
#include "gnss_pos.h"
#include "cloud_common.h"

uint8_t gnss_rx_buffer[MAX_BUFFER_SIZE];
uint8_t l610_rx_buffer[MAX_BUFFER_SIZE];

uart_buffer_config_t gnss_buffer_config = {.rx_buffer = gnss_rx_buffer, .rx_buffer_size = MAX_BUFFER_SIZE}; // gnss uart

uart_buffer_config_t l610_buffer_config = {.rx_buffer = l610_rx_buffer, .rx_buffer_size = MAX_BUFFER_SIZE}; // l610 uart

errcode_t l610_uart_init(void)
{

    uapi_pin_set_mode(GNSS_TXD_PIN, (pin_mode_t)GNSS_TXD_MODE);
    uapi_pin_set_mode(GNSS_RXD_PIN, (pin_mode_t)GNSS_RXD_MODE); // gnss

    uapi_pin_set_mode(L610_TXD_PIN, (pin_mode_t)L610_UART_TXD_PIN_MODE);
    uapi_pin_set_mode(L610_RXD_PIN, (pin_mode_t)L610_UART_RXD_PIN_MODE); // l610

    uart_attr_t gnss_attr = {.baud_rate = GNSS_UART_BAUDRATE,
                             .data_bits = UART_DATA_BIT_8,
                             .stop_bits = UART_STOP_BIT_1,
                             .parity = UART_PARITY_NONE};

    uart_pin_config_t gnss_pin_config = {
        .tx_pin = GNSS_TXD_PIN, .rx_pin = GNSS_RXD_PIN, .cts_pin = PIN_NONE, .rts_pin = PIN_NONE}; // gnss

    uart_attr_t l610_attr = {.baud_rate = L610_UART_BAUDRATE,
                             .data_bits = UART_DATA_BIT_8,
                             .stop_bits = UART_STOP_BIT_1,
                             .parity = UART_PARITY_NONE};

    uart_pin_config_t l610_pin_config = {
        .tx_pin = L610_TXD_PIN, .rx_pin = L610_RXD_PIN, .cts_pin = PIN_NONE, .rts_pin = PIN_NONE}; // print

    uapi_uart_deinit(GNSS_UART_BUS);
    uapi_uart_deinit(L610_UART_BUS);

    errcode_t ret = uapi_uart_init(GNSS_UART_BUS, &gnss_pin_config, &gnss_attr, NULL, &gnss_buffer_config);
    if (ret != ERRCODE_SUCC) {
        osal_printk("GNSS UART init failed: 0x%x\r\n", ret);
        return ret;
    }

    ret = uapi_uart_register_rx_callback(GNSS_UART_BUS, UART_RX_CONDITION_FULL_OR_IDLE, 1, gnss_uart_rx_callback);
    if (ret != ERRCODE_SUCC) {
        osal_printk("GNSS Register callback failed: 0x%x\r\n", ret);
        return ret;
    } // gnss

    ret = uapi_uart_init(L610_UART_BUS, &l610_pin_config, &l610_attr, NULL, &l610_buffer_config);
    if (ret != ERRCODE_SUCC) {
        osal_printk("L610 UART init failed: 0x%x\r\n", ret);
        return ret;
    }

    ret = uapi_uart_register_rx_callback(L610_UART_BUS, UART_RX_CONDITION_FULL_OR_IDLE, 1, l610_uart_rx_callback);
    if (ret != ERRCODE_SUCC) {
        osal_printk("L610 Register callback failed: 0x%x\r\n", ret);
        return ret;
    } // l610
    osal_printk("UART init success!!\r\n");
    return ERRCODE_SUCC;
}
