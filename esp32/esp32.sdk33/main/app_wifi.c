/*
 * Project Secured MQTT Publisher
 * Copyright 2026 Care Active Corp. ("Care Active").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

#include <string.h>
#include <lwip/sockets.h>

#include "esp_wifi.h"
#include "esp_event_loop.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_task_wdt.h"
#include "freertos/event_groups.h"
#include "esp_log.h"
#include "app_wifi.h"
#include "lwip/err.h"
#include "lwip/apps/sntp.h"

#include "open_tls.h"
#include "t_gpio.h"
#include "util.h"

static const char *TAG = "WIFI";

///////////////////////////////////////////////////////////////////////////////////
// defines
#define APP_WIFI_MAX_NTP_RETRY_TIME             600     // in seconds

///////////////////////////////////////////////////////////////////////////////////
// local variables

// FreeRTOS event group to signal when we are connected & ready to make a request
static EventGroupHandle_t wifi_event_group = NULL;

/* The event group allows multiple bits for each event,
   but we only care about one event - are we connected
   to the AP with an IP? */
static const int APP_WIFI_CONNECTED_BIT = BIT0;

///////////////////////////////////////////////////////////////////////////////////
// local functions
static esp_err_t event_handler(void *ctx, system_event_t *event);
static void app_wifi_connect_ap(void);
static wifi_config_t app_wifi_get_config(void);

///////////////////////////////////////////////////////////////////////////////////
// public function implementations

/**
 * WiFi init, set ip settings
 * NOTE: Start connect to ap when SYSTEM_EVENT_STA_START event
 */
void app_wifi_initialise(void)
{
    tcpip_adapter_init();
    wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_event_loop_init(event_handler, NULL));
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));

    // check ip type, default is DHCP
    int32_t ipType = OPEN_TLS_IP_TYPE;
    if( ipType != OPEN_TLS_IP_TYPE_DHCP && ipType != OPEN_TLS_IP_TYPE_STATIC ) {
        ipType = OPEN_TLS_IP_TYPE_DHCP;
    }

    if( ipType == OPEN_TLS_IP_TYPE_STATIC ) {
        esp_err_t err = ESP_FAIL;
        tcpip_adapter_ip_info_t ipInfo;
        tcpip_adapter_dns_info_t dnsInfo;
        tcpip_adapter_dns_info_t dnsInfoBackup;
        char *ip = OPEN_TLS_IP_ADDR;
        char *netmask = OPEN_TLS_IP_NETMASK;
        char *gw = OPEN_TLS_IP_GATEWAY;
        char *dns = OPEN_TLS_IP_MAIN_DNS;
        char *dnsBackup = OPEN_TLS_IP_BACKUP_DNS;

        // clean dns info
        memset(&dnsInfo, 0x00, sizeof(dnsInfo));
        memset(&dnsInfoBackup, 0x00, sizeof(dnsInfoBackup));

        do {
            // for using of static IP
            err = tcpip_adapter_dhcpc_stop(TCPIP_ADAPTER_IF_STA);
        } while( err != ESP_OK );

        if( ip != NULL ) {
            // set ip to wifi info
            inet_pton(AF_INET, ip, &ipInfo.ip);
        }

        if( netmask != NULL ) {
            // set netmask to wifi info
            inet_pton(AF_INET, netmask, &ipInfo.netmask);
        }

        if( gw != NULL ) {
            // set gateway to wifi info
            inet_pton(AF_INET, gw, &ipInfo.gw);
        }

        do {
            // set ip config
            err = tcpip_adapter_set_ip_info(TCPIP_ADAPTER_IF_STA, &ipInfo);
        } while( err != ESP_OK );

        if( dns != NULL ) {
            // set dns to dns info
            ip4addr_aton(dns, &dnsInfo.ip.u_addr.ip4) ;

            do {
                // set main dns config
                err = tcpip_adapter_set_dns_info(TCPIP_ADAPTER_IF_STA, TCPIP_ADAPTER_DNS_MAIN, &dnsInfo);
            } while( err != ESP_OK );
        }

        if( dnsBackup != NULL ) {
            // set dns to dns info
            ip4addr_aton(dnsBackup, &dnsInfoBackup.ip.u_addr.ip4) ;

            do {
                // set backup dns config
                err = tcpip_adapter_set_dns_info(TCPIP_ADAPTER_IF_STA, TCPIP_ADAPTER_DNS_BACKUP, &dnsInfoBackup);
            } while( err != ESP_OK );
        }
    }

    // setup wifi band type
    if( OPEN_TLS_WIFI_CHANNEL != OPEN_TLS_WIFI_CHANNEL_GENERIC ) {

        wifi_country_t wifiBand;
        wifiBand.schan = 1;
        wifiBand.policy = WIFI_COUNTRY_POLICY_AUTO; // policy can be changed based on the connected AP

        // determin the tail band
        switch( OPEN_TLS_WIFI_CHANNEL ) {

            case OPEN_TLS_WIFI_CHANNEL_JP:
                strcpy(wifiBand.cc, "JP");
                wifiBand.nchan = 14;
                break;

            case OPEN_TLS_WIFI_CHANNEL_US:
                strcpy(wifiBand.cc, "US");
                wifiBand.nchan = 11;
                break;
        }

        ESP_ERROR_CHECK(esp_wifi_set_country(&wifiBand));
    }

    // process SSID/PASSWORD
    wifi_config_t wifiConfig = app_wifi_get_config();

    ESP_LOGI(TAG, "Setting WiFi configuration SSID %s...", wifiConfig.sta.ssid);
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifiConfig));
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));
    ESP_ERROR_CHECK(esp_wifi_start());
}


