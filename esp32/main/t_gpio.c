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
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "driver/gpio.h"
#include "esp_int_wdt.h"
#include "esp_task_wdt.h"
#include "esp_log.h"
#include "esp_system.h"
#include "sys/time.h"
#include <time.h>
#include "driver/ledc.h"

#include "app_wifi.h"
#include "util.h"
#include "open_tls.h"
#include "button.h"
#include "periodical.h"
#include "t_gpio.h"

static const char *TAG = "TGPIO";

///////////////////////////////////////////////////////////////////////////////////
// defines

// LED-PWM config
#define T_GPIO_LED_IO                      OPEN_TLS_HW_LED1
#define T_GPIO_INTR_FLAG_LEDC              1
#define T_GPIO_LEDC_SPEED_MODE             LEDC_LOW_SPEED_MODE
#define T_GPIO_LEDC_CHANNEL                LEDC_CHANNEL_0
#define T_GPIO_LED_DARK_DUTY               0
#define T_GPIO_LED_LIGHT_DUTY              4000    // scale of 13-bit brightness (8192)
#define T_GPIO_LED_DARK_FADE_TIME          2000    // in ms
#define T_GPIO_LED_LIGHT_FADE_TIME         1000    // in ms

#define T_GPIO_LED_BREATHING_INTERVAL_LONG     20  // in 250ms count
#define T_GPIO_LED_BREATHING_INTERVAL_MEDIUM   10  // in 250ms count
#define T_GPIO_LED_BREATHING_INTERVAL_SHORT    1   // in 250ms count

// LED 2 config
#define T_GPIO_LED2_IO                     OPEN_TLS_HW_LED2

// no wifi tolerance before reboot
#define T_GPIO_MAX_NO_WIFI_TIME            3600    // in seconds

///////////////////////////////////////////////////////////////////////////////////
// local variables
static t_gpio_led_t t_gpio_current_led_stat;
static time_t t_gpio_reboot_time = 0;                          // 0 means no reboot request. if non-zero, reboot at the configured time
static bool t_gpio_restart_issued = false;                     // to avoid continously restart requests to delay the actual reboot time
static bool t_gpio_led_mode_short_set = false;
static bool t_gpio_led_mode_medium_set = false;
static uint32_t t_gpio_led2_blinking_counter = 0;

///////////////////////////////////////////////////////////////////////////////////
// local functions

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 * Initial the GPIO hooks
 */
void t_gpio_init(void)
{
    // var reset
    t_gpio_current_led_stat = T_GPIO_LED_MODE_ERROR_BLINKING;     // everything starts from an error blinking
    t_gpio_reboot_time = 0;
    t_gpio_restart_issued = false;
    t_gpio_led_mode_short_set = false;
    t_gpio_led_mode_medium_set = false;
    t_gpio_led2_blinking_counter = 0;

    // ------ LED PWM initialization ------
    ledc_timer_config_t ledc_timer = {
        .duty_resolution = LEDC_TIMER_13_BIT,   // resolution of PWM duty
        .freq_hz = 5000,                        // frequency of PWM signal
        .speed_mode = T_GPIO_LEDC_SPEED_MODE,  // timer mode
        .timer_num = LEDC_TIMER_0               // timer index
    };

    // set configuration of timer0 for high speed channels
    ledc_timer_config(&ledc_timer);

    ledc_channel_config_t ledc_channel = {
        .channel    = T_GPIO_LEDC_CHANNEL,
        .duty       = 0,
        .gpio_num   = T_GPIO_LED_IO,
        .speed_mode = T_GPIO_LEDC_SPEED_MODE,
        .timer_sel  = LEDC_TIMER_0
    };
    // set configuration of timer0 for high speed channels
    ledc_channel_config(&ledc_channel);

    // initialize fade service.
    ledc_fade_func_install(T_GPIO_INTR_FLAG_LEDC);

    // initialize the second LED and the IOs to control the door
    gpio_config_t ioConf;
    ioConf.intr_type = GPIO_PIN_INTR_DISABLE;
    ioConf.pin_bit_mask = (1ULL << T_GPIO_LED2_IO) |
                          (1ULL << OPEN_TLS_HW_DOOR_OPEN) |
                          (1ULL << OPEN_TLS_HW_DOOR_STOP)  |
                          (1ULL << OPEN_TLS_HW_DOOR_CLOSE);
    ioConf.mode = GPIO_MODE_OUTPUT;
    ioConf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    ioConf.pull_up_en = GPIO_PULLUP_DISABLE;
    gpio_config(&ioConf);

    // LED2
    gpio_set_level(T_GPIO_LED2_IO, 0);

    // DOOR Control IO
    gpio_set_level(OPEN_TLS_HW_DOOR_OPEN, 1);
    gpio_set_level(OPEN_TLS_HW_DOOR_STOP, 1);
    gpio_set_level(OPEN_TLS_HW_DOOR_CLOSE, 1);

}


