#ifndef  __GNSS_POS_H__
#define __GNSS_POS_H__

#include "stdint.h"
#include "stdbool.h"

#define GNSS_POW_PIN 27



typedef struct{
    uint32_t latitude_bd;                    //纬度   分扩大100000倍，实际要除以100000
    uint8_t nshemi_bd;                        //北纬/南纬,N:北纬;S:南纬    
    uint32_t longitude_bd;              //经度 分扩大100000倍,实际要除以100000
    uint8_t ewhemi_bd;                        //东经/西经,E:东经;W:西经
} gnss_msg;

typedef struct {
    double    Longitude;         // 经度
    double    Latitude;          // 纬度
} gnss_end_data;

typedef struct {
    double longitude;
    double latitude;
    uint32_t longitude_scaled;
    uint32_t latitude_scaled;
    bool gps_valid;
    uint32_t last_fix_tick;
} gnss_latest_data_t;

void gnss_uart_rx_callback(const void *buffer, uint16_t length, bool error);
void gnss_get_data(double* longitude,double* latitude);
void gnss_get_latest_state(gnss_latest_data_t *state);
bool gnss_is_valid(void);
void gnss_init(void);
void gnss_task(void);





#endif // __GNSS_POS_H__
