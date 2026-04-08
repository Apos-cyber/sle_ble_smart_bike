#include "app_init.h"
#include "systick.h"
#include "soc_osal.h"
#include "common_def.h"
#include "pinctrl.h"
#include "osal_debug.h"
#include "error.h"

#include "sle_device_discovery.h"
#include "sle_connection_manager.h"
#include "sle_errcode.h"
#include "uart.h"
#include "my_uart.h"

#include "sle_client.h"

#include "los_event.h"
#include "los_task.h"
#include "securec.h"

UINT32 g_testTaskId;

EVENT_CB_S g_exampleEvent;


#define UART_STACK_SIZE 0x1200
#define UART_TASK_PRIO 24

#define SLE_ADV_STACK_SIZE 0x1200
#define SLE_ADV_TASK_PRIO 24

uint8_t g_send_mac[8][6];
uint8_t save_flag=0;

void uart_task(void)
{
    // LOS_EventInit(&g_exampleEvent);

    errcode_t ret=uart_init();
    if(ret!=ERRCODE_SUCC)
    {
        osal_printk("uart init fail:0x%2x\r\n",ret);
        return;
    }
    else
        osal_printk("uart_init SUCC!!!\r\n");
    while (1)
    {
        if(receive_flag)//待处理数据
        {
            if(save_MAC())
            {    
                // osal_printk("save_g_send_mac: %02x:%02x:%02x:%02x:%02x:%02x ,SUCC!!!\r\n",g_send_mac[0],g_send_mac[1],g_send_mac[2],g_send_mac[3],g_send_mac[4],g_send_mac[5]);
                memset(connect_book,0,sizeof(connect_book));
                save_flag=1;
            }
            else
            {
                osal_printk("save_g_send_mac FAIL!!!\r\n");
            }


            memset(g_rx_buffer,0,MAX_BUFFER_SIZE);//执行完一系列解析操作后要把缓冲区清空，将保存到的数据放到另一个缓冲区（最好开一个队列）。
            receive_flag=0;
        }
        osal_msleep(100);//为stop广播腾出时间
    }
    
}

void sle_adv_task(void)
{
    sle_init();

    while (1)
    {
        if(save_flag)
        {
            osal_printk("start seek!!!!!\r\n");
            sle_start_scan();

            save_flag=0;
        }
        osal_msleep(500);
    }
}

static void debugger_entry(void)
{
    osal_task *task1=NULL;
    osal_task *task2=NULL;
    osal_kthread_lock();
    task1=osal_kthread_create((osal_kthread_handler)uart_task,0,"uart_task",UART_STACK_SIZE);
    if(task1!=NULL)
    {
        osal_kthread_set_priority(task1,UART_TASK_PRIO);
    }
    osal_kthread_unlock();

    osal_kthread_lock();
    task2=osal_kthread_create((osal_kthread_handler)sle_adv_task,0,"sle_adv_task",SLE_ADV_STACK_SIZE);
    if(task2!=NULL)
    {
        osal_kthread_set_priority(task2,SLE_ADV_TASK_PRIO);
    }
    osal_kthread_unlock();
}
app_run(debugger_entry);