/**
 * Control LED breathing/blinking mode
 * if the current mode is the error blinking, it cannot be changed to breathing mode until the error is cleared
 *
 * @param ledMode refer to the type definition t_gpio_led_t
 */
void t_gpio_led_mode(t_gpio_led_t ledMode)
{
    if( ledMode == T_GPIO_LED_MODE_CLEAR_ERROR ) {
        t_gpio_current_led_stat = T_GPIO_LED_MODE_BREATHING_INTERVAL_SHORT;
        t_gpio_led_mode_short_set = true;

    } else if( ledMode == T_GPIO_LED_MODE_ERROR_BLINKING ) {
        t_gpio_current_led_stat = ledMode;

    } else if( t_gpio_current_led_stat != T_GPIO_LED_MODE_ERROR_BLINKING ) {
        t_gpio_current_led_stat = ledMode;

        // set medium and short separately
        // the purpose of using these two addtional flags is to prevent
        // medium mode preempt the short mode
        if( ledMode == T_GPIO_LED_MODE_BREATHING_INTERVAL_SHORT ) {
            t_gpio_led_mode_short_set = true;
        } else if( ledMode == T_GPIO_LED_MODE_BREATHING_INTERVAL_MEDIUM ) {
            t_gpio_led_mode_medium_set = true;
        }
    }
}


/**
 * Initiate software system reboot request
 * system will count down 10 seconds to perform a software reset
 */
void t_gpio_issue_esp_restart(void)
{
    time_t currentTime;

    // avoid duplicate restart request
    if( t_gpio_restart_issued ) {
        // do not proceed a restart command more than once
        return;
    } else {
        // mark the flag to avoid the second restart request
        t_gpio_restart_issued = true;
    }

    // get current time
    time(&currentTime);

    // set the reboot time at 3 seconds from now
    t_gpio_reboot_time = currentTime + 3;

    ESP_LOGI(TAG, "software reset requested");
}


/**
 * Make the LED2 blinking once
 */
void t_gpio_led2_blink(void)
{
    // turn on led2
    gpio_set_level(T_GPIO_LED2_IO, 1);

    // set the counter then let the gpio task to turn led2 off
    t_gpio_led2_blinking_counter = 1;
}


/**
 * this task serialize the routine tasks and the other low priority handlers
 */
