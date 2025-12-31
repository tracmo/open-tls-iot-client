/*
 * Project Secured MQTT Publisher
 * Copyright 2026 Care Active Corp. ("Care Active").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "esp_int_wdt.h"
#include "esp_task_wdt.h"
#include "esp_system.h"
#include "esp_log.h"
#include "mbedtls/aes.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "nvs_flash.h"
#include "nvs.h"

#include "open_tls.h"
#include "util.h"
#include "cmd.h"

static const char *TAG = "CMD";

///////////////////////////////////////////////////////////////////////////////////
// defines
#define CMD_QUEUE_SIZE                  16
#define	CMD_EVENT_WAITING_TIME			1000	// in ms
#define CMD_RELAY_STAY_TIME             700     // in ms

///////////////////////////////////////////////////////////////////////////////////
// typedefs
typedef struct {
    uint32_t random1;
    uint32_t otpTime;
    uint32_t random3;
    uint8_t random4[3];
    uint8_t checksum;
} cmd_otp_type_t;

///////////////////////////////////////////////////////////////////////////////////
// local variables
static QueueHandle_t cmd_que = NULL;

static bool cmd_delayed_stop_action = false;
static time_t cmd_delayed_stop_action_time = 0;

static bool cmd_delayed_close_action = false;
static time_t cmd_delayed_close_action_time = 0;

///////////////////////////////////////////////////////////////////////////////////
// local function
void cmd_loop(void * arg);
void cmd_perform(cmd_action_code_t action);

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 * initialize the command queue
 */
void cmd_init(void)
{
    TaskHandle_t cmdEventHnd;

    // vars init
    cmd_delayed_stop_action = false;
    cmd_delayed_stop_action_time = 0;
    cmd_delayed_close_action = false;
    cmd_delayed_close_action_time = 0;

    // create the command handling queues
    cmd_que = xQueueCreate(CMD_QUEUE_SIZE, sizeof(cmd_action_t));
    if( cmd_que == NULL ) {

        ESP_LOGE(TAG, "unable to create command queue");
        return;
    }

	// create the receiver task
	xTaskCreate(&cmd_loop, "cmd_task", 3096, NULL, 1, &cmdEventHnd);	  // lowest priority
	esp_task_wdt_add(cmdEventHnd);
}


/**
 * adding the command to the processing queue
 */
void cmd_add(cmd_action_t *cmdSet)
{
    if( cmd_que == NULL ) {

        ESP_LOGE(TAG, "command queue is NULL");
        return;
    }

    // add the command queue without waiting
    if( xQueueSend(cmd_que, cmdSet, 0) != pdTRUE ) {

        ESP_LOGE(TAG, "failed to add to the command queue for action %d", cmdSet->command_action);
    }
}

