#include "L610.h"
#include "soc_osal.h"
#include <los_mux.h>
#include "uart.h"
#include "tcxo.h"
#include "osal_event.h"
#include "string.h"

#include "cloud_common.h"
#include "gnss_pos.h"
#include "common_uart.h"
#include "cloud_service.h"

#define MAX_LINE_SIZE 128
#define MQTTMSG_PROCESSING 1
#define MQTTMSG_NONE 0
#define MQTTMSG_MAX_SIZE 512

extern uint32_t l610_uart_send_mux_id;

extern osal_event l610_uart_event;
extern temp_buffer_t l610_temp_buffer;

static uint8_t l610_mqttmsg_buffer[MQTTMSG_MAX_SIZE] = {0}; // MQTT下发消息缓存
static bool g_l610_mqtt_ready = false;

void l610_MQTTPub(char *topic, char *msg);
static bool l610_MQTTSub(char *topic);

static bool l610_wait_queue_keyword(const char *expect, uint32_t timeout_ms)
{
    uint8_t check_buffer[SYNC_MSG_SIZE + 1] = {0};
    unsigned int check_buffer_size = SYNC_MSG_SIZE;
    uint32_t start_time = uapi_tcxo_get_ms();

    while (uapi_tcxo_get_ms() - start_time < timeout_ms) {
        uint32_t elapsed = uapi_tcxo_get_ms() - start_time;
        uint32_t remained = (elapsed >= timeout_ms) ? 0 : (timeout_ms - elapsed);
        check_buffer_size = SYNC_MSG_SIZE;
        if (osal_msg_queue_read_copy(l610_sync_queue, check_buffer, &check_buffer_size, remained) != ERRCODE_SUCC) {
            continue;
        }
        if (expect == NULL || strstr((char *)check_buffer, expect) != NULL) {
            return true;
        }
    }

    return false;
}

static void l610_process_mqtt_message(const char *line_buffer)
{
    const char *topic_start;
    const char *topic_end;
    const char *payload_start;
    const char *payload_end;
    char topic[96] = {0};
    char payload[MQTTMSG_MAX_SIZE] = {0};
    size_t topic_len;
    size_t payload_len;

    if (line_buffer == NULL) {
        return;
    }

    topic_start = strstr(line_buffer, "v1/devices/me/rpc/request/");
    payload_start = strchr(line_buffer, '{');
    payload_end = strrchr(line_buffer, '}');
    if (topic_start == NULL || payload_start == NULL || payload_end == NULL || payload_end < payload_start) {
        osal_printk("L610 mqtt msg ignore: %s\r\n", line_buffer);
        return;
    }

    topic_end = topic_start;
    while (*topic_end != '\0' && *topic_end != '"' && *topic_end != ',' &&
        *topic_end != '\r' && *topic_end != '\n' && *topic_end != ' ') {
        topic_end++;
    }
    topic_len = (size_t)(topic_end - topic_start);
    if (topic_len == 0 || topic_len >= sizeof(topic)) {
        osal_printk("L610 mqtt topic parse failed\r\n");
        return;
    }

    payload_len = (size_t)(payload_end - payload_start + 1);
    if (payload_len >= sizeof(payload)) {
        payload_len = sizeof(payload) - 1;
    }

    if (memcpy_s(topic, sizeof(topic), topic_start, topic_len) != EOK) {
        return;
    }
    topic[topic_len] = '\0';
    if (memcpy_s(payload, sizeof(payload), payload_start, payload_len) != EOK) {
        return;
    }
    payload[payload_len] = '\0';

    cloud_service_handle_rpc(topic, payload);
}

// 供uart注册使用
void l610_uart_rx_callback(const void *buffer, uint16_t length, bool error)
{

    //       osal_printk("From the l610 buffer :\r\n");
    //     uapi_uart_write(DEFAULT_UART_BUS, (uint8_t *)buffer, length, 0);
    //    osal_printk("\r\nEnd by the l610 buffer!!!\r\n");

    if (error || buffer == NULL || length == 0)
        return;
    const uint8_t *buffer_ptr = (const uint8_t *)buffer;

    for (int i = 0; i < length; i++) {
        temp_buffer_push(&l610_temp_buffer, buffer_ptr[i]);
    } // 先存入缓存队列再分包处理

    osal_event_write(&l610_uart_event, L610_RX_EVENT_PROCESS); // 唤醒解析任务
}

/**
 * @brief [发送某指令 -> 判断接受 -> 返回状态值]
 *
 * @param [send_cmd] [发送数据]
 * @param [expect] [期望返回]……
 *
 * @return [收到状态值]
 */
