//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import AVFoundation

enum SoundEffect {
    static private var player: AVAudioPlayer?
    
    case success
    case failure
        
    func play() {
        do {
            SoundEffect.player = try AVAudioPlayer(contentsOf: url)
            SoundEffect.player?.play()
        } catch { NSLog("SMP SoundEffect play error: \(error)") }
    }
    
    private var url: URL {
        switch self {
        case .success: return Bundle.main.url(forResource: "success", withExtension: "mp3")!
        case .failure: return Bundle.main.url(forResource: "failure", withExtension: "wav")!
        }
    }
}
