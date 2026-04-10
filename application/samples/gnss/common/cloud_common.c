#include "cloud_common.h"
#include "osal_debug.h"
#include "soc_osal.h"
#include "errcode.h"
#include <los_mux.h>

unsigned long l610_sync_queue = 0;

osal_event l610_uart_event = {0};
uint32_t l610_uart_send_mux_id;

temp_buffer_t l610_temp_buffer;
static uint8_t l610_tbuffer[TEMP_BUFFER_SIZE] = {0};

void temp_buffer_init(temp_buffer_t *tb, uint8_t *buffer, uint32_t max_len)
{
    tb->buffer = buffer;
    tb->head = 0;
    tb->tail = 0;
    tb->max_len = max_len;
}

bool temp_buffer_push(temp_buffer_t *tb, const uint8_t data)
{
    uint32_t next = (tb->head + 1) % tb->max_len;
    if (next == tb->tail) {
        osal_printk("temp_buffer_push: Queue is full, data %d is dropped.\r\n", data);
        return false; // 队列满了，发生覆盖或丢弃
    }
    tb->buffer[tb->head] = data;
    tb->head = next;
    return true;
}

bool temp_buffer_pop(temp_buffer_t *tb, uint8_t *data)
{
    if (tb->head == tb->tail) {
        return false; // 队列空了
    }
    *data = tb->buffer[tb->tail];
    tb->tail = (tb->tail + 1) % tb->max_len;
    return true;
}

void temp_buffer_clean(temp_buffer_t *tb)
{
    uint32_t irq_status = osal_irq_lock();
    tb->tail = tb->head; // 直接将 tail 移动到 head 的位置，表示队列为空
    osal_irq_restore(irq_status);
}

void cloud_common_init(void)
{

    LOS_MuxCreate(&l610_uart_send_mux_id);
    osal_event_init(&l610_uart_event); // l610 uart event init

    temp_buffer_init(&l610_temp_buffer, l610_tbuffer, TEMP_BUFFER_SIZE);

    errcode_t ret = osal_msg_queue_create("l610_sync_queue", L610_SYNC_QUEUE_LEN, &l610_sync_queue, 0, SYNC_MSG_SIZE);
    if (ret != ERRCODE_SUCC)
        osal_printk("Failed to create L610 sync queue: 0x%x\r\n", ret);

    osal_printk("cloud_common_init done\r\n");
}
