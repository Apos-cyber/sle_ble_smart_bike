#include "bike_ctrl.h"

#include "osal_debug.h"
#include "soc_osal.h"
#include "securec.h"
#include "gpio.h"
#include "pinctrl.h"
#include "bts_le_gap.h"

#include "ble_uart_server.h"
#include "sle_uart_server_adv.h"
#include "buzzer.h"
#include "light.h"

#define BIKE_CTRL_LOG "[bike ctrl]"
#define BIKE_LOCK_RESET_DELAY_MS 5000

static osal_timer g_lock_timer;
static uint8_t g_lock_timer_inited = 0;
static uint8_t g_lock_final_state = GPIO_LEVEL_HIGH;

static const char *bike_ctrl_source_name(bike_ctrl_source_t source)
{
    return (source == BIKE_CTRL_SOURCE_SLE) ? "SLE" : "BLE";
}

static void bike_ctrl_lock_timer_callback(unsigned long data)
{
    g_lock_final_state = (uint8_t)data;
    uapi_gpio_set_val(LOCK_GPIO_PIN1, g_lock_final_state ? GPIO_LEVEL_HIGH : GPIO_LEVEL_LOW);
    uapi_gpio_set_val(LOCK_GPIO_PIN2, g_lock_final_state ? GPIO_LEVEL_HIGH : GPIO_LEVEL_LOW);
    osal_printk("%s lock auto reset to %s\r\n", BIKE_CTRL_LOG,
        g_lock_final_state ? "HIGH" : "LOW");
}

static void bike_ctrl_lock_timer_init(void)
{
    if (g_lock_timer_inited != 0) {
        return;
    }

    g_lock_timer.handler = bike_ctrl_lock_timer_callback;
    g_lock_timer.data = GPIO_LEVEL_HIGH;
    g_lock_timer.interval = BIKE_LOCK_RESET_DELAY_MS;
    osal_timer_init(&g_lock_timer);
    g_lock_timer_inited = 1;
}

static void bike_ctrl_lock_timer_start(uint8_t final_state)
{
    bike_ctrl_lock_timer_init();
    g_lock_timer.data = final_state;
    osal_timer_mod(&g_lock_timer, BIKE_LOCK_RESET_DELAY_MS);
}

