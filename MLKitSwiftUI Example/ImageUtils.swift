//
//  ImageUtils.swift
//  MLKitSwiftUI Example
//
//  Created by Dohyun Ji on 2021/04/11.
//

import MLKit


class ImageUtils {
    public static func applyMask(mask: SegmentationMask, image: UIImage) -> UIImage? {
        guard let imageBuffer = createImageBuffer(from: image) else { return nil }
        applySegmentationMask(mask: mask, to: imageBuffer,
                              backgroundColor: UIColor.white.withAlphaComponent(1.0),
                              foregroundColor: UIColor.white.withAlphaComponent(0.0))
        return createUIImage(from: imageBuffer, orientation: image.imageOrientation)
    }
    
    public static func applySegmentationMask(
      mask: SegmentationMask, to imageBuffer: CVImageBuffer,
      backgroundColor: UIColor?, foregroundColor: UIColor?
    ) {
      assert(
        CVPixelBufferGetPixelFormatType(imageBuffer) == kCVPixelFormatType_32BGRA,
        "Image buffer must have 32BGRA pixel format type")

      let width = CVPixelBufferGetWidth(mask.buffer)
      let height = CVPixelBufferGetHeight(mask.buffer)
      assert(CVPixelBufferGetWidth(imageBuffer) == width, "Width must match")
      assert(CVPixelBufferGetHeight(imageBuffer) == height, "Height must match")

      if backgroundColor == nil && foregroundColor == nil {
        return
      }

      let writeFlags = CVPixelBufferLockFlags(rawValue: 0)
      CVPixelBufferLockBaseAddress(imageBuffer, writeFlags)
      CVPixelBufferLockBaseAddress(mask.buffer, CVPixelBufferLockFlags.readOnly)

      let maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask.buffer)
      var maskAddress =
        CVPixelBufferGetBaseAddress(mask.buffer)!.bindMemory(
          to: Float32.self, capacity: maskBytesPerRow * height)

      let imageBytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
      var imageAddress = CVPixelBufferGetBaseAddress(imageBuffer)!.bindMemory(
        to: UInt8.self, capacity: imageBytesPerRow * height)

      var redFG: CGFloat = 0.0
      var greenFG: CGFloat = 0.0
      var blueFG: CGFloat = 0.0
      var alphaFG: CGFloat = 0.0
      var redBG: CGFloat = 0.0
      var greenBG: CGFloat = 0.0
      var blueBG: CGFloat = 0.0
      var alphaBG: CGFloat = 0.0

      let backgroundColor = backgroundColor != nil ? backgroundColor : .clear
      let foregroundColor = foregroundColor != nil ? foregroundColor : .clear
      backgroundColor!.getRed(&redBG, green: &greenBG, blue: &blueBG, alpha: &alphaBG)
      foregroundColor!.getRed(&redFG, green: &greenFG, blue: &blueFG, alpha: &alphaFG)

