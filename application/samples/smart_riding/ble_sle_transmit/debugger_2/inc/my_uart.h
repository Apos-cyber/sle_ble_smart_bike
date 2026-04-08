#ifndef MY_UART_H
#define MY_UART_H

#define MAX_BUFFER_SIZE 500//缓冲区大小，condition：FULL触发条件
#define TRIGGER_SIZE //condition：SUFFICIENT_DATA触发条件

#define UART_BUS_ID             0
#define UART_TXD_PIN            17
#define UART_RXD_PIN            18
#define UART_PIN_MODE           1
#define UART_BAUDRATE           115200

extern uint8_t g_rx_buffer[MAX_BUFFER_SIZE];

extern uint8_t receive_flag;

extern uint8_t mac_num;

errcode_t uart_init(void);

bool save_MAC();

#endif