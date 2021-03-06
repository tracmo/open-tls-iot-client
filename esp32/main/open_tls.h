/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#ifndef _OPEN_TLS_H_
#define _OPEN_TLS_H_

///////////////////////////////////////////////////////////////////////////////////
// defines
#define OPEN_TLS_IP_TYPE_DHCP               0
#define OPEN_TLS_IP_TYPE_STATIC             1

#define OPEN_TLS_WIFI_CHANNEL_GENERIC       0
#define OPEN_TLS_WIFI_CHANNEL_US            1
#define OPEN_TLS_WIFI_CHANNEL_JP            2

///////////////////////////////////////////////////////////////////////////////////
// USER SOFTWARE CONFIGURATIONS
#define OPEN_TLS_WIFI_CHANNEL               OPEN_TLS_WIFI_CHANNEL_GENERIC
#define OPEN_TLS_WIFI_SSID                  "myssid"
#define OPEN_TLS_WIFI_PASSWORD              "mypassword"
#define OPEN_TLS_IP_TYPE                    OPEN_TLS_IP_TYPE_DHCP
#define OPEN_TLS_MQTT_BROKER                "mqtts://my-endpoint-ats.iot.amazonaws.com:8883"
#define OPEN_TLS_MQTT_TOPIC                 "mytopic/demo"
#define OPEN_TLS_OTP_AES_KEY                "11223344556677889900aabbccddeeff"  // my AES key

// If "OPEN_TLS_IP_TYPE_STATIC" is used, continue the configurations below
#define OPEN_TLS_IP_ADDR                    "IP_ADDR"
#define OPEN_TLS_IP_NETMASK                 "IP_NETMASK"
#define OPEN_TLS_IP_GATEWAY                 "IP_GATEWAY"
#define OPEN_TLS_IP_MAIN_DNS                "IP_MAIN_DNS"
#define OPEN_TLS_IP_BACKUP_DNS              "IP_BACKUP_DNS"

///////////////////////////////////////////////////////////////////////////////////
// USER HARDWARE CONFIGURATIONS
#define OPEN_TLS_HW_LED1                    GPIO_NUM_14
#define OPEN_TLS_HW_LED2                    GPIO_NUM_4
#define OPEN_TLS_HW_BUTTON                  GPIO_NUM_8

// Physical Control
#define OPEN_TLS_HW_DOOR_OPEN               GPIO_NUM_2
#define OPEN_TLS_HW_DOOR_STOP               GPIO_NUM_12
#define OPEN_TLS_HW_DOOR_CLOSE              GPIO_NUM_13

// time to perform stop after open-stop-close action is triggered
#define OPEN_TLS_DOOR_OPEN_STOP_CLOSE_TIMER_STOP  10      // in seconds

// time to perform close after open-stop-close action is triggered
// this time must be longer than the stop delayed timer
#define OPEN_TLS_DOOR_OPEN_THEN_CLOSE_TIMER_CLOSE 60      // in seconds

///////////////////////////////////////////////////////////////////////////////////
// more defines
#define T_DEVICE_WATCHDOG_TIMER_SEC       60
#define T_DEVICE_LEGITIMATE_TIME          1537962074     // any time prior than this time is not valid

///////////////////////////////////////////////////////////////////////////////////
// Global Variables
extern char t_device_sn_str[24];                          // "TT-AABBCCDDEEFF"
extern uint8_t t_device_MAC[6];                           // this is the WiFi MAC
extern char t_device_wifi_ssid[20];
extern uint8_t t_device_wifi_bssid[6];

#endif
