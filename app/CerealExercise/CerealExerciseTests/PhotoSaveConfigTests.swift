import UIKit
import XCTest
@testable import CerealExercise

/// Guard against shipping the app without the photo-library permission string
/// the "写真に保存" button needs. Without it, calling
/// `UIImageWriteToSavedPhotosAlbum` crashes on a real device with an Apple
/// privacy-string exception (and is silently ignored on Simulator).
@MainActor
final class PhotoSaveConfigTests: XCTestCase {

    func testInfoPlistDeclaresPhotoLibraryAddUsageDescription() throws {
        let bundle = Bundle(for: type(of: self))
            .bundleURL
            .deletingLastPathComponent()      // .xctest bundle dir
            .appendingPathComponent("CerealExercise.app")

        // When running inside the host app's process, just read Bundle.main.
        // When running as a standalone xctest bundle, fall back to the app
        // bundle path computed above.
        let source: Bundle
        if let mainKey = Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String,
           mainKey == "com.serial.cerealexercise" {
            source = .main
        } else if let appBundle = Bundle(url: bundle) {
            source = appBundle
        } else {
            source = .main
        }

        let value = source.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String
        XCTAssertNotNil(value, "Info.plist must declare NSPhotoLibraryAddUsageDescription or the streak-share Save-to-Photos button will crash the app on iOS devices.")
        XCTAssertFalse(value?.isEmpty ?? true, "NSPhotoLibraryAddUsageDescription cannot be empty — App Store review rejects empty privacy strings.")
    }

    func testImageSaverInitializesWithoutCrash() {
        let saver = ImageSaver()
        XCTAssertNotNil(saver)
        // Cannot meaningfully invoke save() in unit tests (it would touch the
        // real Photos library), but we verify the object's selector wiring
        // compiles by referencing the type itself.
    }
}
