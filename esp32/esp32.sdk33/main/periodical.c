/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_int_wdt.h"
#include "esp_task_wdt.h"
#include "esp_log.h"
#include "esp_system.h"

#include "app_wifi.h"
#include "open_tls.h"
#include "mqtt.h"
#include "periodical.h"

static const char *TAG = "PERIODICAL";

///////////////////////////////////////////////////////////////////////////////////
// defines
#define PERIODICAL_NTP_ADJUST_INTERVAL              21600   // time is crital, regularly re-calibrate time
#define PERIODICAL_DEVICE_STATUS_REPORT             600     // in seconds

///////////////////////////////////////////////////////////////////////////////////
// local variables
static time_t periodical_initialized = false;
static time_t periodical_last_ntp_request = 0;
static time_t periodical_last_device_status_report = 0;

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 *  Initial the low-priority periodical module
 */
void periodical_init(void)
{
    // already init periodical
    periodical_initialized = true;
}


/**
 * this function is performed by the gpio task, so the other task functions
 * can impact the timing of this function
 */
void periodical_perform(void)
{
    time_t currentTime;

    if( !periodical_initialized ) {
        return;
    }

    // get current time
    time(&currentTime);

    // time is critical, time calibration is needed regularly
    if( periodical_last_ntp_request == 0 ) {
        // skip the first one since the time was just obtained
        periodical_last_ntp_request = currentTime;
    } else if( (currentTime - periodical_last_ntp_request) > PERIODICAL_NTP_ADJUST_INTERVAL ) {
        // send NTP request
        // Note: NTP does not impact MQTT, so not need to stop MQTT
        app_wifi_ntp_request();
        periodical_last_ntp_request = currentTime;
        ESP_LOGI(TAG, "perform time recalibration");
    }

    // make sure the device report is performed periodically
    if( mqtt_connected() &&
        (currentTime - periodical_last_device_status_report ) > PERIODICAL_DEVICE_STATUS_REPORT ) {

        ESP_LOGI(TAG, "perform periodical device status report");

        // perform the device status report
        mqtt_proceed_device_report();

        // track the current time
        periodical_last_device_status_report = currentTime;
    }
}

