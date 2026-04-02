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
#include "gpio.h"

#include "tcxo.h"
#include "light.h"

/* 车锁 GPIO 初始化 */
static void lock_gpio_init(void)
{
    /* 设置 GPIO 复用为 GPIO 功能 */
    uapi_pin_set_mode(LOCK_GPIO_PIN1, HAL_PIO_FUNC_GPIO);
    uapi_pin_set_mode(LOCK_GPIO_PIN2, HAL_PIO_FUNC_GPIO);

    /* 设置 GPIO 方向为输出 */
    uapi_gpio_set_dir(LOCK_GPIO_PIN1, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_dir(LOCK_GPIO_PIN2, GPIO_DIRECTION_OUTPUT);

    /* 初始拉高 (开锁状态) */
    uapi_gpio_set_val(LOCK_GPIO_PIN1, GPIO_LEVEL_HIGH);
    uapi_gpio_set_val(LOCK_GPIO_PIN2, GPIO_LEVEL_HIGH);

    osal_printk("Lock GPIO init: pin9=%d, pin10=%d\r\n", LOCK_GPIO_PIN1, LOCK_GPIO_PIN2);
}

#define SLE_UART_TASK_STACK_SIZE            0x1000
#define SLE_UART_TASK_PRIO                  24
#define BLE_UART_TASK_STACK_SIZE            0x800
#define BLE_UART_TASK_PRIO                  24


static void uart_entry(void)
{
    if (uapi_clock_control(CLOCK_CONTROL_FREQ_LEVEL_CONFIG, CLOCK_FREQ_LEVEL_HIGH) == ERRCODE_SUCC) {
        osal_printk("Clock config succ.\r\n");
    } else {
        osal_printk("Clock config fail.\r\n");
    }

    buzzer_init();
    lock_gpio_init();

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