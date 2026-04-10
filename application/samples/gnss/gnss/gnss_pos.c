#include "app_init.h"
#include "common_def.h"
#include "osal_debug.h"
#include "soc_osal.h"
#include "gpio.h"
#include "pinctrl.h"
#include "tcxo.h"

#include "common_uart.h"
#include "gnss_pos.h"
#include "cloud_service.h"

#define GNSS_MAX_BUFFER_SIZE 512

static gnss_msg g_gnss_msg;
static gnss_end_data sample_data = {0};
static gnss_latest_data_t g_gnss_latest = {0};
static uint8_t gnss_rbuff[GNSS_MAX_BUFFER_SIZE];
static uint16_t g_rbuff_pos = 0;

static void gnss_mark_invalid(void)
{
    g_gnss_latest.gps_valid = false;
}

static void gnss_update_latest_fix(const gnss_end_data *data)
{
    if (data == NULL) {
        return;
    }

    sample_data = *data;
    g_gnss_latest.longitude = data->Longitude;
    g_gnss_latest.latitude = data->Latitude;
    g_gnss_latest.longitude_scaled = g_gnss_msg.longitude_bd;
    g_gnss_latest.latitude_scaled = g_gnss_msg.latitude_bd;
    g_gnss_latest.gps_valid = true;
    g_gnss_latest.last_fix_tick = uapi_tcxo_get_ms();
}

void gnss_clear_buffer(void)
{
    g_rbuff_pos = 0;
    memset(gnss_rbuff, 0, sizeof(gnss_rbuff));
} // clear

void gnss_send_cmd(char *data)
{
    uapi_uart_write(GNSS_UART_BUS, (uint8_t *)data, strlen(data), 200);
    osal_printk("send cmd to L80-R ok!!\r\n");
} // 发给L80-R模块cmd

void gnss_uart_rx_callback(const void *buffer, uint16_t length, bool error)
{
    unused(error);
    //    osal_printk("From the gnss buffer :\r\n");
    //     uapi_uart_write(DEFAULT_UART_BUS, (uint8_t *)buffer, length, 0);
    //    osal_printk("\r\nEnd by the gnss buffer!!!\r\n");
    if (g_rbuff_pos + length >= sizeof(gnss_rbuff) - 1) {
        g_rbuff_pos = 0;
        memset(gnss_rbuff, 0, sizeof(gnss_rbuff));
    }

    memcpy(&gnss_rbuff[g_rbuff_pos], buffer, length);
    g_rbuff_pos += length;

    gnss_rbuff[g_rbuff_pos] = '\0'; // 确保结尾包含字符串结束符 \0
}

