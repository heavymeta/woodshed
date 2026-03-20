// Minimal singleton AudioService for environment injection
import Foundation
import SwiftUI

final class AudioService: ObservableObject {
    static let shared = AudioService()
    private init() {}
    // Stub methods and properties can be expanded as needed
}
