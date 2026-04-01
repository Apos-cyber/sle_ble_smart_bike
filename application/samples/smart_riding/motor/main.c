/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 */
#include "motor.h"
#include "soc_osal.h"
#include "app_init.h"

#define MOTOR_TASK_PRIO 24
#define MOTOR_STACK_SIZE 0x1000

static int motor_task(const char *arg)
{
    unused(arg);
    motor_init();

    while (1) {
        motor_forward();
        osal_printk("Forward\r\n");
        osal_msleep(3000);

        motor_stop();
        osal_printk("Stop\r\n");
        osal_msleep(1000);

        motor_reverse();
        osal_printk("Reverse\r\n");
        osal_msleep(3000);

        motor_stop();
        osal_msleep(1000);
    }
}

static void motor_entry(void)
{
    osal_task *task = osal_kthread_create((osal_kthread_handler)motor_task, 0,
                                          "MotorTask", MOTOR_STACK_SIZE);
    if (task != NULL) {
        osal_kthread_set_priority(task, MOTOR_TASK_PRIO);
    }
}

app_run(motor_entry);