///////////////////////////////////////////////////////////////////////////////////
// local function implementations
void cmd_loop(void * arg)
{
	ESP_LOGI(TAG, "cmd_loop start");

	// task loop
	while( true ) {

        cmd_action_t cmdEvent;

		// receive the event from the queue
		if( xQueueReceive(cmd_que, &cmdEvent, pdMS_TO_TICKS(CMD_EVENT_WAITING_TIME)) ) {

            ESP_LOGI(TAG, "incoming queue command=%d", cmdEvent.command_action);

            // AED decrypt
            esp_aes_context aes;
            uint8_t aesKey[16];
            uint8_t plainText[16];

            if( util_string_to_aes_key(OPEN_TLS_OTP_AES_KEY, aesKey) ) {

                // set AES key
                esp_aes_setkey(&aes, aesKey, 128);

                // decrypt
                esp_aes_crypt_ecb(&aes, ESP_AES_DECRYPT, cmdEvent.otpAuth, plainText);

                // verify checksum
                uint8_t checksum = 0;
                for( uint8_t pIdx=0; pIdx < 15; pIdx++ ) {

                    checksum += plainText[pIdx];
                }

                if( checksum == plainText[15] ) {

                    // decode the timestamp
                    cmd_otp_type_t *otp = (cmd_otp_type_t *) plainText;

                    ESP_LOGI(TAG, "decrypted checksum matched (0x%02x)", otp->checksum);

                    // check time difference
                    time_t currentTime;
                    int32_t timeDiff;

                    // get current time
                    time(&currentTime);
                    timeDiff = (int32_t) currentTime - (int32_t) otp->otpTime;

                    ESP_LOGI(TAG, "otp time difference = %d", timeDiff);

                    if( timeDiff <= OPEN_TLS_CMD_OTP_TOLERANCE ) {

                        // everything is correct, perform the action
                        cmd_perform(cmdEvent.command_action);

                    } else {

                        // timestamp is not right, someone is reusing the old messages!?
                        ESP_LOGI(TAG, "intolerable timestamp is used");

                        // convert time string
                        char strftime_buf[64];
                        struct tm timeinfo = { 0 };
                        time_t obtainedTimestamp = (time_t) otp->otpTime;
                        localtime_r(&obtainedTimestamp, &timeinfo);
                        strftime(strftime_buf, sizeof(strftime_buf), "%c", &timeinfo);
                        ESP_LOGI(TAG, "Obtained timestamp GMT date/time: %s", strftime_buf);
                    }
                } else {

                    ESP_LOGI(TAG, "checksum not matched! (cal=0x%02x vs rcv=0x%02x)", checksum, plainText[15]);

                    // show the decrypted message for debugging
                    char decryptedMsg[64];
                    decryptedMsg[0] = 0;
                    for( uint8_t decIdx=0; decIdx<16; decIdx++ ) {
                        char msgChip[8];
                        sprintf(msgChip, "%02x", plainText[decIdx]);
                        strcat(decryptedMsg, msgChip);
                    }

                    ESP_LOGI(TAG, "DECRYPTED MSG: %s", decryptedMsg);
                }
            } else {

                ESP_LOGE(TAG, "AES KEY configuration error");
            }
        }

        // get current time for the following up the delayed actions
        time_t currentTime;
        time(&currentTime);

        // check if any delayed actions to perform
        if( cmd_delayed_stop_action ) {

            if( currentTime >= cmd_delayed_stop_action_time ) {

                cmd_perform(CMD_ACTION_STOP);
                cmd_delayed_stop_action = false;

                ESP_LOGI(TAG, "delayed STOP performed");
            }
        }

        if( cmd_delayed_close_action ) {

            if( currentTime >= cmd_delayed_close_action_time ) {

                cmd_perform(CMD_ACTION_CLOSE);
                cmd_delayed_close_action = false;

                ESP_LOGI(TAG, "delayed CLOSE performed");
            }
        }

		// watchdog
		esp_task_wdt_reset();
	}

	ESP_LOGI(TAG, "cmd_loop end");

	xQueueReset(cmd_que);
	vTaskSuspend(NULL);
}


/**
 * Perform the IO actions
 */
void cmd_perform(cmd_action_code_t action)
{
    if( action == CMD_ACTION_OPEN ) {

        // --------- OPEN ---------
        gpio_set_level(OPEN_TLS_HW_DOOR_OPEN, 1);
        vTaskDelay(pdMS_TO_TICKS(CMD_RELAY_STAY_TIME));
        gpio_set_level(OPEN_TLS_HW_DOOR_OPEN, 0);

    } else if( action == CMD_ACTION_STOP ) {

        // --------- STOP ---------
        gpio_set_level(OPEN_TLS_HW_DOOR_STOP, 1);
        vTaskDelay(pdMS_TO_TICKS(CMD_RELAY_STAY_TIME));
        gpio_set_level(OPEN_TLS_HW_DOOR_STOP, 0);

    } else if( action == CMD_ACTION_CLOSE ) {

        // --------- CLOSE ---------
        gpio_set_level(OPEN_TLS_HW_DOOR_CLOSE, 1);
        vTaskDelay(pdMS_TO_TICKS(CMD_RELAY_STAY_TIME));
        gpio_set_level(OPEN_TLS_HW_DOOR_CLOSE, 0);

    } else if( action == CMD_ACTION_OPEN_STOP_CLOSE ) {

        // --------- OPEN-STOP-THEN-CLOSE ---------
        // make it open first
        gpio_set_level(OPEN_TLS_HW_DOOR_OPEN, 1);
        vTaskDelay(pdMS_TO_TICKS(CMD_RELAY_STAY_TIME));
        gpio_set_level(OPEN_TLS_HW_DOOR_OPEN, 0);

        // get current time
        time_t currentTime;
        time(&currentTime);

        // define the delayed action timers
        cmd_delayed_stop_action_time = currentTime + OPEN_TLS_DOOR_OPEN_STOP_CLOSE_TIMER_STOP;
        cmd_delayed_close_action_time = currentTime + OPEN_TLS_DOOR_OPEN_THEN_CLOSE_TIMER_CLOSE;
        cmd_delayed_stop_action = true;
        cmd_delayed_close_action = true;
    }
    // Note: there is no else
}

