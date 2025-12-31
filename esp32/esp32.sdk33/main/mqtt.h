/*
 * Project Secured MQTT Publisher
 * Copyright 2026 Care Active Corp. ("Care Active").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#ifndef _MQTT_H_
#define _MQTT_H_

///////////////////////////////////////////////////////////////////////////////////
// public function
void mqtt_init(void);
bool mqtt_connected(void);
void mqtt_send_msg(char *msg);
void mqtt_proceed_device_report(void);

#endif
