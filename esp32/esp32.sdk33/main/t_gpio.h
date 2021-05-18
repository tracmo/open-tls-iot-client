/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#ifndef _T_GPIO_H_
#define _T_GPIO_H_

///////////////////////////////////////////////////////////////////////////////////
// defines
typedef enum {
    T_GPIO_LED_MODE_ERROR_BLINKING = 1,                 // 250ms blinking, which has the highest priority
    T_GPIO_LED_MODE_CLEAR_ERROR,                        // clear the error blinking status, continue with short breathing
    T_GPIO_LED_MODE_BREATHING_INTERVAL_MEDIUM,          // medium breathing led interval
    T_GPIO_LED_MODE_BREATHING_INTERVAL_SHORT            // short breathing led interval (network activity)
                                                        // not short, not medium is long
} t_gpio_led_t;

///////////////////////////////////////////////////////////////////////////////////
// public function
void t_gpio_init(void);
void t_gpio_led_mode(t_gpio_led_t ledMode);
void t_gpio_task(void *pvParameters);
void t_gpio_issue_esp_restart(void);
void t_gpio_led2_blink(void);

#endif
