import Flutter
import UIKit
import MediaPlayer

public class SwiftNowPlayingPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "gomes.com.es/nowplaying", binaryMessenger: registrar.messenger())
    let instance = SwiftNowPlayingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    MPRemoteCommandCenter.shared().pauseCommand.addTarget { event in
        channel.invokeMethod("pause", arguments: nil)
        return MPRemoteCommandHandlerStatus.success
    }
    MPRemoteCommandCenter.shared().playCommand.addTarget { event in
        channel.invokeMethod("play", arguments: nil)
        return MPRemoteCommandHandlerStatus.success
    }
  }

  var trackData: [String: Any?] = [:]
  let imageSize: CGSize = CGSize(width: 400, height: 400)

    enum ImageError: Error {
        case notPresent(artwork: MPMediaItemArtwork)
    }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "track":
          let musicPlayer = MPMusicPlayerController.systemMusicPlayer
          if let nowPlayingItem = musicPlayer.nowPlayingItem {
            let id = "\(nowPlayingItem.title ?? ""):\(nowPlayingItem.artist ?? ""):\(nowPlayingItem.albumTitle ?? "")"
            if trackData["id"] == nil || (trackData["id"] as! String) != id {
              trackData["id"] = id
              trackData["album"] = nowPlayingItem.albumTitle
              trackData["title"] = nowPlayingItem.title
              trackData["artist"] = nowPlayingItem.artist
              trackData["genre"] = nowPlayingItem.genre
              trackData["duration"] = Int(nowPlayingItem.playbackDuration * 1000)
              trackData["image"] = nowPlayingItem.artwork?.image(at: imageSize)?.pngData()
              trackData["source"] = "com.apple.music"
            }

            trackData["position"] = Int(musicPlayer.currentPlaybackTime * 1000)

            switch musicPlayer.playbackState {
              case MPMusicPlaybackState.playing, MPMusicPlaybackState.seekingForward, MPMusicPlaybackState.seekingBackward:
                trackData["state"] = 0
              case MPMusicPlaybackState.paused, MPMusicPlaybackState.interrupted:
                trackData["state"] = 1
              case MPMusicPlaybackState.stopped:
                trackData["state"] = 2
              default:
                trackData["state"] = 2
            }
          } else {
            trackData = [:]
          }

          result(trackData)
          break;
      case "update":
       
        
        guard  let args = call.arguments as? [String:String], let artist = args["artist"], let title = args["title"] else {
            return
        }
        
        guard let artwork = args["artwork"] else {
            let nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyArtist: artist,
                MPMediaItemPropertyTitle: title,
            ]

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            return
        }

        getArt(url: artwork, completion: { artwork in
            let nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyArtist: artist,
                MPMediaItemPropertyTitle: title,
                MPMediaItemPropertyArtwork: artwork
            ]

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        })
      default:
          result(FlutterMethodNotImplemented)
    }
  }

    func getData(from url: URL, completion: @escaping (UIImage?) -> Void) {
           URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
               if let data = data {
                   completion(UIImage(data:data))
               }
           })
               .resume()
       }

    func getArt(url: String, completion: @escaping (MPMediaItemArtwork) -> Void) {
           guard let url = URL(string: url) else { return }
           getData(from: url) { [weak self] image in
               guard let self = self,
                   let downloadedImage = image else {
                       return
               }
               let artwork = MPMediaItemArtwork.init(boundsSize: downloadedImage.size, requestHandler: { _ -> UIImage in
                   return downloadedImage
               })
               completion(artwork)
           }
       }
}
