// Minimal SwiftData model for Tune
import Foundation
import SwiftData

@Model
class Tune: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var composer: String?

    init(id: UUID = UUID(), title: String, composer: String? = nil) {
        self.id = id
        self.title = title
        self.composer = composer
    }
}
