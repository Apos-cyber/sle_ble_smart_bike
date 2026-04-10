#ifndef __COMMON_UART_H__
#define __COMMON_UART_H__

#include "pinctrl_porting.h"
#include "errcode.h"
#include "uart.h"

#define MAX_BUFFER_SIZE 512

#define GNSS_TXD_MODE HAL_PIO_UART_H0_TXD
#define GNSS_RXD_MODE HAL_PIO_UART_H0_RXD
#define GNSS_TXD_PIN 17
#define GNSS_RXD_PIN 18

#define GNSS_UART_BUS UART_BUS_1
#define GNSS_UART_BAUDRATE 9600



#define L610_UART_TXD_PIN_MODE HAL_PIO_UART_L1_TXD
#define L610_UART_RXD_PIN_MODE HAL_PIO_UART_L1_RXD
#define L610_TXD_PIN 9
#define L610_RXD_PIN 10

#define L610_UART_BUS UART_BUS_2
#define L610_UART_BAUDRATE 115200


#define DEFAULT_UART_BUS UART_BUS_0


void gnss_clear_buffer(void);
void gnss_send_cmd(char* data);
errcode_t l610_uart_init(void);





#endif 