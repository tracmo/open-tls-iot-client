/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <time.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "esp_task_wdt.h"
#include "mbedtls/base64.h"
#include "rom/crc.h"
#include "mqtt_client.h"
#include "cJSON.h"

#include "app_wifi.h"
#include "open_tls.h"
#include "t_gpio.h"
#include "util.h"
#include "version.h"
#include "cmd.h"
#include "mqtt.h"

static const char *TAG = "MQTT";

///////////////////////////////////////////////////////////////////////////////////
// defines
#define MQTT_MAX_WAITING_COUNT          600 // in seconds, this is for the first MQTT connection.
                                            // if failed, system will reboot
#define MQTT_BUF_SIZE                   (2 * 1024)

extern const uint8_t aws_root_ca_pem_start[] asm("_binary_aws_root_ca_pem_start");
extern const uint8_t aws_root_ca_pem_end[] asm("_binary_aws_root_ca_pem_end");
extern const uint8_t certificate_pem_crt_start[] asm("_binary_my_tls_certificate_pem_crt_start");
extern const uint8_t certificate_pem_crt_end[] asm("_binary_my_tls_certificate_pem_crt_end");
extern const uint8_t private_key_pem_start[] asm("_binary_my_tls_private_pem_key_start");
extern const uint8_t private_key_pem_end[] asm("_binary_my_tls_private_pem_key_end");

///////////////////////////////////////////////////////////////////////////////////
// local variables
static bool mqtt_currently_connected = false;        // this state is just a 'possible' state
static esp_mqtt_client_handle_t client = NULL;

///////////////////////////////////////////////////////////////////////////////////
// local functions
static void mqtt_handle_received_control_message(char *data, uint32_t len);

///////////////////////////////////////////////////////////////////////////////////
// MQTT event handler

static esp_err_t mqtt_event_handler(esp_mqtt_event_handle_t event)
{
    esp_mqtt_client_handle_t client = event->client;
    int msg_id;

    switch (event->event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");

            mqtt_currently_connected = true;

            // normal status
            t_gpio_led_mode(T_GPIO_LED_MODE_CLEAR_ERROR);

            // subscribe the command topic with QOS0
            msg_id = esp_mqtt_client_subscribe(client, OPEN_TLS_MQTT_TOPIC, 0);
            ESP_LOGI(TAG, "sent subscribe %s successful, msg_id=%d", OPEN_TLS_MQTT_TOPIC, msg_id);

            break;

        case MQTT_EVENT_DISCONNECTED:
            // Note: this event is triggered only when the broker disconnects the client.
            //       if the client issues the disconnect, this event will not be triggered.

            // blinking led
            t_gpio_led_mode(T_GPIO_LED_MODE_ERROR_BLINKING);

            ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED");
            mqtt_currently_connected = false;

            break;

        case MQTT_EVENT_SUBSCRIBED:
            ESP_LOGI(TAG, "MQTT_EVENT_SUBSCRIBED, msg_id=%d", event->msg_id);
            break;

        case MQTT_EVENT_UNSUBSCRIBED:
            ESP_LOGI(TAG, "MQTT_EVENT_UNSUBSCRIBED, msg_id=%d", event->msg_id);
            break;

        case MQTT_EVENT_PUBLISHED:
            ESP_LOGI(TAG, "MQTT_EVENT_PUBLISHED, msg_id=%d", event->msg_id);
            break;

        case MQTT_EVENT_DATA:
            // ignore the device status report
            // then process the other messages
            if( strncmp(event->data, "{\"TT_ID\"", 8) ) {

                // process message only sent from the known topic
                if( !strncmp(event->topic, OPEN_TLS_MQTT_TOPIC, strlen(OPEN_TLS_MQTT_TOPIC)) ) {

                    t_gpio_led2_blink();
                    mqtt_handle_received_control_message(event->data, event->data_len);

                } else {

                    ESP_LOGI(TAG, "MQTT_EVENT_DATA, (no handler) %s", event->data);
                }
            }
            break;

        case MQTT_EVENT_ERROR:
            ESP_LOGI(TAG, "MQTT_EVENT_ERROR");
            break;

        default:
            break;
    }
    return ESP_OK;
}