      for _ in 0...(height - 1) {
        for col in 0...(width - 1) {
          let pixelOffset = col * Constants.bgraBytesPerPixel
          let blueOffset = pixelOffset
          let greenOffset = pixelOffset + 1
          let redOffset = pixelOffset + 2
          let alphaOffset = pixelOffset + 3

          let maskValue: CGFloat = CGFloat(maskAddress[col])
          let backgroundRegionRatio: CGFloat = 1.0 - maskValue
          let foregroundRegionRatio = maskValue

          let originalPixelRed: CGFloat =
            CGFloat(imageAddress[redOffset]) / Constants.maxColorComponentValue
          let originalPixelGreen: CGFloat =
            CGFloat(imageAddress[greenOffset]) / Constants.maxColorComponentValue
          let originalPixelBlue: CGFloat =
            CGFloat(imageAddress[blueOffset]) / Constants.maxColorComponentValue
          let originalPixelAlpha: CGFloat =
            CGFloat(imageAddress[alphaOffset]) / Constants.maxColorComponentValue

          let redOverlay = redBG * backgroundRegionRatio + redFG * foregroundRegionRatio
          let greenOverlay = greenBG * backgroundRegionRatio + greenFG * foregroundRegionRatio
          let blueOverlay = blueBG * backgroundRegionRatio + blueFG * foregroundRegionRatio
          let alphaOverlay = alphaBG * backgroundRegionRatio + alphaFG * foregroundRegionRatio

          // Calculate composite color component values.
          // Derived from https://en.wikipedia.org/wiki/Alpha_compositing#Alpha_blending
          let compositeAlpha: CGFloat = ((1.0 - alphaOverlay) * originalPixelAlpha) + alphaOverlay
          var compositeRed: CGFloat = 0.0
          var compositeGreen: CGFloat = 0.0
          var compositeBlue: CGFloat = 0.0
          // Only perform rgb blending calculations if the output alpha is > 0. A zero-value alpha
          // means none of the color channels actually matter, and would introduce division by 0.
          if abs(compositeAlpha) > CGFloat(Float.ulpOfOne) {
            compositeRed =
              (((1.0 - alphaOverlay) * originalPixelAlpha * originalPixelRed)
                + (alphaOverlay * redOverlay)) / compositeAlpha
            compositeGreen =
              (((1.0 - alphaOverlay) * originalPixelAlpha * originalPixelGreen)
                + (alphaOverlay * greenOverlay)) / compositeAlpha
            compositeBlue =
              (((1.0 - alphaOverlay) * originalPixelAlpha * originalPixelBlue)
                + (alphaOverlay * blueOverlay)) / compositeAlpha
          }

          imageAddress[redOffset] = UInt8(compositeRed * Constants.maxColorComponentValue)
          imageAddress[greenOffset] = UInt8(compositeGreen * Constants.maxColorComponentValue)
          imageAddress[blueOffset] = UInt8(compositeBlue * Constants.maxColorComponentValue)
        }

        imageAddress += imageBytesPerRow / MemoryLayout<UInt8>.size
        maskAddress += maskBytesPerRow / MemoryLayout<Float32>.size
      }

      CVPixelBufferUnlockBaseAddress(imageBuffer, writeFlags)
      CVPixelBufferUnlockBaseAddress(mask.buffer, CVPixelBufferLockFlags.readOnly)
    }

    /// Converts an image buffer to a `UIImage`.
    ///
    /// @param imageBuffer The image buffer which should be converted.
    /// @param orientation The orientation already applied to the image.
    /// @return A new `UIImage` instance.
    public static func createUIImage(
      from imageBuffer: CVImageBuffer,
      orientation: UIImage.Orientation
    ) -> UIImage? {
      let ciImage = CIImage(cvPixelBuffer: imageBuffer)
      let context = CIContext(options: nil)
      guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
      return UIImage(cgImage: cgImage, scale: Constants.originalScale, orientation: orientation)
    }

    /// Converts a `UIImage` to an image buffer.
    ///
    /// @param image The `UIImage` which should be converted.
    /// @return The image buffer. Callers own the returned buffer and are responsible for releasing it
    ///     when it is no longer needed. Additionally, the image orientation will not be accounted for
    ///     in the returned buffer, so callers must keep track of the orientation separately.
    public static func createImageBuffer(from image: UIImage) -> CVImageBuffer? {
      guard let cgImage = image.cgImage else { return nil }
      let width = cgImage.width
      let height = cgImage.height

      var buffer: CVPixelBuffer? = nil
      CVPixelBufferCreate(
        kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil,
        &buffer)
      guard let imageBuffer = buffer else { return nil }

      let flags = CVPixelBufferLockFlags(rawValue: 0)
      CVPixelBufferLockBaseAddress(imageBuffer, flags)
      let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
      let context = CGContext(
        data: baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: bytesPerRow, space: colorSpace,
        bitmapInfo: (CGImageAlphaInfo.premultipliedFirst.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue))

      if let context = context {
        let rect = CGRect.init(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: rect)
        CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
        return imageBuffer
      } else {
        CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
        return nil
      }
    }
    
    private enum Constants {
      static let circleViewAlpha: CGFloat = 0.7
      static let rectangleViewAlpha: CGFloat = 0.3
      static let shapeViewAlpha: CGFloat = 0.3
      static let rectangleViewCornerRadius: CGFloat = 10.0
      static let maxColorComponentValue: CGFloat = 255.0
      static let originalScale: CGFloat = 1.0
      static let bgraBytesPerPixel = 4
    }

}