uint8_t l610_uart_send(const char *send_cmd, const char *expect)
{
    uint8_t check_buffer[SYNC_MSG_SIZE + 1] = {0}; // 保证有结束符
    unsigned int check_buffer_size = SYNC_MSG_SIZE;

    osal_printk("clean queue before send cmd to L610\r\n");

    while (osal_msg_queue_read_copy(l610_sync_queue, check_buffer, &check_buffer_size, 0) == ERRCODE_SUCC)
        ; // 清空消息队列

    LOS_MuxPend(l610_uart_send_mux_id, LOS_WAIT_FOREVER);

    uapi_uart_write(L610_UART_BUS, (uint8_t *)send_cmd, strlen(send_cmd), 0);
    osal_printk("MCU >> 4G: %s\r\n", send_cmd);

    LOS_MuxPost(l610_uart_send_mux_id);

    uint32_t start_time = uapi_tcxo_get_ms();
    uint32_t timeout_ms = 2000; // 2秒超时

    while (1) // 2s内处理
    {
        uint32_t rested = uapi_tcxo_get_ms() - start_time;                      // 已用时间
        uint32_t remained = (rested >= timeout_ms) ? 0 : (timeout_ms - rested); // 剩余时间
        if (rested >= timeout_ms)
            break; // 超过超时

        check_buffer_size = SYNC_MSG_SIZE;
        if (osal_msg_queue_read_copy(l610_sync_queue, check_buffer, &check_buffer_size, remained) ==
            ERRCODE_SUCC) { // 说明取到了数据
            if (!expect)
                return BACK_EXPECT; // 没有期望返回，直接返回成功
            else if (strstr((char *)check_buffer, expect))
                return BACK_EXPECT; // 收到期望返回，返回成功
        }
    }

    if (strlen((char *)check_buffer)) // 有数据但是非期望
    {
        osal_printk("L610 UART received unexpected response: %s\r\n", check_buffer);
        return BACK_UNEEXPECT;
    }

    osal_printk("L610 UART send cmd timeout, cmd: %s\r\n", send_cmd);
    return BACK_TIMEOUT; // 超时
}

/*
 *@brief：拨号初始化
 */
bool l610_mipcall_init(void)
{

    if (l610_uart_send("AT+CFUN=15\r\n", NULL) != BACK_EXPECT) // 硬复位L610模组
    {
        osal_printk("*******\r\nCFUN failed.\r\n*******\r\n");
    }
    osal_msleep(5000);

    osal_printk("*******\r\nStart to wait SIM card ready.\r\n*******\r\n");
    if (!l610_wait_queue_keyword("+SIM READY", 5000)) {
        osal_printk("*******\r\nSIM card ready timeout, skip cloud init.\r\n*******\r\n");
        return false;
    }

    temp_buffer_clean(&l610_temp_buffer); // 清空缓存，准备接收后续数据

    l610_uart_send("AT\r\n", "OK");
    l610_uart_send("ATE0\r\n", "OK");
    l610_uart_send("AT+MIPCALL=0\r\n", NULL);

    osal_msleep(1000); // 等模组初始化完成
    uint8_t mipcall_time = 0;
    while (mipcall_time <= 5) {
        l610_uart_send("AT+MIPCALL=1\r\n", "OK");
        osal_msleep(2000);
        mipcall_time++;
        if (l610_uart_send("AT+MIPCALL?\r\n", "+MIPCALL: 1") == BACK_EXPECT) {
            return true;
        }
    }
    osal_printk("*******\r\nMIPCALL failed, skip cloud init.\r\n*******\r\n");
    return false;
}

/// 缺心跳包

/*
 *@brief：连接MQTT服务器
 */
bool l610_mqtt_init(void)
{
    char mqtt_open_ask_cmd[] = "AT+MQTTCLOSE?\r\n";
    uint8_t mipcall_time = 0;
    g_l610_mqtt_ready = false;

    // 设置MQTT登录信息
    char mqtt_login_cmd[200] = {0};
    char username[] = "szh_test";
    char password[] = "Sztu@123456";
    char clientid[] = "c81d15ab52024a3889eef4eb936c01bf";

    sprintf(mqtt_login_cmd, "AT+MQTTUSER=1,\"%s\",\"%s\",\"%s\"\r\n", username, password, clientid);
    l610_uart_send(mqtt_login_cmd, "+MQTTOPEN");
    osal_msleep(1000);

    // 设置MQTT域名和端口
    char mqtt_open_cmd[200] = {0};
    char mqtt_ip[] = "thingskit.aiotcomm.com.cn";
    char mqtt_port[] = "11883";
    sprintf(mqtt_open_cmd, "AT+MQTTOPEN=1,\"%s\",%s,0,60\r\n", mqtt_ip, mqtt_port);

    // 当MQTT未连接时，“AT+MQTTCLOSE?”指令的返回码为“+MQTTCLOSE: 1”
    do {
        l610_uart_send(mqtt_open_cmd, "+MQTTOPEN");
        osal_msleep(1000);
        mipcall_time++;
        if (mipcall_time > 10) {
            osal_printk("*******\r\n MQTTOPEN failed.\r\n*******\r\n");
            return false;
        }
    } while (l610_uart_send(mqtt_open_ask_cmd, "+MQTTCLOSE: 1") != BACK_EXPECT);

    char test_sub_topic[] = "v1/devices/me/rpc/request/+";
    if (!l610_MQTTSub(test_sub_topic)) {
        return false;
    }

    osal_printk("************************\r\n");
    osal_printk("MQTTOPEN Success!\r\n");
    osal_printk("************************\r\n");
    g_l610_mqtt_ready = true;
    return true;
}

