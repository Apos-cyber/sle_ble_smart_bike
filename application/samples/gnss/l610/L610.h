#ifndef __L610_H__
#define __L610_H__

#include "stdint.h"
#include "stdbool.h"





typedef enum{
     BACK_EXPECT,
     BACK_UNEEXPECT,
     BACK_TIMEOUT 
}l610_checker_t;



void l610_task(void);
void l610_uart_rx_callback(const void *buffer, uint16_t length, bool error);
bool l610_mipcall_init(void);
bool l610_mqtt_init(void);
void l610_mqtt_publish(const char *topic, const char *msg);
void l610_send_location(void);

#endif
