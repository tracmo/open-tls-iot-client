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
const lambdaFuncVersion = "v1.1.0/2021-Mar-10"

const iftttWebhookAPIKey = "<your_ifttt_webhook_api_key>"
const iftttWebhookEventName = "<your_ifttt_webhook_event_name>"
const commandOpen = 1
const commandOpenClose = 4

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

	// convert the payload from AWS IoT Core
	if rec.Command == nil || rec.Otp == nil || rec.Sender == nil {

		if rec.Command != nil {

			rlog.Error("Skip incoming command:", *rec.Command, rec)

		} else {

			rlog.Error("Error to handle incoming data:", rec)

		}

		return nil
	}

	rlog.Infof("New Event command=%d, sender=%s", *rec.Command, *rec.Sender)

	// trigger IFTTT with only the designated command
	if *rec.Command == commandOpen || *rec.Command == commandOpenClose {

		rlog.Infof("Triggering IFTTT event %s", iftttWebhookEventName)

		i := IFTTT.New(iftttWebhookAPIKey)
		i.Emit(iftttWebhookEventName, *rec.Sender, strconv.Itoa(*rec.Command), "value3")
	} else {

		rlog.Info(" No IFTTT Trigger")
	}

	return nil
}

/**
 * Main Function
 */
func main() {
	rlog.Infof("Open-TLS IFTTT Trigger, Version %s", lambdaFuncVersion)
	lambda.Start(handler)
}
