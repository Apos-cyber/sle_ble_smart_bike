#include "app_init.h"
#include "systick.h"
#include "soc_osal.h"
#include "common_def.h"
#include "pinctrl.h"
#include "osal_debug.h"
#include "error.h"

#include "sle_errcode.h"
#include "uart.h"
#include "sle_uart.h"
#include "ble_uart.h"
#include "pm_clock.h"
#include "buzzer.h"
#include "bike_ctrl.h"
#include "light.h"
#include "cloud_service.h"
#include "cloud_common.h"
#include "common_uart.h"
#include "gnss_pos.h"
#include "L610.h"

#define SLE_UART_TASK_STACK_SIZE            0x1000
#define SLE_UART_TASK_PRIO                  24
#define BLE_UART_TASK_STACK_SIZE            0x800
#define BLE_UART_TASK_PRIO                  24
#define CLOUD_INIT_TASK_STACK_SIZE          0x1000
#define CLOUD_INIT_TASK_PRIO                23
#define L610_TASK_STACK_SIZE                0x1400
#define L610_TASK_PRIO                      23
#define GNSS_TASK_STACK_SIZE                0x0C00
#define GNSS_TASK_PRIO                      26

static void smart_bike_cloud_init_task(void)
{
    bool mipcall_ok;
    bool mqtt_ok;
    osal_task *task_handle = NULL;

    osal_printk("Smart bike cloud init start\r\n");
    cloud_common_init();
    if (l610_uart_init() != ERRCODE_SUCC) {
        osal_printk("Smart bike uart init failed\r\n");
        return;
    }

    task_handle = osal_kthread_create((osal_kthread_handler)l610_task, 0, "l610_task", L610_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, L610_TASK_PRIO);
    } else {
        osal_printk("Smart bike cloud init failed: no memory for l610 task\r\n");
        return;
    }

    osal_msleep(2000); // 等待l610任务完成初始化
    mipcall_ok = l610_mipcall_init();
    mqtt_ok = false;
    if (mipcall_ok) {
        mqtt_ok = l610_mqtt_init();
    }
    if (!mipcall_ok || !mqtt_ok) {
        osal_printk("Smart bike cloud degraded: 4G/MQTT init failed\r\n");
        return;
    }

    task_handle = osal_kthread_create((osal_kthread_handler)gnss_task, 0, "gnss_task", GNSS_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, GNSS_TASK_PRIO);
    } else {
        osal_printk("Smart bike cloud degraded: no memory for gnss task\r\n");
        return;
    }

    osal_printk("Smart bike cloud service periodic publish runs in l610 task\r\n");
}

static void uart_entry(void)
{
    errcode_t light_ret;

    if (uapi_clock_control(CLOCK_CONTROL_FREQ_LEVEL_CONFIG, CLOCK_FREQ_LEVEL_HIGH) == ERRCODE_SUCC) {
        osal_printk("Clock config succ.\r\n");
    } else {
        osal_printk("Clock config fail.\r\n");
    }
    osal_task *task1_handle =NULL;
    light_ret = light_init(); /* 预初始化RGB/SPI，避免首包控制时再初始化 */
    if (light_ret != ERRCODE_SUCC) {
        osal_printk("Light init fail: 0x%x\r\n", light_ret);
    }
    bike_ctrl_init();
    buzzer_init();

    osal_kthread_lock();
    task1_handle = osal_kthread_create((osal_kthread_handler)mode_change_task, 0, "MODE_CHANGE_Task",
                                       BLE_UART_TASK_STACK_SIZE);
    if (task1_handle != NULL) {
        osal_kthread_set_priority(task1_handle, BLE_UART_TASK_PRIO);
    }
    osal_kthread_unlock();

    osal_task *task2_handle = NULL;
    osal_kthread_lock();
    task2_handle = osal_kthread_create((osal_kthread_handler)ble_uart_server_task, 0, "BLEUartServerTask",
                                       BLE_UART_TASK_STACK_SIZE);
    if (task2_handle != NULL) {
        osal_kthread_set_priority(task2_handle, BLE_UART_TASK_PRIO);
    }
    osal_kthread_unlock();

    osal_task *task3_handle = NULL;
    osal_kthread_lock();
    task3_handle = osal_kthread_create((osal_kthread_handler)sle_uart_server_task, 0, "SLEUartServerTask",
                                       SLE_UART_TASK_STACK_SIZE);
    if (task3_handle != NULL) {
        osal_kthread_set_priority(task3_handle, SLE_UART_TASK_PRIO);
    }
    osal_kthread_unlock();

    osal_task *task4_handle = NULL;
    osal_kthread_lock();
    task4_handle = osal_kthread_create((osal_kthread_handler)smart_bike_cloud_init_task, 0,
        "SmartBikeCloudInit", CLOUD_INIT_TASK_STACK_SIZE);
    if (task4_handle != NULL) {
        osal_kthread_set_priority(task4_handle, CLOUD_INIT_TASK_PRIO);
    }
    osal_kthread_unlock();
}

/* Run the ble_uart_entry. */
app_run(uart_entry);
