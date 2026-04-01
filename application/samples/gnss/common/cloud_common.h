#ifndef CLOUD_COMMON_H
#define CLOUD_COMMON_H


#include "stdint.h"
#include "stdbool.h"
#include "osal_event.h"

typedef struct{
    uint8_t *buffer;
    uint32_t head;
    uint32_t tail;
    uint32_t max_len;

}temp_buffer_t;

#define L610_SYNC_QUEUE_LEN 4
#define L610_ASYNC_QUEUE_LEN 5
#define TEMP_BUFFER_SIZE 512
#define SYNC_MSG_SIZE 64
#define ASYNC_MSG_SIZE 256

#define L610_RX_EVENT_PROCESS (1U << 1)
#define L610_RX_EVENT_NONE (1U << 0)


extern unsigned long l610_sync_queue;
extern osal_event l610_uart_event;
extern uint32_t l610_uart_send_mux_id;

void cloud_common_init(void);
bool temp_buffer_push(temp_buffer_t *tb,const uint8_t data);
bool temp_buffer_pop(temp_buffer_t *tb,uint8_t *data);
void temp_buffer_clean(temp_buffer_t *tb);

#endif // !CLOUD_COMMON_H
