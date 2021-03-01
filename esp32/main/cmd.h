/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#ifndef _CMD_H_
#define _CMD_H_

#include "esp_system.h"

///////////////////////////////////////////////////////////////////////////////////
// defines

///////////////////////////////////////////////////////////////////////////////////
// typdefs
typedef enum {
    CMD_ACTION_NONE = 0,
    CMD_ACTION_OPEN = 1,
    CMD_ACTION_STOP = 2,
    CMD_ACTION_CLOSE = 3,
    CMD_ACTION_OPEN_CLOSE = 4,
    CMD_ACTION_INVALID = 5
} cmd_action_code_t;

typedef struct {
    uint32_t command_action;
    uint8_t otpAuth[16];
} cmd_action_t;


///////////////////////////////////////////////////////////////////////////////////
// public functions
void cmd_init(void);
void cmd_add(cmd_action_t *cmdSet);

#endif
