#ifndef CLOUD_SERVICE_H
#define CLOUD_SERVICE_H

#include <stdint.h>

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif
#endif

#ifndef GNSS_REPORT_PERIOD_MS
#define GNSS_REPORT_PERIOD_MS 30000
#endif

#ifndef GNSS_REPORT_PERIOD_VALID_MS
#define GNSS_REPORT_PERIOD_VALID_MS 10000
#endif

#ifndef GNSS_REPORT_PERIOD_INVALID_MS
#define GNSS_REPORT_PERIOD_INVALID_MS 60000
#endif

void cloud_service_publish_latest_location(void);
void cloud_service_handle_rpc(const char *topic, const char *payload);
void *cloud_service_task(const char *arg);

#ifdef __cplusplus
#if __cplusplus
}
#endif
#endif

#endif
