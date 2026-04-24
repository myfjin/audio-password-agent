import Foundation

// MARK: - Types

enum CarrierStyle: String, CaseIterable {
    case rainyWindow    = "rainy_window"
    case morningCoffee  = "morning_coffee"
    case cityLights     = "city_lights"
    case deepSpace      = "deep_space"
    case forestPath     = "forest_path"
    case electricDreams = "electric_dreams"
    case midnightDrive  = "midnight_drive"
    case oceanBreeze    = "ocean_breeze"

    var displayName: String {
        switch self {
        case .rainyWindow:    return "Rainy Window"
        case .morningCoffee:  return "Morning Coffee"
        case .cityLights:     return "City Lights"
        case .deepSpace:      return "Deep Space"
        case .forestPath:     return "Forest Path"
        case .electricDreams: return "Electric Dreams"
        case .midnightDrive:  return "Midnight Drive"
        case .oceanBreeze:    return "Ocean Breeze"
        }
    }

    var icon: String {
        switch self {
        case .rainyWindow:    return "cloud.rain"
        case .morningCoffee:  return "cup.and.saucer.fill"
        case .cityLights:     return "building.2.fill"
        case .deepSpace:      return "sparkles"
        case .forestPath:     return "leaf.fill"
        case .electricDreams: return "bolt.fill"
        case .midnightDrive:  return "car.fill"
        case .oceanBreeze:    return "water.waves"
        }
    }
}

enum CarrierSelection {
    case autoGenerate
    case builtIn(CarrierStyle)
    case custom(URL)

    var displayName: String {
        switch self {
        case .autoGenerate:      return "Auto-generate"
        case .builtIn(let s):    return s.displayName
        case .custom(let url):   return url.lastPathComponent
        }
    }
}

// MARK: - Library

enum CarrierLibrary {
    static let sampleRate: Int32 = 44100
    static let durationSeconds   = 10
    static var totalSamples: Int { Int(sampleRate) * durationSeconds }

