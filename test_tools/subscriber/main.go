/*
 *  Project Secured MQTT Publisher
 *  Copyright 2026 Care Active Corp. ("Care Active").
 *  Open Source Project Licensed under MIT License.
 *  Please refer to https://github.com/tracmo/open-tls-iot-client
 *  for the license and the contributors information.
 */

// https://github.com/eclipse/paho.mqtt.golang/issues/72

package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"time"

	MQTT "github.com/eclipse/paho.mqtt.golang"
)

/**
 * MQTT Connect Event Handler
 */
func onConnectHandler(client MQTT.Client) {
	log.Println("CONNECTED EVENT")

	if token := client.Subscribe("securedios/demo", 0, onRecvMsgHandler); token.Wait() && token.Error() != nil {
		fmt.Println(token.Error())
	}
}

/**
 * MQTT Disconnect Event Handler
 */
func onDisconnectHandler(client MQTT.Client, err error) {
	log.Println("MQTT DISCONNECTED:" + err.Error())
}

/**
 * MQTT Messages Receiving Event Handler
 */
func onRecvMsgHandler(client MQTT.Client, inMsg MQTT.Message) {
	str := string(inMsg.Payload())
	log.Println(str)
}

func main() {

	// load CA Root
	certpool := x509.NewCertPool()
	pemCerts, errCA := ioutil.ReadFile("../aws-root-ca.pem")
	if errCA != nil {
		log.Println("Unable to load Root CA, skip Root CA verification")
	} else {
		log.Println("Root CA will be verified")
	}
	certpool.AppendCertsFromPEM(pemCerts)

	// get X.509 key pair
	cer, err := tls.LoadX509KeyPair("../my-certificate.pem.crt", "../my-private.pem.key")
	check(err)

	s1 := rand.NewSource(time.Now().UnixNano())
	cid := "goMQTTclient" + fmt.Sprintf("-%x", rand.New(s1).Intn(65536))
	log.Printf("client ID: %s\n", cid)

	var myTLSConfig *tls.Config
	if errCA == nil {
		// TLS with CA Root
		myTLSConfig = &tls.Config{Certificates: []tls.Certificate{cer}, RootCAs: certpool}
	} else {
		// TLS without CA Root
		myTLSConfig = &tls.Config{Certificates: []tls.Certificate{cer}}
	}

	connOpts := &MQTT.ClientOptions{
		ClientID:             cid,
		CleanSession:         true,
		AutoReconnect:        true,
		MaxReconnectInterval: 1 * time.Minute,
		ConnectTimeout:       0,
		KeepAlive:            60,
		PingTimeout:          15 * time.Second,
		TLSConfig:            myTLSConfig,
		OnConnect:            onConnectHandler,
		OnConnectionLost:     onDisconnectHandler,
	}

	host := "a33eb93essa9os-ats.iot.us-west-2.amazonaws.com"
	port := 8883
	path := "/mqtt"

	brokerURL := fmt.Sprintf("tcps://%s:%d%s", host, port, path)
	connOpts.AddBroker(brokerURL)

	mqttClient := MQTT.NewClient(connOpts)
	if token := mqttClient.Connect(); token.Wait() && token.Error() != nil {
		panic(token.Error())
	}
	log.Println("[MQTT Subscriber] Connected")

	quit := make(chan struct{})
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		<-c
		mqttClient.Disconnect(250)
		fmt.Println("[MQTT] Disconnected")

		quit <- struct{}{}
	}()
	<-quit
}

func check(err error) {
	if err != nil {
		panic(err)
	}
}
