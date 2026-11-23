import Foundation

/// Checks on a Windows program's PE header.
enum Executable {
    /// A 32-bit Windows program (machine type i386).
    static func isWindows32(_ url: URL) throws -> Bool {
        let head = try FileHandle(forReadingFrom: url).readHeader(4096)
        guard head.count > 0x40, head.starts(with: [0x4D, 0x5A]) else { return false }
        let pe = Int(head.u32(0x3C))
        guard pe + 6 <= head.count, head[pe..<pe + 4].elementsEqual([0x50, 0x45, 0, 0]) else { return false }
        return head.u16(pe + 4) == 0x14C
    }

    /// True when the program still carries disc copy protection that CrossOver can't run.
    /// SafeDisc adds sections named stxt…; SecuROM adds .securom.
    static func isCopyProtected(_ url: URL) throws -> Bool {
        let head = try FileHandle(forReadingFrom: url).readHeader(8192)
        guard head.count > 0x40, head.starts(with: [0x4D, 0x5A]) else { return false }
        let pe = Int(head.u32(0x3C))
        guard pe + 24 <= head.count else { return false }
        let sections = Int(head.u16(pe + 6)), optional = Int(head.u16(pe + 20))
        let table = pe + 24 + optional
        for i in 0..<sections {
            let start = table + i * 40
            guard start + 8 <= head.count else { break }
            let name = String(decoding: head[start..<start + 8].prefix { $0 != 0 }, as: UTF8.self).lowercased()
            if name.hasPrefix("stxt") || name.contains("securom") { return true }
        }
        return false
    }
}

private extension FileHandle {
    func readHeader(_ count: Int) throws -> Data {
        defer { try? close() }
        return try read(upToCount: count) ?? Data()
    }
}

private extension Data {
    func u16(_ offset: Int) -> UInt16 { UInt16(self[startIndex + offset]) | UInt16(self[startIndex + offset + 1]) << 8 }
    func u32(_ offset: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(self[startIndex + offset + $1]) << (8 * $1) } }
}
