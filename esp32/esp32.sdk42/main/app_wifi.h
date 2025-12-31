/*
 * Project Secured MQTT Publisher
 * Copyright 2026 Care Active Corp. ("Care Active").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#ifndef _APP_WIFI_H_
#define _APP_WIFI_H_

///////////////////////////////////////////////////////////////////////////////////
// public function
void app_wifi_initialise(void);
void app_wifi_wait_connected(void);
bool app_wifi_is_connected(void);

void app_wifi_ntp_request(void);
void app_wifi_ntp_init(void);

int8_t app_wifi_get_rssi(void);

#endif