static esp_mqtt_client_config_t mqtt_cfg = {
    .uri = OPEN_TLS_MQTT_BROKER,
    .event_handle = mqtt_event_handler,
    .keepalive = 120,
    .buffer_size = MQTT_BUF_SIZE
};

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 * Init the state of mqtt agent
 */
void mqtt_init(void)
{
    // var init
    mqtt_currently_connected = false;

    // set MQTT Broker
    mqtt_cfg.uri = OPEN_TLS_MQTT_BROKER;

    // set default client id
    mqtt_cfg.client_id = t_device_sn_str;

    // set default mqtt settings
    mqtt_cfg.cert_pem = (const char *)aws_root_ca_pem_start;
    mqtt_cfg.client_cert_pem = (const char *)certificate_pem_crt_start;
    mqtt_cfg.client_key_pem = (const char *)private_key_pem_start;
    mqtt_cfg.cert_pem = (const char *)aws_root_ca_pem_start;

    // init mqtt client handler
    client = esp_mqtt_client_init(&mqtt_cfg);

    // start the MQTT task
    esp_mqtt_client_start(client);

    // wait until it is connected
    uint16_t waitingCount = 0;
    do {
        // delay the previous scanning period
        vTaskDelay(pdMS_TO_TICKS(1000));

        // feed the watchdog
        esp_task_wdt_reset();

        waitingCount++;

        ESP_LOGI(TAG, "waiting for MQTT connection (%d)", waitingCount);

        if( waitingCount > MQTT_MAX_WAITING_COUNT ) {
            ESP_LOGI(TAG, "unable to get MQTT connected, restart the system");

            // this init is before any main function tasks, so simply a direct reboot
            esp_restart();

            // unreachable
        }

    } while( !mqtt_currently_connected );
}


/**
 * return the status of MQTT
 * Note: since MQTT is not reliable connection, the connected status is not reliable, but disconnected status is
 *
 * @return true if MQTT is connected
 */
bool mqtt_connected(void)
{
    return(mqtt_currently_connected);
}


/**
 * Convert raw data to json and send to cloud via mqtt
 *
 * @param *msg data to report via matt
 */
void mqtt_send_msg(char *msg)
{
    if( mqtt_connected() && msg != NULL ) {
        // publish data
        int msg_id;
        msg_id = esp_mqtt_client_publish(client, OPEN_TLS_MQTT_TOPIC, msg, 0, 0, 0);
        ESP_LOGI(TAG, "MQTT Publish %s, msg_id=%d", msg, msg_id);
    } // end if(mqtt_connected())
}


/**
 * Proceed Device-Alive Report
 */
