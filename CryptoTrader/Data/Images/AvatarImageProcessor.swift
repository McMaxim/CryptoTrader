import Foundation
import ImageIO
import UniformTypeIdentifiers

enum AvatarProcessingError: LocalizedError {
    case unsupportedImage

    var errorDescription: String? { "Не удалось открыть изображение" }
}

/// Уменьшает фото до квадратного JPEG, чтобы не хранить в базе многомегабайтные оригиналы.
/// Работает на ImageIO без UIKit, поэтому безопасно выполняется в фоне.
struct AvatarImageProcessor: AvatarProcessing {
    var side = 512
    var compressionQuality = 0.85

    func prepareAvatar(from imageData: Data) async throws -> Data {
        let side = side
        let quality = compressionQuality
        // Обработка картинки тяжёлая — уводим её с главного потока.
        return try await Task.detached(priority: .userInitiated) {
            try Self.process(imageData, side: side, quality: quality)
        }.value
    }

    private static func process(_ data: Data, side: Int, quality: Double) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw AvatarProcessingError.unsupportedImage
        }
        // Уменьшаем с учётом EXIF-ориентации; длинная сторона с запасом, чтобы после обрезки хватило `side`.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: side * 2,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AvatarProcessingError.unsupportedImage
        }

        // Обрезаем по центру до квадрата.
        let shortSide = min(thumbnail.width, thumbnail.height)
        let cropRect = CGRect(
            x: (thumbnail.width - shortSide) / 2,
            y: (thumbnail.height - shortSide) / 2,
            width: shortSide,
            height: shortSide
        )
        guard let square = thumbnail.cropping(to: cropRect) else {
            throw AvatarProcessingError.unsupportedImage
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw AvatarProcessingError.unsupportedImage
        }
        CGImageDestinationAddImage(
            destination, square,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw AvatarProcessingError.unsupportedImage
        }
        return output as Data
    }
}
