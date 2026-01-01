<p align="center">
	<img src="images/tls_iot_tool.png" width="25%" alt="TLS-IoT-Tools"/>
</p> 

# open-tls-iot-client

### Introduction

Looking for a secure tool to control your IoT device, such as a garage door? This is it. This open source project is co-sponsored by [Care Active Corp](https://careactive.ai/). The goal is to build an end-to-end **highly** secure MQTT communication to control an IoT device. The target is to build a mobile app that has the following features:
* Use only X.509 to authenticate and secure the communication
* Support Root CA authentication
* Support Face ID or Touch ID
* Prevent Man-in-the-Middle Attack
* No need to set a NAT port forward for the end IoT device

![Conceptual Architecture](https://github.com/tracmo/open-tls-iot-client/blob/main/images/figures/Secured-MQTT-Page-1.png?raw=true)

### How is this project organized?

| Folder     | Description                                                  |
|------------|--------------------------------------------------------------|
| [esp32](https://github.com/tracmo/open-tls-iot-client/tree/main/esp32)      | Source and the binary build of ESP32 based target IoT Device |
| [images](https://github.com/tracmo/open-tls-iot-client/tree/main/images)     | Icon and image files                                         |
| [ios](https://github.com/tracmo/open-tls-iot-client/tree/main/ios)        | Source code of the iOS app                                   |
| [test_tools](https://github.com/tracmo/open-tls-iot-client/tree/main/test_tools) | Test tools to simulate the target IoT Device                 |
| [ifttt_webhook](https://github.com/tracmo/open-tls-iot-client/tree/main/ifttt_webhook) | Lambda Function for AWS IoT Rule Engine                 |

### More Information

Each folder has its own README document. Please open the folder to see the document. For the overall technical instructions, please go to the project Wiki page.

[Open TLS IoT Wiki](https://github.com/tracmo/open-tls-iot-client/wiki)

[中文資訊 (Information in Chinese)](https://github.com/tracmo/open-tls-iot-client/wiki/Home_zh)

***

### Sample Use-Case and The Origin of This Project

When I tried to build a smartphone-based garage door control, making the door control device was not the difficult part. When I was looking for a mobile app that is easy to use and secure, I could not find a good alternative that could meet all my needs, especially the security features. Since it is a door being controlled, it has to be a very secure method. Most apps that support makers use REST-based control. It is easy to use but lacks security. All I wanted was an end-to-end secure and easy-to-use app, so I decided to create a new one.

This is the app screen.

<img src="https://raw.githubusercontent.com/wiki/tracmo/open-tls-iot-client/images/app/app-main-screen-original.png" width="40%" alt="The app main screen"/>

The remote control box built with an ESP32-PICO-MINI-02 kit.

<img src="https://raw.githubusercontent.com/wiki/tracmo/open-tls-iot-client/images/demos/final_box.png" width="60%" alt="The remote control box"/>

This is the video to demonstrate how it works.

[![final testing](https://img.youtube.com/vi/s7u8p_ucmuI/0.jpg)](https://youtu.be/s7u8p_ucmuI "final testing")

For more information, please check [the full demo videos](https://github.com/tracmo/open-tls-iot-client/wiki/Demo).

***

### Contributors

| Contributor | Contact                  | Roles                                      |
| ----------- | ------------------------ | ------------------------------------------ |
| Samson Chen | samson AT careactive.ai  | Project Coordinator, ESP32, Documentations |
| Eric Jan    | janeric11yt AT gmail.com | iOS Core App                               |
| Jie Chien   | jie AT careactive.ai     | App Icon and Style Design                  |
| Shaofu Cu   | shaojeng AT gmail.com    | iOS App and Release                        |
| Enos Wu     | p510132006 AT gmail.com  | ESP32 Development                          |

We welcome your participation. If you are interested in joining this project, please email us at
opensource AT careactive.ai

***

### The App

Open TLS MQTT Client in iOS
<p align="left">
	<a href="https://apps.apple.com/us/app/tls-iot-x-509-mqtt/id1554992163" target="_blank">
	<img src="images/appstore-badge-2x.png" width="25%" alt="Open TLS iOS App"/>
	</a>
</p> 

The Android app is not available yet. If you are interested in being a contributor, please contact us.

***

### LICENSE

MIT License

Copyright (c) 2026 Care Active Corp.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### Acknowledgements

This project makes use of the following third party libraries:

##### [MQTT Client Framework](https://github.com/novastone-media/MQTT-Client-Framework)

License
https://github.com/novastone-media/MQTT-Client-Framework/blob/master/LICENSE

##### [Open SSL for iOS](https://github.com/x2on/OpenSSL-for-iPhone)

License
https://github.com/x2on/OpenSSL-for-iPhone/blob/master/LICENSE

##### [Keychain Swift](https://github.com/evgenyneu/keychain-swift)

License
https://github.com/evgenyneu/keychain-swift/blob/master/LICENSE

##### [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift)

License
https://github.com/krzyzanowskim/CryptoSwift/blob/master/LICENSE

This product includes software developed by the "Marcin Krzyzanowski" (http://krzyzanowskim.com/).