/**
 * Wait until WiFi connect
 */
void app_wifi_wait_connected(void)
{
    xEventGroupWaitBits(wifi_event_group, APP_WIFI_CONNECTED_BIT, false, true, portMAX_DELAY);
}


/**
 * Check if WiFi is connected
 * Note: WiFi is connected does NOT indicate the Internet is connected
 *
 * @return true if WiFi is connected otherwise false
 */
bool app_wifi_is_connected(void)
{
    bool result = false;

    if( wifi_event_group != NULL ) {
        if( xEventGroupGetBits(wifi_event_group) & APP_WIFI_CONNECTED_BIT ) {
            result = true;
        }
    }

    return(result);
}


/**
 * Request another time sync request
 */
void app_wifi_ntp_request(void)
{
    // stop the previoud SNTP handler
    sntp_stop();

    // create another one
    sntp_init();
}


/**
 * Initlize NTP Client
 */
void app_wifi_ntp_init(void)
{
    // wait until the WiFi is connected
    app_wifi_wait_connected();

    // init SNTP
    ESP_LOGI(TAG, "Initializing SNTP");
    sntp_setoperatingmode(SNTP_OPMODE_POLL);
    sntp_setservername(0, "pool.ntp.org");
    sntp_init();

    // wait for time to be set
    time_t now = 0;
    struct tm timeinfo = { 0 };
    char strftime_buf[64];

    // keep led blinking until time is obtained
    t_gpio_led_mode(T_GPIO_LED_MODE_ERROR_BLINKING);

    // attempt to get MAYBE the already configured
    time(&now);
    localtime_r(&now, &timeinfo);

    // whatsoever, still request at least one NTP
    app_wifi_ntp_request();

    // time is critical, stay here until time is obtained
    uint32_t retryCounter = 0;
    while( timeinfo.tm_year < (2016 - 1900) ) {
        ESP_LOGI(TAG, "Waiting for system time to be set... (Attempt %d)", ++retryCounter);
        vTaskDelay(2000 / portTICK_PERIOD_MS);
        time(&now);
        localtime_r(&now, &timeinfo);

        app_wifi_ntp_request();
        ESP_LOGI(TAG, "Resending NTP request");

        // set retry limitation
        if( (retryCounter * 2) > APP_WIFI_MAX_NTP_RETRY_TIME ) {
            ESP_LOGI(TAG, "NTP attemps too many times, restart the system");

            // system will reboot immediately
            esp_restart();

            // SYSTEM REBOOT ...
        }

        // reset watchdog
        esp_task_wdt_reset();
    }

    // switch to normal led
    t_gpio_led_mode(T_GPIO_LED_MODE_CLEAR_ERROR);

    // output the obtained GMT
    setenv("TZ", "GMT", 1);
    tzset();
    localtime_r(&now, &timeinfo);
    strftime(strftime_buf, sizeof(strftime_buf), "%c", &timeinfo);
    ESP_LOGI(TAG, "Obtained %ld GMT date/time: %s", now, strftime_buf);
}


/**
 * Get AP rssi
 *
 * @return rssi of ap, return 0 if no wifi
 */
int8_t app_wifi_get_rssi(void)
{
    wifi_ap_record_t wifiInfo;
    int8_t rssi = 0;

    // get ap info
    if( esp_wifi_sta_get_ap_info(&wifiInfo) == ESP_OK ){
        // get rssi from ap info
        rssi = wifiInfo.rssi;
    }

    return(rssi);
}


///////////////////////////////////////////////////////////////////////////////////
// local function implementations

/**
 * WiFi event handler
 */