static bool l610_MQTTSub(char *topic)
{
    // 1. AT+MQTTSUB=1,"主题",Qos    → 订阅
    char mqtt_cmd[100] = "";
    snprintf(mqtt_cmd, sizeof(mqtt_cmd), "AT+MQTTSUB=1,\"%s\",1\r\n", topic);
    uint8_t retry_num = 0;
    while (l610_uart_send(mqtt_cmd, "OK") != BACK_EXPECT) {
        osal_msleep(1000);
        // l610_mqtt_init();
        retry_num++;
        if (retry_num > 5) {
            osal_printk("topic %s sub faild\r\n", topic);
            return false;
        }
    }
    return true;
}

void l610_MQTTPub(char *topic, char *msg)
{
    if (!g_l610_mqtt_ready) {
        return;
    }
    // AT+MQTTPUB=1,"主题名",QoS,保留位,"消息内容"
    char mqtt_cmd[256] = "";
    snprintf(mqtt_cmd, sizeof(mqtt_cmd), "AT+MQTTPUB=1,\"%s\",1,0,\"%s\"\r\n", topic, msg);
    // uint8_t retry_num = 0;
    l610_uart_send(mqtt_cmd, "OK");
}

void l610_mqtt_publish(const char *topic, const char *msg)
{
    if (topic == NULL || msg == NULL) {
        return;
    }

    l610_MQTTPub((char *)topic, (char *)msg);
}

// void l610_send_location(void)
// {
//     cloud_service_publish_latest_location();
// }

void l610_task(void)
{
    uint8_t byte;
    // 因为异步(MQTT)数据可能很长，放在静态区可以防止大量占用任务栈空间，也解决了截断问题
    static char line_buffer[MAX_BUFFER_SIZE] = {0};
    uint32_t line_pos = 0;
    osal_printk("L610 UART task start\r\n");

    while (1) {
        if (osal_event_read(&l610_uart_event, L610_RX_EVENT_PROCESS, OSAL_WAIT_FOREVER,
                            OSAL_WAITMODE_OR | OSAL_WAITMODE_CLR) != OSAL_FAILURE) {
            // 当事件被触发时，把环形缓冲里的数据全部读出来
            while (temp_buffer_pop(&l610_temp_buffer, &byte) == true) {
                // 防止单行超长载荷被截断
                if (line_pos < sizeof(line_buffer) - 1) {
                    line_buffer[line_pos++] = (char)byte;
                } else {
                    // 超出最大极限512字节
                    line_buffer[sizeof(line_buffer) - 1] = '\0';
                    byte = '\n';
                }

                if (byte == '\n') {
                    line_buffer[line_pos] = '\0';

                    if (line_pos >= 2 && line_buffer[line_pos - 2] == '\r') {
                        line_buffer[line_pos - 2] = '\0';
                    }

                    if (strlen(line_buffer) > 0) {
                        /* ================== 核心路由分拣逻辑 ================== */

                        if (strstr(line_buffer, "+MQTTMSG") != NULL) {
                            if (strchr(line_buffer, '{') != NULL) {
                                memset(l610_mqttmsg_buffer, 0, sizeof(l610_mqttmsg_buffer));
                                strncpy_s((char *)l610_mqttmsg_buffer, sizeof(l610_mqttmsg_buffer), line_buffer,
                                          strlen(line_buffer));
                                osal_printk("Received inline MQTT msg: %s\r\n", l610_mqttmsg_buffer);
                                l610_process_mqtt_message((const char *)l610_mqttmsg_buffer);
                            }
                        } else {
                            // AT 短指令
                            osal_msg_queue_write_copy(l610_sync_queue, line_buffer, SYNC_MSG_SIZE, 0);
                        }
                    }
                    // 处理完这一行，清空缓存，准备接下一行
                    memset(line_buffer, 0, sizeof(line_buffer));
                    line_pos = 0;
                }
            }
        }
    }
}
