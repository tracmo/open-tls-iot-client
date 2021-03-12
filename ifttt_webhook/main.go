/*
 * Project Secured MQTT Publisher
 * Copyright 2021 Tracmo, Inc. ("Tracmo").
 * Open Source Project Licensed under MIT License.
 * Please refer to https://github.com/tracmo/open-tls-iot-client
 * for the license and the contributors information.
 *
 */

package main

import (
	"context"
	"strconv"

	"github.com/romana/rlog"

	"github.com/aws/aws-lambda-go/lambda"

	IFTTT "github.com/domnikl/ifttt-webhook"
)

///////////////////////////////////////////////////////////////////////////////////
// Configurations
const lambdaFuncVersion = "v1.3.0/2021-Mar-12"

const iftttWebhookAPIKey = "<your_ifttt_webhook_api_key>"
const iftttWebhookNotificationEvent = "<your_ifttt_webhook_notification_event_name>"
const iftttWebhookLogEvent = "<your_ifttt_webhook_log_event_name>"
const commandOpen = 1
const commandStop = 2
const commandClose = 3
const commandOpenClose = 4
const commandForceReport = 5

///////////////////////////////////////////////////////////////////////////////////
// Data Types

// predetermined payload data structure from the Mobile App
type payloadDataType struct {
	Command *int    `json:"command"`
	Otp     *string `json:"otp-auth"`
	Sender  *string `json:"sender"`
}

/**
 * Lambda Main Handler
 */
func handler(ctx context.Context, rec payloadDataType) error {

	// check the payload from AWS IoT Core
	if rec.Command == nil {

		rlog.Error("Error to handle incoming data:", rec)
		return nil
	}

	// extract the optinal sender's info
	sender := "NULL"
	if rec.Sender != nil {

		sender = *rec.Sender
	}

	// extract the mandatory command info
	command := *rec.Command

	// convert the command code into the readable text
	commandText := strconv.Itoa(command)
	switch command {
	case commandOpen:
		commandText = "open"

	case commandStop:
		commandText = "stop"

	case commandClose:
		commandText = "close"

	case commandOpenClose:
		commandText = "auto"

	case commandForceReport:
		commandText = "report"
	}

	rlog.Infof("New Event command=%d (%s), sender=%s", command, commandText, sender)

	// intiate the IFTTT service
	ifttt := IFTTT.New(iftttWebhookAPIKey)

	// trigger IFTTT notification with only the designated commands
	if command == commandOpen || command == commandOpenClose {

		rlog.Infof("Triggering IFTTT notification event %s", iftttWebhookNotificationEvent)

		ifttt.Emit(iftttWebhookNotificationEvent, sender, commandText, strconv.Itoa(command))
	}

	// log all the commands
	ifttt.Emit(iftttWebhookLogEvent, sender, commandText, strconv.Itoa(command))

	return nil
}

/**
 * Main Function
 */
func main() {
	rlog.Infof("Open-TLS IFTTT Trigger, Version %s", lambdaFuncVersion)
	lambda.Start(handler)
}
