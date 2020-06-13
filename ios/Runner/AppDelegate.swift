/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Flutter
import Photos


@UIApplicationMain
/*@objc*/ class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
    ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    let channel = FlutterMethodChannel(name: "/gallery", binaryMessenger: controller as! FlutterBinaryMessenger)
    channel.setMethodCallHandler { (call, result) in
      switch (call.method) {
      case "getItemCount": result(self.getGalleryImageCount())
      case "getItem":
        let index = call.arguments as? Int ?? 0
        self.dataForGalleryItem(index: index, completion: { (data, id, created, location) in
            result([
                "data": data ?? Data(),
                "id": id,
                "created": created,
                "location": location
            ])
        })
      default: result(FlutterError(code: "0", message: nil, details: nil))
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func dataForGalleryItem(index: Int, completion: @escaping (Data?, String, Int, String) -> Void) {
    let fetchOptions = PHFetchOptions()

    let collection: PHFetchResult = PHAsset.fetchAssets(with: fetchOptions)
    if (index >= collection.count) {
      return
    }

    let asset = collection.object(at: index)

    let options = PHImageRequestOptions()
    options.deliveryMode = .fastFormat
    options.isSynchronous = true

    let imageSize = CGSize(width: 250,
                           height: 250)

    let imageManager = PHCachingImageManager()
    imageManager.requestImage(for: asset, targetSize: imageSize, contentMode: .aspectFit, options: options) { (image, info) in
      if let image = image {
        let data = UIImageJPEGRepresentation(image, 0.9)
        completion(data,
                   asset.localIdentifier,
                   Int(asset.creationDate?.timeIntervalSince1970 ?? 0),
                   "\(asset.location ?? CLLocation())")
      } else {
        completion(nil, "", 0, "")
      }
    }
  }

  func getGalleryImageCount() -> Int {
    let fetchOptions = PHFetchOptions()
    fetchOptions.includeHiddenAssets = true

    let collection: PHFetchResult = PHAsset.fetchAssets(with: fetchOptions)
    return collection.count
  }
}