// 低电平使能GNSS模块
void gnss_pow_enable(void)
{
    uapi_pin_set_mode(GNSS_POW_PIN, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(GNSS_POW_PIN, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(GNSS_POW_PIN, GPIO_LEVEL_LOW);

    uapi_pin_set_mode(2, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(2, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(2, GPIO_LEVEL_LOW);

    uapi_pin_set_mode(3, HAL_PIO_FUNC_GPIO);
    uapi_gpio_set_dir(3, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(3, GPIO_LEVEL_HIGH);
}

void gnss_init(void)
{
    gnss_pow_enable();
    osal_msleep(1000);
    char *cmd_GGA = "$CCMSG,GGA,1,0,*19\r\n"; //  GGA（时间、经纬度、海拔、卫星数）
    char *cmd_GSA = "$CCMSG,GSA,1,0,*0D\r\n"; //  GSA（精度因子、定位质量）
    char *cmd_GSV = "$CCMSG,GSV,1,0,*1A\r\n"; //  GSV（卫星数量、信号强度)

    gnss_send_cmd(cmd_GGA);
    gnss_send_cmd(cmd_GSA);
    gnss_send_cmd(cmd_GSV);

    // 只保留GPRMC等语句，也就是最小定位信息
}

uint8_t NMEA_comma_pos(uint8_t *buf, uint8_t cx)
{
    uint8_t *p = buf;
    while (cx) {
        if (*buf == '*' || *buf < ' ' || *buf > 'z')
            return 0xFF; // 非法或结束符则end
        if (*buf == ',')
            cx--;
        buf++;
    }

    return (buf - p); // 返回找到的第cx个逗号的后一个位置
}

uint32_t NMEA_pow(uint8_t m, uint8_t n)
{
    uint32_t ret = 1;
    while (n--)
        ret *= m;

    return ret;
}

static uint32_t parse_nmea_coord(uint8_t *str, int is_lon)
{
    if (str == NULL || *str == ',' || *str == '*')
        return 0;

    uint32_t degrees = 0;
    uint32_t minutes_int = 0;
    uint32_t minutes_frac = 0;

    int deg_len = is_lon ? 3 : 2;

    // 1. 解析度数
    for (int i = 0; i < deg_len; i++) {
        if (str[i] >= '0' && str[i] <= '9') {
            degrees = degrees * 10 + (str[i] - '0');
        }
    }
    str += deg_len;

    // 2. 解析分的整数部分 (mm)
    for (int i = 0; i < 2; i++) {
        if (str[i] >= '0' && str[i] <= '9') {
            minutes_int = minutes_int * 10 + (str[i] - '0');
        }
    }
    str += 2;

    // 3. 跳过小数点 (如果有)
    if (*str == '.')
        str++;

    // 4. 读取小数部分，扩大它的提取范围，读取多达 6 位以备不时之需
    int frac_count = 0;
    while (*str >= '0' && *str <= '9' && frac_count < 6) {
        minutes_frac = minutes_frac * 10 + (*str - '0');
        str++;
        frac_count++;
    }
    // 统一补齐为 6 位小数
    while (frac_count < 6) {
        minutes_frac *= 10;
        frac_count++;
    }

    // 拼合总的分数并放大 1,000,000 倍 (10^6)
    // 注意：这里的 minutes_int 最大是 59，59 * 1e6 = 59,000,000 不会溢出 32 位整型
    uint32_t total_minutes = minutes_int * 1000000 + minutes_frac;

    // 将 (分/60) 加到度上，并整体放大 1,000,000 倍传出
    // 经度最大是 180 * 1e6 = 180,000,000, 也在 uint32_t 范围内，安全。
    return (degrees * 1000000) + (total_minutes / 60);
}

errcode_t NMEA_analysis(gnss_msg *gnssmsg, uint8_t *buf)
{
    uint8_t posx;
    uint8_t *p4 = (uint8_t *)strstr((const char *)buf, "$GPRMC");

    if (p4 == NULL)
        return ERRCODE_FAIL;

    // 检查定位状态，第二个逗号后
    posx = NMEA_comma_pos(p4, 2);
    if (posx != 0xFF && *(p4 + posx) == 'V') {
        return ERRCODE_FAIL; // 未定位时不计算
    }

    // 第3个逗号: 纬度 (ddmm.mmmm)
    posx = NMEA_comma_pos(p4, 3);
    if (posx != 0xFF) {
        // 0 代表解析纬度(2位度数)
        gnssmsg->latitude_bd = parse_nmea_coord(p4 + posx, 0);
    }

    // 第4个逗号: 北纬/南纬(N/S)
    posx = NMEA_comma_pos(p4, 4);
    if (posx != 0xFF)
        gnssmsg->nshemi_bd = *(p4 + posx);

    // 第5个逗号: 经度 (dddmm.mmmm)
    posx = NMEA_comma_pos(p4, 5);
    if (posx != 0xFF) {
        // 1 代表解析经度(3位度数)
        gnssmsg->longitude_bd = parse_nmea_coord(p4 + posx, 1);
    }

    // 第6个逗号: 东经/西经(E/W)
    posx = NMEA_comma_pos(p4, 6);
    if (posx != 0xFF)
        gnssmsg->ewhemi_bd = *(p4 + posx);

    return ERRCODE_SUCC;
}
// ============================================

errcode_t gnss_read_data(gnss_end_data *ReadData)
{
    if (strstr((const char *)gnss_rbuff, "$GPRMC") == NULL) {
        return ERRCODE_FAIL;
    }

    errcode_t ret = NMEA_analysis(&g_gnss_msg, (uint8_t *)gnss_rbuff);
    if (ret != ERRCODE_SUCC)
        return ret;

    // 但是这里也把它从除以 100000 变成除以 1000000：
    ReadData->Latitude = (double)((double)g_gnss_msg.latitude_bd / 1000000);
    ReadData->Longitude = (double)((double)g_gnss_msg.longitude_bd / 1000000);
    return ERRCODE_SUCC;
}

void gnss_get_data(double *longitude, double *latitude)
{
    *longitude = sample_data.Longitude;
    *latitude = sample_data.Latitude;
}

void gnss_get_latest_state(gnss_latest_data_t *state)
{
    if (state == NULL) {
        return;
    }

    *state = g_gnss_latest;
}

bool gnss_is_valid(void)
{
    return g_gnss_latest.gps_valid;
}

void gnss_task(void)
{
    gnss_end_data read_data = {0};
    uint32_t last_report_ms = 0;
    bool last_report_valid = g_gnss_latest.gps_valid;

    gnss_init();
    while (1) {
        if (strlen((char *)gnss_rbuff) > 100) {
            errcode_t ret = gnss_read_data(&read_data);
            if (ret != ERRCODE_SUCC) {
                gnss_mark_invalid();
                // osal_printk("waitting for Real GNSS data...\r\n");
                // osal_printk("Current Buf Data: %s\r\n", gnss_rbuff);
            } else {
                gnss_update_latest_fix(&read_data);
            }
            gnss_clear_buffer();
        }

        uint32_t now_ms = uapi_tcxo_get_ms();
        bool current_valid = g_gnss_latest.gps_valid;
        uint32_t current_period_ms = current_valid ? GNSS_REPORT_PERIOD_VALID_MS : GNSS_REPORT_PERIOD_INVALID_MS;
        bool should_report_now = (last_report_ms == 0) || (current_valid != last_report_valid) ||
            ((now_ms - last_report_ms) >= current_period_ms);
        if (should_report_now) {
            last_report_ms = now_ms;
            last_report_valid = current_valid;
            cloud_service_publish_latest_location();
            if (!current_valid) {
                osal_printk("[GNSS] position invalid, publish with 60s pacing\r\n");
            }
        }
        osal_msleep(1000);
    }
}
