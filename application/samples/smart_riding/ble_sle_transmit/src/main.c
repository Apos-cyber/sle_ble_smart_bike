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

#include "tcxo.h"

#define SLE_UART_TASK_STACK_SIZE            0x1200
#define SLE_UART_TASK_PRIO                  24
#define BLE_UART_TASK_STACK_SIZE            0x1200
#define BLE_UART_TASK_PRIO                  24


static void uart_entry(void)
{
    // osal_task *task1_handle = NULL;
    if (uapi_clock_control(CLOCK_CONTROL_FREQ_LEVEL_CONFIG, CLOCK_FREQ_LEVEL_HIGH) == ERRCODE_SUCC) {
        osal_printk("Clock config succ.\r\n");
    } else {
        osal_printk("Clock config fail.\r\n");
    }
    // osal_kthread_lock();

    // task1_handle = osal_kthread_create((osal_kthread_handler)sle_uart_client_task, 0, "SLEUartClientTask",
    //                                    SLE_UART_TASK_STACK_SIZE);
    // if (task1_handle != NULL) {
    //     osal_kthread_set_priority(task1_handle, SLE_UART_TASK_PRIO);
    // }
    // osal_kthread_unlock();

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
}

/* Run the ble_uart_entry. */
app_run(uart_entry);