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
#include "esp_vfs.h"
#include "esp_vfs_fat.h"
#include "esp_system.h"

#include "util.h"
#include "open_tls.h"

//static const char *TAG = "UTIL";

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 * convert 32-character string to 128-bit AES key value
 *
 * @param str 32-character long AES key in string
 * @param key 16-byte buffer to store the 128-bit key
 *
 * @return true if the value can be converted,
 *         false if there is any non-digit character in the string
 */
bool util_string_to_aes_key(char *str, uint8_t *key)
{
    // dtring must be 32-character long
    if( strlen(str) != 32 ) {
        return(false);
    }

    bool foundNonDigit = false;
    for( uint8_t nIdx=0; nIdx < 16; nIdx++ ) {

        int8_t digitHiValue = util_hex_digit_to_dec(str[nIdx * 2]);
        int8_t digitLoValue = util_hex_digit_to_dec(str[nIdx * 2 + 1]);

        if( digitHiValue < 0 || digitLoValue < 0 ) {

            // illeagle char found
            foundNonDigit = true;
            break;
        }

        // convert it in
        key[nIdx] = digitHiValue << 4 | digitLoValue;
    }

    return(!foundNonDigit);
}


/**
 * Convert a single heximal digit to a decimal value
 */
int8_t util_hex_digit_to_dec(char hexDigit)
{
    if( hexDigit >= '0' && hexDigit <= '9' ) {
        return(hexDigit - '0');
    } else if( hexDigit >= 'A' && hexDigit <= 'F') {
        return(hexDigit - 'A' + 10);
    } else if( hexDigit >= 'a' && hexDigit <= 'f') {
        return(hexDigit - 'a' + 10);
    } else {
        // error digit
        return(-1);
    }
}
