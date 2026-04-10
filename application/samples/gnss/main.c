#include "soc_osal.h"
#include "app_init.h"
#include "common_def.h"
#include "osal_debug.h"
#include "L610.h"
#include "gnss_pos.h"
#include "cloud_common.h"
#include "common_uart.h"



#define INIT_TASK_PRIO                     24
#define INIT_TASK_STACK_SIZE               0x1024

#define L610_TASK_STACK_SIZE 0x2000
#define L610_TASK_PRIO 23

#define GNSS_TASK_STACK_SIZE 0x1024
#define GNSS_TASK_PRIO 26


void init_task(void)
{
    
    osal_printk("Init task start\r\n");
    cloud_common_init();//初始化云平台公共资源，如消息队列、事件等
    uart_init();

    osal_task *task_l610 = osal_kthread_create((osal_kthread_handler)l610_task,0,"l610_task",L610_TASK_STACK_SIZE);
    if(task_l610)  osal_kthread_set_priority(task_l610, L610_TASK_PRIO);
      
        
    l610_mipcall_init();//启动4G模组并拨号
    l610_mqtt_init();//MQTT连接
    osal_msleep(3000);

    osal_task *task_gnss = osal_kthread_create((osal_kthread_handler)gnss_task,0,"gnss_task",GNSS_TASK_STACK_SIZE);
    if(task_gnss)  osal_kthread_set_priority(task_gnss, GNSS_TASK_PRIO);
    
}


static void main_entry(void)
{

    osal_kthread_lock();

    osal_task *task_init = osal_kthread_create((osal_kthread_handler)init_task,0,"init_task",INIT_TASK_STACK_SIZE);
    if(task_init)  osal_kthread_set_priority(task_init,24);

    osal_kthread_unlock();
}

app_run(main_entry);
