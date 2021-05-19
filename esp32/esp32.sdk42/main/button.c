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
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "esp_system.h"

#include "open_tls.h"
#include "t_gpio.h"
#include "button.h"

static const char *TAG = "BTN";

///////////////////////////////////////////////////////////////////////////////////
// defines
#define BUTTON_IO                           OPEN_TLS_HW_BUTTON
#define BUTTON_PIN_SEL                      (1ULL << BUTTON_IO)
#define BUTTON_INTR_FLAG_DEFAULT            0

///////////////////////////////////////////////////////////////////////////////////
// local variables
int button_level;
bool button_pressed;

// ISR lock and debouncing control
portMUX_TYPE button_mux = portMUX_INITIALIZER_UNLOCKED;

///////////////////////////////////////////////////////////////////////////////////
// local functions
static void IRAM_ATTR button_isr_handler(void* arg);

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 * Button gpio initialization, a button ISR is hooked
 */
void button_init(void)
{
    // init variables
    // ignore the power-on button status
    button_level = 0;
    button_pressed = false;

    // IO initialization
    // -----------------
    gpio_config_t ioConf;

    // ------ config button ------
    // interrupt of both rising/falling edge
    ioConf.intr_type = GPIO_PIN_INTR_ANYEDGE;

    // bit mask of the pins
    ioConf.pin_bit_mask = BUTTON_PIN_SEL;

    // set as input mode
    ioConf.mode = GPIO_MODE_INPUT;

    // disable pull-down mode
    ioConf.pull_down_en = GPIO_PULLDOWN_DISABLE;

    // enable pull-up mode
    ioConf.pull_up_en = GPIO_PULLUP_ENABLE;

    // gpio common configuration
    gpio_config(&ioConf);

    // install gpio isr service
    gpio_install_isr_service(BUTTON_INTR_FLAG_DEFAULT);

    // hook isr handler for specific gpio pin
    gpio_isr_handler_add(BUTTON_IO, button_isr_handler, (void*) BUTTON_IO);
}


/**
 * Handle all button event, call by t_gpio_task()
 */
void button_handle(void)
{
    if( button_pressed) {

        ESP_LOGI(TAG, "button pressed");

        // ENTER critical section
        portENTER_CRITICAL_ISR(&button_mux);

        button_pressed = false;

        // LEAVE critical section
        portEXIT_CRITICAL_ISR(&button_mux);

        // use LED2 as the feedback
        t_gpio_led2_blink();

        // Note: Debouncing check is not implemented since this application does not use button
    }
}


///////////////////////////////////////////////////////////////////////////////////
// local functions implementation

// *******************************************************************************
// CAUTION: THIS IS AN ISR HANDLER. BE CAREFUL!!!
static void IRAM_ATTR button_isr_handler(void* arg)
{
    // ENTER critical section
    portENTER_CRITICAL_ISR(&button_mux);

    button_level = gpio_get_level(BUTTON_IO);

    if( button_level == 1 ) {

        button_pressed = true;
    }

    // LEAVE critical section
    portEXIT_CRITICAL_ISR(&button_mux);
}
// ******************************************************************************