void bike_ctrl_init(void)
{
    bike_ctrl_lock_timer_init();

    uapi_pin_set_mode(LOCK_GPIO_PIN1, HAL_PIO_FUNC_GPIO);
    uapi_pin_set_mode(LOCK_GPIO_PIN2, HAL_PIO_FUNC_GPIO);

    uapi_gpio_set_dir(LOCK_GPIO_PIN1, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_dir(LOCK_GPIO_PIN2, GPIO_DIRECTION_OUTPUT);

    uapi_gpio_set_val(LOCK_GPIO_PIN1, GPIO_LEVEL_HIGH);
    uapi_gpio_set_val(LOCK_GPIO_PIN2, GPIO_LEVEL_HIGH);

    osal_printk("%s lock gpio init: pin%d=%d, pin%d=%d\r\n", BIKE_CTRL_LOG,
        LOCK_GPIO_PIN1, LOCK_GPIO_PIN1, LOCK_GPIO_PIN2, LOCK_GPIO_PIN2);
}

static void bike_ctrl_handle_lock(uint8_t value)
{
    if (value == 0x01) {
        osal_printk("%s lock closing (low for 5s)\r\n", BIKE_CTRL_LOG);
        uapi_gpio_set_val(LOCK_GPIO_PIN1, GPIO_LEVEL_LOW);
        uapi_gpio_set_val(LOCK_GPIO_PIN2, GPIO_LEVEL_LOW);
        bike_ctrl_lock_timer_start(GPIO_LEVEL_HIGH);
    } else if (value == 0x00) {
        osal_printk("%s lock opening (high for 5s)\r\n", BIKE_CTRL_LOG);
        uapi_gpio_set_val(LOCK_GPIO_PIN1, GPIO_LEVEL_HIGH);
        uapi_gpio_set_val(LOCK_GPIO_PIN2, GPIO_LEVEL_HIGH);
        bike_ctrl_lock_timer_start(GPIO_LEVEL_LOW);
    } else {
        osal_printk("%s unknown lock value: 0x%02x\r\n", BIKE_CTRL_LOG, value);
    }
}

static void bike_ctrl_handle_light(uint8_t value)
{
    switch (value) {
        case 0x00:
            light_off();
            break;
        case 0x01:
            light_on(LIGHT_COLOR_ORANGE);
            break;
        case 0x02:
            light_turn_left(LIGHT_COLOR_YELLOW);
            break;
        case 0x03:
            light_turn_right(LIGHT_COLOR_YELLOW);
            break;
        default:
            osal_printk("%s unknown light mode: 0x%02x\r\n", BIKE_CTRL_LOG, value);
            break;
    }
}

static void bike_ctrl_handle_find_bike(uint8_t value)
{
    if (value == 0x01) {
        buzzer_play_alarm();
    } else if (value == 0x00) {
        buzzer_stop_alarm();
    } else {
        osal_printk("%s unknown find-bike value: 0x%02x\r\n", BIKE_CTRL_LOG, value);
    }
}

static void bike_ctrl_handle_rename(const uint8_t *value, uint8_t len, bike_ctrl_source_t source)
{
    if (len == 0 || value == NULL) {
        return;
    }

    if (source == BIKE_CTRL_SOURCE_BLE) {
        ble_uart_set_device_name_value(value, len);
        gap_ble_set_local_name(value, len);
        return;
    }

    sle_set_device_name(value, len);
}

void bike_ctrl_dispatch(const uint8_t *frame, uint32_t len, bike_ctrl_source_t source)
{
    uint8_t flag;
    uint8_t payload_len;
    const uint8_t *value;

    if (frame == NULL || len < 5) {
        osal_printk("%s %s invalid buffer\r\n", BIKE_CTRL_LOG, bike_ctrl_source_name(source));
        return;
    }

    if (frame[0] != 0xAA) {
        osal_printk("%s %s invalid head: 0x%02x\r\n", BIKE_CTRL_LOG, bike_ctrl_source_name(source), frame[0]);
        return;
    }

    payload_len = frame[3];
    if (len < (uint32_t)(payload_len + 5)) {
        osal_printk("%s %s invalid length: buffer_size=%u expected=%u\r\n", BIKE_CTRL_LOG,
            bike_ctrl_source_name(source), len, payload_len + 5);
        return;
    }

    if (frame[payload_len + 4] != 0xBB) {
        osal_printk("%s %s invalid end\r\n", BIKE_CTRL_LOG, bike_ctrl_source_name(source));
        return;
    }

    flag = frame[1];
    value = &frame[4];

    osal_printk("%s %s protocol: flag=0x%02x, type=0x%02x, len=%u\r\n", BIKE_CTRL_LOG,
        bike_ctrl_source_name(source), flag, frame[2], payload_len);

    switch (flag) {
        case 0x01:
            if (payload_len < 1) {
                return;
            }
            bike_ctrl_handle_lock(value[0]);
            break;
        case 0x02:
            if (payload_len < 1) {
                return;
            }
            bike_ctrl_handle_light(value[0]);
            break;
        case 0x03:
            if (payload_len < 1) {
                return;
            }
            bike_ctrl_handle_find_bike(value[0]);
            break;
        case 0x04:
            bike_ctrl_handle_rename(value, payload_len, source);
            break;
        case 0x05:
            osal_printk("%s %s unbind device\r\n", BIKE_CTRL_LOG, bike_ctrl_source_name(source));
            break;
        default:
            osal_printk("%s %s unknown flag: 0x%02x\r\n", BIKE_CTRL_LOG, bike_ctrl_source_name(source), flag);
            break;
    }
}
