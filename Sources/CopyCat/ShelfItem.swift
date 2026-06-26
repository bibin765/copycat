import Foundation

/// A single thing parked on the shelf. Everything is backed by a file on disk
/// so it can be dragged back out as a real file, and survives app restarts.
struct ShelfItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
        case file
        case link
    }

    let id: UUID
    var kind: Kind
    /// Display label shown under the card.
    var name: String
    /// Inline text for `.text` / `.link` items.
    var text: String?
    /// Filename (relative to the store's files directory) for `.image` / `.file`.
    var fileName: String?
    var createdAt: Date

    init(id: UUID = UUID(),
         kind: Kind,
         name: String,
         text: String? = nil,
         fileName: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.name = name
        self.text = text
        self.fileName = fileName
        self.createdAt = createdAt
    }
}