void t_gpio_task(void *pvParameters)
{
    time_t disconnectWifiTime = 0;
    bool blinkingLedOn = false;
    bool breathingLedOn = false;
    uint8_t breathingLedWaitCounter = 0;
    uint8_t breathingLedWaitMax = 0;

    while( 1 ) {
        // per-250ms interval process resolution
        vTaskDelay(pdMS_TO_TICKS(250));

        // --------------------------------------------------
        // handling led breathing/blinking
        // --------------------------------------------------
        if( t_gpio_current_led_stat == T_GPIO_LED_MODE_ERROR_BLINKING ) {

            if( blinkingLedOn ) {
                // turn off
                ledc_set_duty_and_update(T_GPIO_LEDC_SPEED_MODE, T_GPIO_LEDC_CHANNEL, T_GPIO_LED_DARK_DUTY, 0);
                blinkingLedOn = false;
            } else {
                // turn on
                ledc_set_duty_and_update(T_GPIO_LEDC_SPEED_MODE, T_GPIO_LEDC_CHANNEL, T_GPIO_LED_LIGHT_DUTY, 0);
                blinkingLedOn = true;
            }

        } else {

            if( breathingLedOn ) {

                // fade off
                ledc_set_fade_time_and_start(T_GPIO_LEDC_SPEED_MODE,
                                             T_GPIO_LEDC_CHANNEL,
                                             T_GPIO_LED_DARK_DUTY,
                                             T_GPIO_LED_DARK_FADE_TIME,
                                             LEDC_FADE_WAIT_DONE);
                breathingLedOn = false;

            } else {

                // determine how long to restart the led breathing
                // note: short interval has the highest priority
                if( t_gpio_led_mode_short_set ) {
                    breathingLedWaitMax = T_GPIO_LED_BREATHING_INTERVAL_SHORT;
                    t_gpio_led_mode_short_set = false; // clear the flag
                } else if( t_gpio_led_mode_medium_set ) {
                    breathingLedWaitMax = T_GPIO_LED_BREATHING_INTERVAL_MEDIUM;
                    t_gpio_led_mode_medium_set = false;
                } else {
                    breathingLedWaitMax = T_GPIO_LED_BREATHING_INTERVAL_LONG;
                }

                if( breathingLedWaitCounter < breathingLedWaitMax ) {
                    breathingLedWaitCounter++;
                } else {
                    // fade on
                    ledc_set_fade_time_and_start(T_GPIO_LEDC_SPEED_MODE,
                                                T_GPIO_LEDC_CHANNEL,
                                                T_GPIO_LED_LIGHT_DUTY,
                                                T_GPIO_LED_LIGHT_FADE_TIME,
                                                LEDC_FADE_WAIT_DONE);
                    breathingLedOn = true;
                    breathingLedWaitCounter = 0;
                }

            }

        }

        time_t currentTime;

        // get current time
        time(&currentTime);

        // --------------------------------------------------
        // check WIFI status
        // --------------------------------------------------

        if( !app_wifi_is_connected() ) {
            // save disconnect wifi time
            if( disconnectWifiTime == 0 ) {
                disconnectWifiTime = currentTime;
            }

            // no wifi or token over an hour
            if( currentTime - disconnectWifiTime > T_GPIO_MAX_NO_WIFI_TIME ) {
                ESP_LOGE(TAG, "already no wifi for %ld sec,  restart the system", currentTime - disconnectWifiTime);

                // system will reboot in 3 seconds
                t_gpio_issue_esp_restart();

                // SYSTEM REBOOT ... (in 3 seconds)
            }
        } else {
            // reset disconnect wifi time
            disconnectWifiTime = 0;
        }

        // --------------------------------------------------
        // reboot request
        // --------------------------------------------------

        // check if reboot request is issued
        if( t_gpio_reboot_time > 0 ) {
            if( currentTime > t_gpio_reboot_time ) {
                esp_restart();

                // unreachable
            }

            // time count down
            ESP_LOGI(TAG, "software reset in %ld second(s)", t_gpio_reboot_time - currentTime);
        }

        // feed the watchdog
        esp_task_wdt_reset();

        // check the LED2 blinking status
        if( t_gpio_led2_blinking_counter > 0 ) {

            t_gpio_led2_blinking_counter--;
            if( t_gpio_led2_blinking_counter & 0x1 ) {

                gpio_set_level(T_GPIO_LED2_IO, 1);

            } else {

                gpio_set_level(T_GPIO_LED2_IO, 0);
            }
        }

        // perform button task
        button_handle();
        esp_task_wdt_reset();   // feed the dog in case the previous handler took too much time

        // perform the peridoical task
        periodical_perform();
        esp_task_wdt_reset();   // feed the dog in case the previous handler took too much time

    } // end while(1)

    // end task loop, clear it
    vTaskDelete(NULL);
}


///////////////////////////////////////////////////////////////////////////////////
// local functions implementation

