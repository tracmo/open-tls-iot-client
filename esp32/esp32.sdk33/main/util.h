/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#ifndef _UTIL_H_
#define _UTIL_H_

///////////////////////////////////////////////////////////////////////////////////
// Macros
#define UTIL_FREE(m)        if( m != NULL ) { free(m); m = NULL; }

#define UTIL_MIN(a,b)       (((a) < (b)) ? (a) : (b))
#define UTIL_MAX(a,b)       (((a) > (b)) ? (a) : (b))

#define UTIL_HI_UINT16(a)   (((a) >> 8) & 0xFF)
#define UTIL_LO_UINT16(a)   ((a) & 0xFF)

///////////////////////////////////////////////////////////////////////////////////
// public function
bool util_string_to_aes_key(char *str, uint8_t *key);
int8_t util_hex_digit_to_dec(char hexDigit);

#endif
