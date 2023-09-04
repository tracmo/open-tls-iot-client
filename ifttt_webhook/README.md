# AWS Lambda Function for IoT Core Rule Action

## Build for AWS Lambda

```script
GOARCH=amd64 GOOS=linux go build -tags lambda.norpc -o bootstrap main.go
```

Starting from December 31st, 2023, ```provided.al2``` is required for the AWS Lambda with Golang.

Refer to [Adding Mobile Notifications](https://github.com/tracmo/open-tls-iot-client/wiki/Adding-mobile-notifications) for more information.
