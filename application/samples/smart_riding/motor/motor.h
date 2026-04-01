/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 */
#ifndef MOTOR_H
#define MOTOR_H

#define MOTOR_GPIO_A 0
#define MOTOR_GPIO_B 1

void motor_init(void);
void motor_forward(void);
void motor_reverse(void);
void motor_stop(void);

#endif
