<p align="center">
	<img src="images/tls_iot_tool.png" width="25%" alt="TLS-IoT-Tools"/>
</p> 

# open-tls-iot-client

### Introduction

This open source project is co-sponsored by Tracmo, Inc. The goal is to build an end-to-end secured MQTTs communication to control an end IoT device. The target is to build a tool supporting the following features:
* Use only X.509 to authenticate and secure the communication
* Support CA Root authentication
* Support Face ID or Touch ID
* Prevent Middle-Man Attack
* No need to set a NAT port forward for the end IoT device

### How is this project organized?

| Folder     | Description                                                  |
|------------|--------------------------------------------------------------|
| esp32      | Source and the binary build of ESP32 based target IoT Device |
| images     | Icon and image files                                         |
| ios        | Source code of the iOS app                                   |
| test_tools | Test tools to simulate the target IoT Device                 |

### Contributors

| Contributor | Contact                  | Roles                                      |
|-------------|--------------------------|--------------------------------------------|
| Samson Chen | samson AT mytracmo.com   | Project Coordinator, ESP32, Documentations |
| Eric Jan    | janeric11yt AT gmail.com | iOS App                                    |
| Jie Chien   | jie AT mytracmo.com      | App Icon Design                            |

We welcome your participations. If you are interested in joining this project, please email us via
opensource AT mytracmo.com

### LICENSE

MIT License

Copyright (c) 2020 Tracmo, Inc.

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

##### MQTT Client Framework

https://github.com/novastone-media/MQTT-Client-Framework

License
https://github.com/novastone-media/MQTT-Client-Framework/blob/master/LICENSE

##### Open SSL for iOS

https://github.com/x2on/OpenSSL-for-iPhone

License
https://github.com/x2on/OpenSSL-for-iPhone/blob/master/LICENSE

##### Keychain Swift

https://github.com/evgenyneu/keychain-swift

License
https://github.com/evgenyneu/keychain-swift/blob/master/LICENSE
