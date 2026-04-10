#include "cloud_service.h"

#include "osal_debug.h"
#include "soc_osal.h"
#include "securec.h"

#include "gnss_pos.h"
#include "L610.h"

#define CLOUD_SERVICE_LOG "[cloud service]"
#define CLOUD_LOCATION_TOPIC "v1/devices/me/telemetry"
#define CLOUD_RPC_METHOD_GET_GPS "getGps"
#define CLOUD_RPC_REQUEST_PREFIX "v1/devices/me/rpc/request/"
#define CLOUD_RPC_RESPONSE_PREFIX "v1/devices/me/rpc/response/"

static void cloud_service_build_location_json(char *buffer, size_t buffer_size, const gnss_latest_data_t *state)
{
    uint32_t longitude_integer = state->longitude_scaled / 1000000;
    uint32_t longitude_fraction = state->longitude_scaled % 1000000;
    uint32_t latitude_integer = state->latitude_scaled / 1000000;
    uint32_t latitude_fraction = state->latitude_scaled % 1000000;

    (void)snprintf(buffer, buffer_size,
        "{\\22longitude\\22:%u.%06u,\\22latitude\\22:%u.%06u,\\22gps_valid\\22:%u}",
        longitude_integer, longitude_fraction, latitude_integer, latitude_fraction, state->gps_valid ? 1U : 0U);
}

void cloud_service_publish_latest_location(void)
{
    gnss_latest_data_t state = {0};
    char payload[128] = {0};

    gnss_get_latest_state(&state);
    cloud_service_build_location_json(payload, sizeof(payload), &state);
    l610_mqtt_publish(CLOUD_LOCATION_TOPIC, payload);
}

static bool cloud_service_extract_request_id(const char *topic, char *request_id, size_t request_id_size)
{
    const char *request_start;
    size_t request_len;

    if (topic == NULL || request_id == NULL || request_id_size == 0) {
        return false;
    }

    request_start = strstr(topic, CLOUD_RPC_REQUEST_PREFIX);
    if (request_start == NULL) {
        return false;
    }
    request_start += strlen(CLOUD_RPC_REQUEST_PREFIX);

    request_len = 0;
    while (request_start[request_len] >= '0' && request_start[request_len] <= '9') {
        request_len++;
    }

    if (request_len == 0 || request_len >= request_id_size) {
        return false;
    }

    if (memcpy_s(request_id, request_id_size, request_start, request_len) != EOK) {
        return false;
    }
    request_id[request_len] = '\0';
    return true;
}

void cloud_service_handle_rpc(const char *topic, const char *payload)
{
    gnss_latest_data_t state = {0};
    char request_id[32] = {0};
    char response_topic[96] = {0};
    char response_payload[128] = {0};

    if (topic == NULL || payload == NULL) {
        return;
    }

    if (strstr(payload, CLOUD_RPC_METHOD_GET_GPS) == NULL) {
        osal_printk("%s ignore rpc payload: %s\r\n", CLOUD_SERVICE_LOG, payload);
        return;
    }

    if (!cloud_service_extract_request_id(topic, request_id, sizeof(request_id))) {
        osal_printk("%s failed to parse request id from topic: %s\r\n", CLOUD_SERVICE_LOG, topic);
        return;
    }

    gnss_get_latest_state(&state);
    cloud_service_build_location_json(response_payload, sizeof(response_payload), &state);

    (void)snprintf(response_topic, sizeof(response_topic), "%s%s", CLOUD_RPC_RESPONSE_PREFIX, request_id);
    l610_mqtt_publish(response_topic, response_payload);
    osal_printk("%s responded to rpc %s\r\n", CLOUD_SERVICE_LOG, request_id);
}
