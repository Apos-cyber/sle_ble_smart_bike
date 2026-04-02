/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: SLE ADV Config. \n
 *
 * History: \n
 * 2023-07-17, Create file. \n
 */

#ifndef SLE_SERVER_ADV_H
#define SLE_SERVER_ADV_H

/* LED Control Macros */
#define HEAD        0xAA
#define Flag_led    0x02
#define Flag_button 0x01

#define LED_ON      0x01
#define LED_OFF     0x00
#define LED_LEFT    0x02
#define LED_RIGHT   0x03

/* Control LED Commands: HEAD FLAG TYPE LEN VALUE */
#define CTRL_LED_OPEN   { HEAD, Flag_led, 0x01, 0x01, LED_ON }
#define CTRL_LED_CLOSE  { HEAD, Flag_led, 0x01, 0x01, LED_OFF }
#define CTRL_LED_LEFT   { HEAD, Flag_led, 0x01, 0x01, LED_LEFT }
#define CTRL_LED_RIGHT  { HEAD, Flag_led, 0x01, 0x01, LED_RIGHT }



typedef struct sle_adv_common_value {
    uint8_t type;
    uint8_t length;
    uint8_t value;
} le_adv_common_t;

typedef enum sle_adv_channel {
    SLE_ADV_CHANNEL_MAP_77                 = 0x01,
    SLE_ADV_CHANNEL_MAP_78                 = 0x02,
    SLE_ADV_CHANNEL_MAP_79                 = 0x04,
    SLE_ADV_CHANNEL_MAP_DEFAULT            = 0x07
} sle_adv_channel_map_t;

typedef enum sle_adv_data {
    SLE_ADV_DATA_TYPE_DISCOVERY_LEVEL                              = 0x01,   /* 发现等级 */
    SLE_ADV_DATA_TYPE_ACCESS_MODE                                  = 0x02,   /* 接入层能力 */
    SLE_ADV_DATA_TYPE_SERVICE_DATA_16BIT_UUID                      = 0x03,   /* 标准服务数据信息 */
    SLE_ADV_DATA_TYPE_SERVICE_DATA_128BIT_UUID                     = 0x04,   /* 自定义服务数据信息 */
    SLE_ADV_DATA_TYPE_COMPLETE_LIST_OF_16BIT_SERVICE_UUIDS         = 0x05,   /* 完整标准服务标识列表 */
    SLE_ADV_DATA_TYPE_COMPLETE_LIST_OF_128BIT_SERVICE_UUIDS        = 0x06,   /* 完整自定义服务标识列表 */
    SLE_ADV_DATA_TYPE_INCOMPLETE_LIST_OF_16BIT_SERVICE_UUIDS       = 0x07,   /* 部分标准服务标识列表 */
    SLE_ADV_DATA_TYPE_INCOMPLETE_LIST_OF_128BIT_SERVICE_UUIDS      = 0x08,   /* 部分自定义服务标识列表 */
    SLE_ADV_DATA_TYPE_SERVICE_STRUCTURE_HASH_VALUE                 = 0x09,   /* 服务结构散列值 */
    SLE_ADV_DATA_TYPE_SHORTENED_LOCAL_NAME                         = 0x0A,   /* 设备缩写本地名称 */
    SLE_ADV_DATA_TYPE_COMPLETE_LOCAL_NAME                          = 0x0B,   /* 设备完整本地名称 */
    SLE_ADV_DATA_TYPE_TX_POWER_LEVEL                               = 0x0C,   /* 广播发送功率 */
    SLE_ADV_DATA_TYPE_SLB_COMMUNICATION_DOMAIN                     = 0x0D,   /* SLB通信域域名 */
    SLE_ADV_DATA_TYPE_SLB_MEDIA_ACCESS_LAYER_ID                    = 0x0E,   /* SLB媒体接入层标识 */
    SLE_ADV_DATA_TYPE_EXTENDED                                     = 0xFE,   /* 数据类型扩展 */
    SLE_ADV_DATA_TYPE_MANUFACTURER_SPECIFIC_DATA                   = 0xFF    /* 厂商自定义信息 */
} sle_adv_data_type;

errcode_t sle_dev_register_cbks(void);
errcode_t sle_uart_server_adv_init(void);

errcode_t sle_uart_announce_register_cbks(void);

/**
 * @brief 设置SLE设备名称
 * @param name 设备名称字符串
 * @param len 设备名称长度
 */
void sle_set_device_name(const uint8_t *name, uint8_t len);

void sle_control_device_adv(uint8_t *adv_addr,uint8_t* adv_data,uint8_t adv_handle);

#endif