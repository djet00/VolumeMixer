import Testing
@testable import VolumeMixerCore

@Suite struct VolumeCurveTests {
    @Test func extremes() {
        #expect(VolumeCurve.gain(fromSlider: 0) == 0)
        #expect(VolumeCurve.gain(fromSlider: 1) == 1)
    }
    @Test func perceptualSquare() {
        #expect(abs(VolumeCurve.gain(fromSlider: 0.5) - 0.25) < 0.0001)
    }
    @Test func clamping() {
        #expect(VolumeCurve.gain(fromSlider: -1) == 0)
        #expect(VolumeCurve.gain(fromSlider: 2) == 1)
    }
    @Test func roundtrip() {
        for p: Float in [0, 0.1, 0.33, 0.5, 0.77, 1] {
            #expect(abs(VolumeCurve.slider(fromGain: VolumeCurve.gain(fromSlider: p)) - p) < 0.0001)
        }
    }
}
