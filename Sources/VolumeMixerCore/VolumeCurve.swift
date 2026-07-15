import Foundation

public enum VolumeCurve {
    /// Позиция ползунка 0…1 → линейный коэффициент усиления 0…1.
    /// Квадратичная кривая: середина ползунка ощущается как «вдвое тише».
    public static func gain(fromSlider position: Float) -> Float {
        let p = min(max(position, 0), 1)
        return p * p
    }

    public static func slider(fromGain gain: Float) -> Float {
        let g = min(max(gain, 0), 1)
        return sqrt(g)
    }
}
