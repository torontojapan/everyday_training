import UIKit

/// Wraps the Objective-C `UIImageWriteToSavedPhotosAlbum` completion selector so
/// the caller gets a Swift closure with a typed error. Without this, the legacy
/// API silently swallows write errors (including permission denial).
///
/// Strong-references itself for the duration of the save by attaching to the
/// returned `Self` from the callback; the closure cleans up the reference.
@MainActor
final class ImageSaver: NSObject {
    private var completion: ((Result<Void, Error>) -> Void)?
    private var retainCycleBreaker: ImageSaver?

    func save(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        self.completion = completion
        self.retainCycleBreaker = self
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(didFinishSaving(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func didFinishSaving(
        _ image: UIImage,
        didFinishSavingWithError error: NSError?,
        contextInfo: UnsafeRawPointer
    ) {
        Task { @MainActor in
            if let error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
            completion = nil
            retainCycleBreaker = nil
        }
    }
}
