/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "nvs.h"

#include "util.h"
#include "t_nvs.h"

static const char *TAG = "T_NVS";

///////////////////////////////////////////////////////////////////////////////////
// defines

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 * initialises the default nvs partition
 */
void t_nvs_init(void)
{
    ESP_LOGI(TAG, "initializaing NVS");

    esp_err_t err = nvs_flash_init();
    if( err == ESP_ERR_NVS_NO_FREE_PAGES ) {
        // NVS partition was truncated and needs to be erased
        // Retry nvs_flash_init
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK( err );
}

