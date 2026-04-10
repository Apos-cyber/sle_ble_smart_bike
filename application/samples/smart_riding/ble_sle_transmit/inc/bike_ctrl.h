#ifndef BIKE_CTRL_H
#define BIKE_CTRL_H

#include <stdint.h>

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif
#endif

#define LOCK_GPIO_PIN1 29
#define LOCK_GPIO_PIN2 30

typedef enum {
    BIKE_CTRL_SOURCE_BLE = 0,
    BIKE_CTRL_SOURCE_SLE = 1,
} bike_ctrl_source_t;

void bike_ctrl_init(void);
void bike_ctrl_dispatch(const uint8_t *frame, uint32_t len, bike_ctrl_source_t source);

#ifdef __cplusplus
#if __cplusplus
}
#endif
#endif

#endif