    static var carriersDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioPasswordAgent/carriers", isDirectory: true)
    }

    /// Returns cached (or freshly synthesised) WAV URL for a built-in style.
    static func wavURL(for style: CarrierStyle) throws -> URL {
        let dir = carriersDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(style.rawValue).wav")
        if !FileManager.default.fileExists(atPath: url.path) {
            try buildWAV(samples: generate(style: style), sampleRate: sampleRate).write(to: url)
        }
        return url
    }

    /// Unique temp WAV for the "Auto-generate" option (used when saving).
    static func generateRandomWAV() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("carrier_\(UUID().uuidString).wav")
        try buildWAV(samples: whiteNoise(seed: UInt64(Date().timeIntervalSince1970 * 1000)),
                     sampleRate: sampleRate).write(to: url)
        return url
    }

    /// Stable temp WAV for the "Auto-generate" preview button — regenerated once per session.
    static func previewURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("carrier_preview.wav")
        if !FileManager.default.fileExists(atPath: url.path) {
            try buildWAV(samples: whiteNoise(seed: 0xDEADBEEF),
                         sampleRate: sampleRate).write(to: url)
        }
        return url
    }

    // MARK: - WAV builder

    static func buildWAV(samples: [Int16], sampleRate: Int32) -> Data {
        let dataBytes = samples.count * 2
        var d = Data(capacity: 44 + dataBytes)

        func tag(_ s: StaticString) {
            s.withUTF8Buffer { d.append(contentsOf: $0) }
        }
        func u16(_ v: UInt16) { d.append(contentsOf: [UInt8(v & 0xFF), UInt8(v >> 8)]) }
        func u32(_ v: UInt32) {
            d.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
                                  UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
        }

        tag("RIFF"); u32(UInt32(36 + dataBytes))
        tag("WAVE")
        tag("fmt "); u32(16); u16(1); u16(1)          // PCM, mono
        u32(UInt32(sampleRate))                         // sample rate
        u32(UInt32(sampleRate) * 2)                     // byte rate
        u16(2); u16(16)                                 // block align, bits
        tag("data"); u32(UInt32(dataBytes))

        for s in samples {
            d.append(UInt8(bitPattern: Int8(truncatingIfNeeded: s)))
            d.append(UInt8(bitPattern: Int8(truncatingIfNeeded: s >> 8)))
        }
        return d
    }

    // MARK: - Dispatch

    private static func generate(style: CarrierStyle) -> [Int16] {
        let seed = style.rawValue.utf8.reduce(UInt64(0xC0FFEE)) { $0 &+ UInt64($1) }
        switch style {
        case .rainyWindow:    return rain(seed: seed)
        case .morningCoffee:  return brownNoise(seed: seed)
        case .cityLights:     return pinkNoise(seed: seed)
        case .deepSpace:      return deepSpace(seed: seed)
        case .forestPath:     return greenNoise(seed: seed)
        case .electricDreams: return electric(seed: seed)
        case .midnightDrive:  return rumble(seed: seed)
        case .oceanBreeze:    return ocean(seed: seed)
        }
    }

    // MARK: - PRNG (splitmix64 — fast, zero-alloc)

    private static func next(_ s: inout UInt64) -> Double {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z) / Double(UInt64.max)  // [0, 1)
    }

    private static func sample(_ v: Double) -> Int16 {
        Int16(max(-1.0, min(1.0, v)) * Double(Int16.max))
    }

    // MARK: - Synthesis

    private static func whiteNoise(seed: UInt64) -> [Int16] {
        var rng = seed
        return (0..<totalSamples).map { _ in sample((next(&rng) - 0.5) * 2) }
    }

    private static func brownNoise(seed: UInt64) -> [Int16] {
        var rng = seed, acc = 0.0
        return (0..<totalSamples).map { _ in
            acc = max(-1.0, min(1.0, acc + (next(&rng) - 0.5) * 0.02))
            return sample(acc)
        }
    }

    // Voss-McCartney pink noise approximation
    private static func pinkNoise(seed: UInt64) -> [Int16] {
        var rng = seed
        var b = [Double](repeating: 0, count: 7)
        return (0..<totalSamples).map { _ in
            let w = next(&rng) * 2 - 1
            b[0] = 0.99886*b[0] + w*0.0555179
            b[1] = 0.99332*b[1] + w*0.0750759
            b[2] = 0.96900*b[2] + w*0.1538520
            b[3] = 0.86650*b[3] + w*0.3104856
            b[4] = 0.55000*b[4] + w*0.5329522
            b[5] = -0.7616*b[5] - w*0.0168980
            let pink = (b[0]+b[1]+b[2]+b[3]+b[4]+b[5]+b[6] + w*0.5362) / 7.0
            b[6] = w * 0.115926
            return sample(pink)
        }
    }

    private static func rain(seed: UInt64) -> [Int16] {
        var rng = seed, acc = 0.0
        return (0..<totalSamples).map { _ in
            acc = max(-0.8, min(0.8, acc + (next(&rng) - 0.5) * 0.04))
            let grain = (next(&rng) - 0.5) * 0.3
            return sample(acc + grain)
        }
    }

    private static func deepSpace(seed: UInt64) -> [Int16] {
        var rng = seed, acc = 0.0
        return (0..<totalSamples).map { _ in
            acc = max(-0.05, min(0.05, acc + (next(&rng) - 0.5) * 0.001))
            return sample(acc + (next(&rng) - 0.5) * 0.01)
        }
    }

    // Pink noise with a high-pass: removes very low freqs, gives "forest" feel
    private static func greenNoise(seed: UInt64) -> [Int16] {
        var rng = seed
        var b = [Double](repeating: 0, count: 7)
        var hp = 0.0, prev = 0.0
        return (0..<totalSamples).map { _ in
            let w = next(&rng) * 2 - 1
            b[0] = 0.99886*b[0] + w*0.0555179
            b[1] = 0.99332*b[1] + w*0.0750759
            b[2] = 0.96900*b[2] + w*0.1538520
            b[3] = 0.86650*b[3] + w*0.3104856
            b[4] = 0.55000*b[4] + w*0.5329522
            b[5] = -0.7616*b[5] - w*0.0168980
            let pink = (b[0]+b[1]+b[2]+b[3]+b[4]+b[5]+b[6] + w*0.5362) / 7.0
            b[6] = w * 0.115926
            hp = 0.97 * (hp + pink - prev); prev = pink
            return sample(hp * 1.5)
        }
    }

    private static func electric(seed: UInt64) -> [Int16] {
        var rng = seed
        var phase = 0.0
        let inc = 2 * Double.pi * 60.0 / Double(sampleRate)
        return (0..<totalSamples).map { _ in
            phase += inc; if phase > 2 * .pi { phase -= 2 * .pi }
            return sample(sin(phase) * 0.15 + (next(&rng) - 0.5) * 0.5)
        }
    }

    private static func rumble(seed: UInt64) -> [Int16] {
        var rng = seed, acc = 0.0, phase = 0.0
        let inc = 2 * Double.pi * 40.0 / Double(sampleRate)
        return (0..<totalSamples).map { _ in
            phase += inc; if phase > 2 * .pi { phase -= 2 * .pi }
            acc = max(-0.6, min(0.6, acc + (next(&rng) - 0.5) * 0.015))
            return sample(sin(phase) * 0.4 + acc)
        }
    }

    private static func ocean(seed: UInt64) -> [Int16] {
        var rng = seed, acc = 0.0, modPhase = 0.0
        let modInc = 2 * Double.pi * 0.2 / Double(sampleRate)
        return (0..<totalSamples).map { _ in
            modPhase += modInc; if modPhase > 2 * .pi { modPhase -= 2 * .pi }
            let env = (sin(modPhase) + 1) * 0.4 + 0.2
            acc = max(-0.8, min(0.8, acc + (next(&rng) - 0.5) * 0.03))
            let grain = (next(&rng) - 0.5) * 0.3
            return sample((acc + grain) * env)
        }
    }
}