void mqtt_proceed_device_report(void)
{
    if( mqtt_connected() ) {
        char *postBuf = NULL;

        // prepare JSON memory
        postBuf = malloc(MQTT_BUF_SIZE);
        if( postBuf != NULL ) {

            char tempStr[256];

            // get current time
            time_t currentTime;
            time(&currentTime);

            // put event timestamp to post buffer
            sprintf(postBuf, "{\"TT_ID\":\"%s\",\"event_timestamp\":%ld,\"firmware_version\":\"%s\"", t_device_sn_str, currentTime, TT_VERSION_INFO);

            tcpip_adapter_ip_info_t ipInfo;

            // get IP address
            tcpip_adapter_get_ip_info(TCPIP_ADAPTER_IF_STA, &ipInfo);

            // put IP address to post buffer
            sprintf(tempStr, ",\"tt_net_info\":{\"ipv4\":\"%d.%d.%d.%d\"",
                                            ipInfo.ip.addr & 0xff,
                                            (ipInfo.ip.addr >> 8) & 0xff,
                                            (ipInfo.ip.addr >> 16) & 0xff,
                                            (ipInfo.ip.addr >> 24) & 0xff);
            strcat(postBuf, tempStr);

            // convert SSID to BASE64
            unsigned char wifiSsidBase64[64];
            uint32_t encLen = 0;
            int result = mbedtls_base64_encode(wifiSsidBase64, sizeof(wifiSsidBase64) - 1, &encLen, (unsigned char *) t_device_wifi_ssid, strlen(t_device_wifi_ssid));
            if( result == 0 ) {
                // end string
                wifiSsidBase64[encLen] = 0x00;

                // put SSID to post buffer
                sprintf(tempStr, ",\"SSID\":\"%s\"", (char *) wifiSsidBase64);
                strcat(postBuf, tempStr);
            }

            // put BSSID to post buffer
            sprintf(tempStr, ",\"BSSID\":\"%02X:%02X:%02X:%02X:%02X:%02X\"",
                                                                t_device_wifi_bssid[0],
                                                                t_device_wifi_bssid[1],
                                                                t_device_wifi_bssid[2],
                                                                t_device_wifi_bssid[3],
                                                                t_device_wifi_bssid[4],
                                                                t_device_wifi_bssid[5]);
            strcat(postBuf, tempStr);

            // get wifi rssi
            int8_t wifiRssi;
            wifiRssi = app_wifi_get_rssi();

            // put wifi rssi to post buffer
            sprintf(tempStr, ",\"rssi\":%d}", wifiRssi);
            strcat(postBuf, tempStr);

            // complete the json
            strcat(postBuf, "}");

            // publish data
            int msg_id = esp_mqtt_client_publish(client, OPEN_TLS_MQTT_TOPIC, postBuf, 0, 0, 0);
            ESP_LOGI(TAG, "MQTT Publish %s, msg_id=%d", postBuf, msg_id);

            // release memory
            UTIL_FREE(postBuf);
        } else {
            ESP_LOGE(TAG, "unable to malloc memory");
        }
    } // end if(mqtt_connected())
}


///////////////////////////////////////////////////////////////////////////////////
// local function implementations

static void mqtt_handle_received_control_message(char *data, uint32_t len)
{
    char *msgBuf = (char *) malloc(len + 1);
    if( msgBuf != NULL ) {

        bool commandAccepted = false;

        // duplicate the message
        memcpy(msgBuf, data, len);
        msgBuf[len] = 0;    // make it null-terminated

        // parse the JSON message
        cJSON *jsonRoot = cJSON_Parse(msgBuf);
        if( jsonRoot != NULL ) {

            uint32_t commandActionId = 0;
            char *otpAuthStr = NULL;
            cmd_action_t commandSet;

            // get the command ID
            cJSON *cmdIdJSON = cJSON_GetObjectItem(jsonRoot, "command");
            if( cmdIdJSON != NULL ) {

                if( cJSON_IsNumber(cmdIdJSON) ) {
                    commandActionId = cmdIdJSON->valueint;
                }
            }

            // get OTP authentication key
            cJSON *otpAuthJSON = cJSON_GetObjectItem(jsonRoot, "otp-auth");
            if( otpAuthJSON != NULL ) {

                otpAuthStr = cJSON_GetStringValue(otpAuthJSON);
            }

            // identify the command
            if( commandActionId > CMD_ACTION_NONE && commandActionId < CMD_ACTION_INVALID ) {

                commandSet.command_action = commandActionId;

                if( otpAuthStr != NULL ) {

                    // 16-byte encrypted data must be 32 characters long
                    if( strlen(otpAuthStr) == 32 ) {

                        // convert the string to 16-byte value array
                        if( util_string_to_aes_key(otpAuthStr, commandSet.otpAuth) ) {

                            commandAccepted = true;
                        }
                    }
                }
            }

            if( commandAccepted) {

                // add this action to the command queue
                cmd_add(&commandSet);

                ESP_LOGE(TAG, "command accepted, action=%d, %s", commandSet.command_action, msgBuf);
            }

            // release the cJSON object
            cJSON_Delete(jsonRoot);

        } // end if(jsonRoot==NULL)-else

        // output to log if this command is not accepted
        if( !commandAccepted ) {

            ESP_LOGE(TAG, "invalid command received, %s", msgBuf);
        }

        // release allocated msgBuf
        UTIL_FREE(msgBuf);
    } // end if(msgBuf!=NULL)
}

