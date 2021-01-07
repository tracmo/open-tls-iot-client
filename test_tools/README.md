# MQTT Testing Tools

Before you build your physical IoT device, you can use this tool to simulate the MQTT event subscribing and publishing.

### Environment to run the tool

The testing tools were written by Go language. To install the golang environment, please go to...<br>

[The Go Programming Language](https://golang.org/)

### Prepare your AWS IoT Certificates

You can create yor own AWS account for free. Please refer to this project Wiki to get your own AWS IoT Core device certificates...<br>

[How to create the AWS IoT device certificates?](https://github.com/tracmo/open-tls-iot-client/wiki/How-to-create-the-AWS-IoT-device-certificate%3F)

### Certificates and End-Point

Your AWS IoT device certificates include
* a private key
* a certificate
* a public key

We will not need the public key. Put the private key and the certificate with the test tools. Edit **subscriber/main.go** and **publisher/main.go**.

```golang
// get X.509 key pair
cer, err := tls.LoadX509KeyPair("../my-certificate.pem.crt", "../my-private.pem.key")
```

Replace the certificate and the key with the ones you generated on the AWS IoT Core Console.

```golang
host := "a33eb93essa9os-ats.iot.us-west-2.amazonaws.com"
```

You also need to update the host with your end-point. Your AWS IoT Core end-point is listed in the setting of the IoT Core console.

### Topic and the permissions

This test tool publishes and subscribes the topic of "securedios/demo". Make sure the AWS IoT Core device certificate is attached with the correct policy to allow this topic to be subscribed and published.

### Run the subscriber and the publisher

It is quite simple to run the tool, simply...

```
go run main.go
```

for both the subscriber and the publisher.

### With or without the ROOT CA

ROOT CA is optional. If the ROOT CA does exist, the tool will verify the TLS session with the ROOT CA. If it is removed, then the verification is skipped. There are two ROOT CAs are archived in this repository. aws-root-ca.pem is the ROOT CA of AWS IoT Core. gtsltsr.pem was actually the ROOT CA of Google Cloud. You can try to replace the AWS ROOT CA with Google Cloud's. You will find the tool complains immediately. This is the same behavior in the mobile app.

