import Foundation

/// Настройки эквалайзера: 10 полос (классическая раскладка 60 Гц … 16 кГц)
/// плюс общий уровень. Значения — в децибелах.
public struct EQSettings: Codable, Equatable {
    public static let frequencies: [Float] = [60, 170, 310, 600, 1_000, 3_000, 6_000, 12_000, 14_000, 16_000]
    public static let frequencyLabels = ["60", "170", "310", "600", "1k", "3k", "6k", "12k", "14k", "16k"]
    public static let bandCount = frequencies.count
    public static let range: ClosedRange<Float> = -12...12
    /// Добротность полос: компромисс между «слышно эффект» и «нет гребёнки».
    public static let q: Float = 1.41
    public static let flatGains = [Float](repeating: 0, count: bandCount)

    public var enabled: Bool
    public var preamp: Float
    public var gains: [Float]

    public init(enabled: Bool = false, preamp: Float = 0, gains: [Float] = EQSettings.flatGains) {
        self.enabled = enabled
        self.preamp = Self.clamp(preamp)
        self.gains = Self.normalize(gains)
    }

    private enum CodingKeys: String, CodingKey { case enabled, preamp, gains }

    // Ручной декодер: чужие/старые данные не должны ломать приложение
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) as? Bool ?? false,
            preamp: (try? c.decodeIfPresent(Float.self, forKey: .preamp)) as? Float ?? 0,
            gains: (try? c.decodeIfPresent([Float].self, forKey: .gains)) as? [Float] ?? Self.flatGains
        )
    }

    public var isFlat: Bool {
        abs(preamp) < 0.01 && gains.allSatisfy { abs($0) < 0.01 }
    }

    public static func clamp(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, range.lowerBound), range.upperBound)
    }

    /// Приводит набор полос к нужной длине и диапазону.
    public static func normalize(_ gains: [Float]) -> [Float] {
        var result = gains.prefix(bandCount).map(clamp)
        if result.count < bandCount {
            result.append(contentsOf: [Float](repeating: 0, count: bandCount - result.count))
        }
        return result
    }

    /// Децибелы → линейный множитель.
    public static func linearGain(fromDB db: Float) -> Float {
        pow(10, clamp(db) / 20)
    }
}

// MARK: - Пресеты

public struct EQPreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let gains: [Float]

    public init(id: String, name: String, gains: [Float]) {
        self.id = id
        self.name = name
        self.gains = EQSettings.normalize(gains)
    }
}

public extension EQSettings {
    static let customPresetID = "custom"

    static let presets: [EQPreset] = [
        EQPreset(id: "flat", name: "По умолчанию", gains: flatGains),
        EQPreset(id: "bass", name: "Больше баса", gains: [7, 6, 4, 1, 0, 0, 0, 0, 0, 0]),
        EQPreset(id: "less-bass", name: "Меньше баса", gains: [-7, -6, -4, -1, 0, 0, 0, 0, 0, 0]),
        EQPreset(id: "voice", name: "Голос и подкасты", gains: [-4, -3, 0, 3, 5, 4, 2, 0, -1, -2]),
        EQPreset(id: "treble", name: "Больше высоких", gains: [0, 0, 0, 0, 0, 1, 3, 5, 6, 6]),
        EQPreset(id: "night", name: "Ночной режим", gains: [-8, -6, -3, 0, 2, 2, 0, -2, -3, -4]),
        EQPreset(id: "rock", name: "Рок", gains: [5, 4, 2, -1, -2, 0, 3, 4, 4, 4]),
        EQPreset(id: "electronic", name: "Электроника", gains: [6, 5, 1, 0, -2, 1, 2, 4, 5, 5]),
    ]

    /// id пресета, совпадающего с набором полос, иначе nil (значит «свой»).
    static func presetID(matching gains: [Float]) -> String? {
        let normalized = normalize(gains)
        return presets.first { preset in
            zip(preset.gains, normalized).allSatisfy { abs($0 - $1) < 0.01 }
        }?.id
    }
}

// MARK: - Коэффициенты биквад-фильтра

/// Коэффициенты биквада в форме прямой реализации I:
/// y = b0·x + b1·x₋₁ + b2·x₋₂ − a1·y₋₁ − a2·y₋₂
public struct BiquadCoefficients: Equatable {
    public var b0: Float
    public var b1: Float
    public var b2: Float
    public var a1: Float
    public var a2: Float

    public init(b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }

    /// Пропускает сигнал без изменений.
    public static let identity = BiquadCoefficients(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)

    /// Колоколообразный фильтр (peaking EQ) по формулам RBJ Audio Cookbook.
    public static func peaking(frequency: Float, gainDB: Float, q: Float, sampleRate: Float) -> BiquadCoefficients {
        guard sampleRate > 0, frequency > 0, frequency < sampleRate / 2, q > 0, abs(gainDB) >= 0.01 else {
            return .identity
        }
        let a = pow(10, gainDB / 40)
        let omega = 2 * Float.pi * frequency / sampleRate
        let alpha = sin(omega) / (2 * q)
        let cosOmega = cos(omega)
        let a0 = 1 + alpha / a
        guard a0 != 0, a0.isFinite else { return .identity }
        return BiquadCoefficients(
            b0: (1 + alpha * a) / a0,
            b1: (-2 * cosOmega) / a0,
            b2: (1 - alpha * a) / a0,
            a1: (-2 * cosOmega) / a0,
            a2: (1 - alpha / a) / a0
        )
    }

    /// Модуль передаточной функции на частоте — для тестов и проверок.
    public func magnitude(at frequency: Float, sampleRate: Float) -> Float {
        let omega = Double(2 * Float.pi * frequency / sampleRate)
        let (cos1, sin1) = (cos(omega), sin(omega))
        let (cos2, sin2) = (cos(2 * omega), sin(2 * omega))
        let numeratorReal = Double(b0) + Double(b1) * cos1 + Double(b2) * cos2
        let numeratorImag = -(Double(b1) * sin1 + Double(b2) * sin2)
        let denominatorReal = 1 + Double(a1) * cos1 + Double(a2) * cos2
        let denominatorImag = -(Double(a1) * sin1 + Double(a2) * sin2)
        let numerator = (numeratorReal * numeratorReal + numeratorImag * numeratorImag).squareRoot()
        let denominator = (denominatorReal * denominatorReal + denominatorImag * denominatorImag).squareRoot()
        guard denominator > 0 else { return 0 }
        return Float(numerator / denominator)
    }
}

// MARK: - Какой эквалайзер действует

public enum EQActivation: Equatable {
    case off      // никакой
    case global   // общий
    case own      // свой у приложения
}

public enum EQResolution {
    /// Свой эквалайзер приложения перебивает общий; иначе действует общий (если включён).
    public static func effective(app: EQSettings, global: EQSettings) -> EQSettings? {
        if app.enabled { return app }
        if global.enabled { return global }
        return nil
    }

    public static func activation(app: EQSettings, global: EQSettings) -> EQActivation {
        if app.enabled { return .own }
        return global.enabled ? .global : .off
    }
}
