#include "motor.h"
#include "gpio.h"
#include "pinctrl.h"

void motor_init(void)
{
    uapi_pin_set_mode(MOTOR_GPIO_A, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(MOTOR_GPIO_A, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(MOTOR_GPIO_A, GPIO_LEVEL_LOW);

    uapi_pin_set_mode(MOTOR_GPIO_B, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(MOTOR_GPIO_B, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(MOTOR_GPIO_B, GPIO_LEVEL_LOW);
}

void motor_forward(void)
{
    uapi_gpio_set_val(MOTOR_GPIO_A, GPIO_LEVEL_HIGH);
    uapi_gpio_set_val(MOTOR_GPIO_B, GPIO_LEVEL_HIGH);
}

void motor_reverse(void)
{
    uapi_gpio_set_val(MOTOR_GPIO_A, GPIO_LEVEL_LOW);
    uapi_gpio_set_val(MOTOR_GPIO_B, GPIO_LEVEL_LOW);
}

void motor_stop(void)
{
    uapi_gpio_set_val(MOTOR_GPIO_A, GPIO_LEVEL_LOW);
    uapi_gpio_set_val(MOTOR_GPIO_B, GPIO_LEVEL_LOW);
}