static esp_err_t event_handler(void *ctx, system_event_t *event)
{
    switch( event->event_id ) {
        case SYSTEM_EVENT_STA_START:
            // set hostname
            tcpip_adapter_set_hostname(TCPIP_ADAPTER_IF_STA, "open-tls-device");

            // scan and connect to strongest ap
            app_wifi_connect_ap();
            break;

        case SYSTEM_EVENT_STA_GOT_IP: {
            wifi_ap_record_t wifiInfo;

            // get ap info
            if( esp_wifi_sta_get_ap_info(&wifiInfo) == ESP_OK ){
                // get bssid from ap info
                memcpy(t_device_wifi_bssid, wifiInfo.bssid, 6);
            }

            // set event group tag
            xEventGroupSetBits(wifi_event_group, APP_WIFI_CONNECTED_BIT);

            // normal status
            t_gpio_led_mode(T_GPIO_LED_MODE_CLEAR_ERROR);

            break;
        }

        case SYSTEM_EVENT_STA_DISCONNECTED:

            // blinking led
            t_gpio_led_mode(T_GPIO_LED_MODE_ERROR_BLINKING);

            // set disconnect status
            // NOTE: set before app_wifi_connect_ap(), or
            //      would be too late
            xEventGroupClearBits(wifi_event_group, APP_WIFI_CONNECTED_BIT);

            // cleanup wifi state
            // NOTE: do it before app_wifi_connect_ap(), for wifi scan
            esp_wifi_disconnect();

            // reconnect to ap
            app_wifi_connect_ap();
            break;

        default:
            break;
    }
    return(ESP_OK);
}


/**
 * Search the strongest ap with the config essid, then connect to the ap
 */
static void app_wifi_connect_ap(void)
{
    wifi_ap_record_t *wifiScanList = NULL;
    uint16_t apCount;
    wifi_scan_config_t wifiScanConf = {
        .ssid = NULL,
        .bssid = NULL,
        .channel = 0,
        .show_hidden = 1
    };

    // start wifi scan
    esp_err_t err = esp_wifi_scan_start(&wifiScanConf, true);
    if( err != ESP_OK ) {
        // scan failed, try connect
        esp_wifi_connect();
        return;
    }

    // get number of APs found in last scan
    esp_wifi_scan_get_ap_num(&apCount);

    if( apCount > 0 ) {
        // malloc sacn list
        wifiScanList = malloc(sizeof(wifi_ap_record_t) * apCount);
        if( wifiScanList != NULL ) {
            // get scan list
            esp_wifi_scan_get_ap_records(&apCount, wifiScanList);

            // get SSID/PASSWORD
            wifi_config_t wifiConfig = app_wifi_get_config();

            for( int32_t index = 0; index < apCount; index++ ) {
                // find the bssid of the strongest ap from scan list
                // NOTE: default sort by rssi, so first one must be the strongest one
                if( !strcmp((char *)wifiScanList[index].ssid, (char *)wifiConfig.sta.ssid) ) {
                    // set bssid to config
                    memcpy(wifiConfig.sta.bssid, wifiScanList[index].bssid, 6);

                    // force to use only this ap
                    wifiConfig.sta.bssid_set = true;

                    // commit setting
                    esp_wifi_set_config(ESP_IF_WIFI_STA, &wifiConfig);

                    break;
                } // end if( !strcmp((char *)apList[index].ssid, (char *)wifiConfig.sta.ssid) )
            } // end for
        } // end if( wifiScanList != NULL )

        // free malloc
        UTIL_FREE(wifiScanList);
    } // end if( apCount > 0 )

    // connect to wifi
    esp_wifi_connect();
}


/**
 * Get wifi config, ssid and password
 *
 * @return wifiConfig of user config
 */
static wifi_config_t app_wifi_get_config(void)
{
    wifi_config_t wifiConfig;

    // init wifi config
    memset(&wifiConfig, 0x00, sizeof(wifi_config_t));

    char *t4essid = OPEN_TLS_WIFI_SSID;
    char *t4password = OPEN_TLS_WIFI_PASSWORD;

    if( t4essid != NULL && t4password != NULL ) {
        strcpy((char *) wifiConfig.sta.ssid, t4essid);
        strcpy((char *) wifiConfig.sta.password, t4password);
    } else {
        strcpy((char *) wifiConfig.sta.ssid, "myssid");
        strcpy((char *) wifiConfig.sta.password, "mypassword");
    }

    // duplicate ssid for the device report (long name will be truncated)
    strncpy(t_device_wifi_ssid, (char *) wifiConfig.sta.ssid, 19);
    t_device_wifi_ssid[19] = 0;

    return(wifiConfig);
}
