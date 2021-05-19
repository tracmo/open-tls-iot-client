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
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_int_wdt.h"
#include "esp_task_wdt.h"
#include "esp_log.h"
#include "esp_system.h"

#include "app_wifi.h"
#include "t_gpio.h"
#include "t_nvs.h"
#include "periodical.h"
#include "version.h"
#include "button.h"
#include "cmd.h"
#include "mqtt.h"
#include "open_tls.h"

static const char *TAG = "MAIN";

#define CHECK_RET_CODE(fname, returned, expected) ({                   \
            if(returned != expected){                                  \
                ESP_LOGE(TAG, "%s ERROR code=0x%X\n", fname, returned);\
            }                                                          \
})

///////////////////////////////////////////////////////////////////////////////////
// Global Variables
char t_device_sn_str[24];         // "TT-AABBCCDDEEFF"
uint8_t t_device_MAC[6];          // this is the WiFi MAC
char t_device_wifi_ssid[20];
uint8_t t_device_wifi_bssid[6];

///////////////////////////////////////////////////////////////////////////////////
// MAIN
void app_main()
{
    TaskHandle_t tHandleGpio;

    // version information
    ESP_LOGI(TAG, "+++++++++++++++ Open TLS Device Version %s +++++++++++++++", TT_VERSION_INFO);

    // init watchdog timer
    esp_task_wdt_init(T_DEVICE_WATCHDOG_TIMER_SEC, true);    // panic handler is needed to have the abort function

    // put watchdog on this main task until all the routing tasks are created
    esp_task_wdt_add(0);

    // initialize NVS
    // Note: even NVS is not used by this application, ESP32 needs it to store the RF calibration
    t_nvs_init();

    // init GPIO
    t_gpio_init();

    // init Button gpio
    button_init();

    // create low-priority gpio task early to handle I/O before everything starts
    xTaskCreate(&t_gpio_task, "gpio_task", 4608, NULL, 1, &tHandleGpio);    // lowest priority
    esp_task_wdt_add(tHandleGpio);

    // get the ESP32 factory MAC address (early as possible)
    esp_err_t ret = esp_read_mac(t_device_MAC, ESP_MAC_WIFI_STA); // type 0 for WiFi MAC Address
    if( ret ) {
        ESP_LOGE(TAG, "%s unalbe to get ESP32 WiFi MAC Address, error code = %x\n", __func__, ret);
        return;
    } else {
        // convert MAC to text format
        sprintf(t_device_sn_str, "TT-%02X%02X%02X%02X%02X%02X", t_device_MAC[0],
                                                                t_device_MAC[1],
                                                                t_device_MAC[2],
                                                                t_device_MAC[3],
                                                                t_device_MAC[4],
                                                                t_device_MAC[5]);
        ESP_LOGI(TAG, "ESP32 WiFiAddress %s <---------------------------------------------- SERIAL NUMBER", t_device_sn_str);
    }

    // init WiFi
    app_wifi_initialise();

    // sync time
    // this blocks the task until the correct time is obtained
    app_wifi_ntp_init();

    // feed the watchdog of the main task
    esp_task_wdt_reset();

    // init periodical routings
    periodical_init();

    // main task stack size check point A
    ESP_LOGI(TAG, "main task sshw (A) = %d", uxTaskGetStackHighWaterMark(NULL));

    // Subscribe Idle Tasks to TWDT if they were not subscribed at startup
    ESP_LOGI(TAG, "Adding task watchdog for CPU0/1");
    CHECK_RET_CODE("WDT_CPU0", esp_task_wdt_add(xTaskGetIdleTaskHandleForCPU(0)), ESP_OK);
    CHECK_RET_CODE("WDT_CPU1", esp_task_wdt_add(xTaskGetIdleTaskHandleForCPU(1)), ESP_OK);

    // reset error blinking until the procedure is fulfilled
    t_gpio_led_mode(T_GPIO_LED_MODE_ERROR_BLINKING);

    // initialize the command queue and task to be used by MQTT
    cmd_init();

    // init MQTT agent and wait until it is connected
    // Note1: there is a waiting inside MQTT init, so this needs to be after the main watchdog is added
    // Note2: MQTT topic is needed so this has to be after token is obtained
    mqtt_init();

    // restore the led mode to normal breathing before task creation
    t_gpio_led_mode(T_GPIO_LED_MODE_CLEAR_ERROR);

    // no need to keep eyes on the main task
    esp_task_wdt_delete(0);

    // final check the stack size high water mark
    ESP_LOGI(TAG, "main task sshw (final) = %d", uxTaskGetStackHighWaterMark(NULL));
}
