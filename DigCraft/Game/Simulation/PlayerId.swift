import Foundation

struct PlayerId: Hashable, Codable, Sendable, RawRepresentable {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    static let host = PlayerId(rawValue: 0)
}
