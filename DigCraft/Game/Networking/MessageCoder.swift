import Foundation

enum MessageCoder {
    /// Encode a NetMessage with 4-byte big-endian length prefix + JSON payload
    static func encode(_ message: NetMessage) -> Data {
        let payload = try! JSONEncoder().encode(message)
        var length = UInt32(payload.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(payload)
        return frame
    }

    /// Decode a NetMessage from a buffer. Returns (message, bytesConsumed) or nil if incomplete.
    static func decode(from buffer: Data) -> (NetMessage, Int)? {
        guard buffer.count >= 4 else { return nil }

        let length = buffer.withUnsafeBytes { ptr -> UInt32 in
            ptr.load(as: UInt32.self).bigEndian
        }
        let frameSize = 4 + Int(length)
        guard buffer.count >= frameSize else { return nil }

        let payload = buffer.subdata(in: 4..<frameSize)
        guard let message = try? JSONDecoder().decode(NetMessage.self, from: payload) else {
            return nil
        }
        return (message, frameSize)
    }

    /// Decode all complete messages from a buffer, returning messages and remaining bytes
    static func decodeAll(from buffer: inout Data) -> [NetMessage] {
        var messages: [NetMessage] = []
        while let (message, consumed) = decode(from: buffer) {
            messages.append(message)
            buffer = buffer.subdata(in: consumed..<buffer.count)
        }
        return messages
    }
}
