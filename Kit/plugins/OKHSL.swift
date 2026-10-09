// ----------------------------------------------------------------------- //
//
// MODULE  : OKHSL.swift
//
// PURPOSE : Conversion between sRGB colors and the OKHSL color space
//
// CREATED : 10/9/2026
//
// ----------------------------------------------------------------------- //
//
// Ported from ok_color.h by Björn Ottosson (MIT licence)
// https://bottosson.github.io/posts/colorpicker/
//
// The sRGB gamut boundary is found the reference way: a polynomial fit refined by one Halley step.
// That is not exact, so a fully saturated color can land slightly off the sRGB edge.

import Cocoa

private struct Vector3
{
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0

    // Returns the dot product with another vector.
    func dot(_ other: Vector3) -> Double
    {
        return self.x * other.x + self.y * other.y + self.z * other.z
    }

    // Returns the component-wise product with another vector.
    func times(_ other: Vector3) -> Vector3
    {
        return Vector3(x: self.x * other.x, y: self.y * other.y, z: self.z * other.z)
    }

    // Returns every component multiplied by a scalar.
    func scaled(_ factor: Double) -> Vector3
    {
        return Vector3(x: self.x * factor, y: self.y * factor, z: self.z * factor)
    }

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3
    {
        return Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
}

// A unit vector in the Oklab a/b plane, i.e. a hue direction.
private struct HueDirection
{
    var a: Double = 1
    var b: Double = 0
}

// A point in Oklab lightness/chroma space.
private struct LightnessChroma
{
    var lightness: Double = 0
    var chroma: Double = 0
}

private struct Oklab
{
    var lightness: Double = 0
    var a: Double = 0
    var b: Double = 0
}

private struct SaturationFit
{
    let k0: Double
    let k1: Double
    let k2: Double
    let k3: Double
    let k4: Double
    let channelWeights: Vector3
}

// The chroma anchors that map OKHSL saturation onto Oklab chroma for one lightness and hue.
private struct ChromaStops
{
    var zero: Double = 0
    var mid: Double = 0
    var max: Double = 0
}

// A hue direction with its gamut cusp.
private struct HueGamut
{
    let direction: HueDirection
    let cusp: LightnessChroma
}

// An LMS' value along a line, with its first and second derivatives.
private struct LMSExpansion
{
    let value: Vector3
    let first: Vector3
    let second: Vector3

    // Expands the cube of `prime + t·direction` at t = 0.
    init(prime: Vector3, direction: Vector3)
    {
        self.value = prime.times(prime).times(prime)
        self.first = direction.times(prime).times(prime).scaled(3)
        self.second = direction.times(direction).times(prime).scaled(6)
    }
}

private let linearRGBToLMSRows: [Vector3] = [
    Vector3(x: 0.4122214708, y: 0.5363325363, z: 0.0514459929),
    Vector3(x: 0.2119034982, y: 0.6806995451, z: 0.1073969566),
    Vector3(x: 0.0883024619, y: 0.2817188376, z: 0.6299787005)
]
private let lmsToOklabRows: [Vector3] = [
    Vector3(x: 0.2104542553, y: 0.7936177850, z: -0.0040720468),
    Vector3(x: 1.9779984951, y: -2.4285922050, z: 0.4505937099),
    Vector3(x: 0.0259040371, y: 0.7827717662, z: -0.8086757660)
]
private let oklabAToLMS: Vector3 = Vector3(x: 0.3963377774, y: -0.1055613458, z: -0.0894841775)
private let oklabBToLMS: Vector3 = Vector3(x: 0.2158037573, y: -0.0638541728, z: -1.2914855480)
private let lmsToLinearRed: Vector3 = Vector3(x: 4.0767416621, y: -3.3077115913, z: 0.2309699292)
private let lmsToLinearGreen: Vector3 = Vector3(x: -1.2684380046, y: 2.6097574011, z: -0.3413193965)
private let lmsToLinearBlue: Vector3 = Vector3(x: -0.0041960863, y: -0.7034186147, z: 1.7076147010)

private let redSaturationFit: SaturationFit = SaturationFit(
    k0: 1.19086277, k1: 1.76576728, k2: 0.59662641, k3: 0.75515197, k4: 0.56771245, channelWeights: lmsToLinearRed
)
private let greenSaturationFit: SaturationFit = SaturationFit(
    k0: 0.73956515, k1: -0.45954404, k2: 0.08285427, k3: 0.12541070, k4: 0.14503204, channelWeights: lmsToLinearGreen
)
private let blueSaturationFit: SaturationFit = SaturationFit(
    k0: 1.35733652, k1: -0.00915799, k2: -1.15130210, k3: -0.50559606, k4: 0.00692167, channelWeights: lmsToLinearBlue
)

private let toeK1: Double = 0.206
private let toeK2: Double = 0.03
private let toeK3: Double = (1 + toeK1) / (1 + toeK2)
private let saturationMid: Double = 0.8
private let saturationMidInverse: Double = 1.25
private let achromaticChroma: Double = 1e-8

private func srgbTransfer(_ value: Double) -> Double
{
    return value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1.0 / 2.4) - 0.055
}

private func srgbTransferInverse(_ value: Double) -> Double
{
    return value > 0.04045 ? pow((value + 0.055) / 1.055, 2.4) : value / 12.92
}

private func linearRGBToOklab(_ rgb: Vector3) -> Oklab
{
    let lms = Vector3(x: linearRGBToLMSRows[0].dot(rgb), y: linearRGBToLMSRows[1].dot(rgb), z: linearRGBToLMSRows[2].dot(rgb))
    let lmsPrime = Vector3(x: cbrt(lms.x), y: cbrt(lms.y), z: cbrt(lms.z))
    return Oklab(lightness: lmsToOklabRows[0].dot(lmsPrime), a: lmsToOklabRows[1].dot(lmsPrime), b: lmsToOklabRows[2].dot(lmsPrime))
}

private func oklabToLinearRGB(_ lab: Oklab) -> Vector3
{
    let lmsPrime = Vector3(
        x: lab.lightness + oklabAToLMS.x * lab.a + oklabBToLMS.x * lab.b,
        y: lab.lightness + oklabAToLMS.y * lab.a + oklabBToLMS.y * lab.b,
        z: lab.lightness + oklabAToLMS.z * lab.a + oklabBToLMS.z * lab.b
    )
    let lms = lmsPrime.times(lmsPrime).times(lmsPrime)
    return Vector3(x: lmsToLinearRed.dot(lms), y: lmsToLinearGreen.dot(lms), z: lmsToLinearBlue.dot(lms))
}

// Returns the LMS' change per unit of chroma along a hue direction.
private func lmsDirection(_ hue: HueDirection) -> Vector3
{
    return oklabAToLMS.scaled(hue.a) + oklabBToLMS.scaled(hue.b)
}

// Returns the polynomial fit for whichever sRGB channel clips first along a hue.
private func saturationFit(_ hue: HueDirection) -> SaturationFit
{
    if -1.88170328 * hue.a - 0.80936493 * hue.b > 1
    {
        return redSaturationFit
    }
    if 1.81444104 * hue.a - 1.19445276 * hue.b > 1
    {
        return greenSaturationFit
    }
    return blueSaturationFit
}

// Computes the largest chroma/lightness ratio that stays inside sRGB along a hue.
private func maxSaturation(_ hue: HueDirection) -> Double
{
    let fit = saturationFit(hue)
    var saturation = fit.k0 + fit.k1 * hue.a + fit.k2 * hue.b + fit.k3 * hue.a * hue.a + fit.k4 * hue.a * hue.b

    let direction = lmsDirection(hue)
    let prime = Vector3(x: 1, y: 1, z: 1) + direction.scaled(saturation)
    let expansion = LMSExpansion(prime: prime, direction: direction)
    let value = fit.channelWeights.dot(expansion.value)
    let first = fit.channelWeights.dot(expansion.first)
    let second = fit.channelWeights.dot(expansion.second)
    saturation -= value * first / (first * first - 0.5 * value * second)

    return saturation
}

// Finds the most saturated in-gamut point along a hue.
private func findCusp(_ hue: HueDirection) -> LightnessChroma
{
    let saturation = maxSaturation(hue)
    let rgb = oklabToLinearRGB(Oklab(lightness: 1, a: saturation * hue.a, b: saturation * hue.b))
    let lightness = cbrt(1 / max(rgb.x, rgb.y, rgb.z))
    return LightnessChroma(lightness: lightness, chroma: lightness * saturation)
}

// Returns the Halley step toward where one sRGB channel reaches 1, or infinity if it moves away.
private func channelStep(_ weights: Vector3, _ expansion: LMSExpansion) -> Double
{
    let value = weights.dot(expansion.value) - 1
    let first = weights.dot(expansion.first)
    let second = weights.dot(expansion.second)
    let factor = first / (first * first - 0.5 * value * second)
    return factor >= 0 ? -value * factor : Double.greatestFiniteMagnitude
}

// Finds the largest in-gamut chroma at a fixed lightness along a hue.
private func maxChroma(_ gamut: HueGamut, lightness: Double) -> Double
{
    let cusp = gamut.cusp
    if lightness <= cusp.lightness
    {
        return cusp.chroma * lightness / cusp.lightness
    }

    var chroma = cusp.chroma * (lightness - 1) / (cusp.lightness - 1)
    let direction = lmsDirection(gamut.direction)
    let prime = Vector3(x: lightness, y: lightness, z: lightness) + direction.scaled(chroma)
    let expansion = LMSExpansion(prime: prime, direction: direction)
    let redStep = channelStep(lmsToLinearRed, expansion)
    let greenStep = channelStep(lmsToLinearGreen, expansion)
    let blueStep = channelStep(lmsToLinearBlue, expansion)
    chroma += min(redStep, greenStep, blueStep)
    return chroma
}

// Returns the cusp's chroma/lightness slopes toward black (S) and toward white (T).
private func cuspSlopes(_ cusp: LightnessChroma) -> (toBlack: Double, toWhite: Double)
{
    return (toBlack: cusp.chroma / cusp.lightness, toWhite: cusp.chroma / (1 - cusp.lightness))
}

// Returns the fitted mid-saturation slopes toward black and toward white for a hue.
private func midSlopes(_ hue: HueDirection) -> (toBlack: Double, toWhite: Double)
{
    let a = hue.a
    let b = hue.b
    let toBlack = 0.11516993 + 1.0 / (
        7.44778970 + 4.15901240 * b
        + a * (-2.19557347 + 1.75198401 * b
            + a * (-2.13704948 - 10.02301043 * b
                + a * (-4.24894561 + 5.38770819 * b + 4.69891013 * a))))
    let toWhite = 0.11239642 + 1.0 / (
        1.61320320 - 0.68124379 * b
        + a * (0.40370612 + 0.90148123 * b
            + a * (-0.27087943 + 0.61223990 * b
                + a * (0.00299215 - 0.45399568 * b - 0.14661872 * a))))
    return (toBlack: toBlack, toWhite: toWhite)
}

// Computes the chroma anchors for one Oklab lightness and hue.
private func chromaStops(_ hue: HueDirection, lightness: Double) -> ChromaStops
{
    let cusp = findCusp(hue)
    let chromaMax = maxChroma(HueGamut(direction: hue, cusp: cusp), lightness: lightness)
    let maxSlopes = cuspSlopes(cusp)
    let scale = chromaMax / min(lightness * maxSlopes.toBlack, (1 - lightness) * maxSlopes.toWhite)

    let mid = midSlopes(hue)
    let midA = lightness * mid.toBlack
    let midB = (1 - lightness) * mid.toWhite
    let chromaMid = 0.9 * scale * pow(1 / (1 / pow(midA, 4) + 1 / pow(midB, 4)), 0.25)

    let zeroA = lightness * 0.4
    let zeroB = (1 - lightness) * 0.8
    let chromaZero = (1 / (1 / (zeroA * zeroA) + 1 / (zeroB * zeroB))).squareRoot()

    return ChromaStops(zero: chromaZero, mid: chromaMid, max: chromaMax)
}

private func toe(_ x: Double) -> Double
{
    let shifted = toeK3 * x - toeK1
    return 0.5 * (shifted + (shifted * shifted + 4 * toeK2 * toeK3 * x).squareRoot())
}

private func toeInverse(_ x: Double) -> Double
{
    return (x * x + toeK1 * x) / (toeK3 * (x + toeK2))
}

// Maps Oklab chroma to OKHSL saturation.
private func okhslSaturation(chroma: Double, stops: ChromaStops) -> Double
{
    if chroma < stops.mid
    {
        let k1 = saturationMid * stops.zero
        let k2 = 1 - k1 / stops.mid
        return chroma / (k1 + k2 * chroma) * saturationMid
    }
    let k1 = (1 - saturationMid) * stops.mid * stops.mid * saturationMidInverse * saturationMidInverse / stops.zero
    let k2 = 1 - k1 / (stops.max - stops.mid)
    let t = (chroma - stops.mid) / (k1 + k2 * (chroma - stops.mid))
    return saturationMid + (1 - saturationMid) * t
}

// Maps OKHSL saturation to Oklab chroma.
private func oklabChroma(saturation: Double, stops: ChromaStops) -> Double
{
    if saturation < saturationMid
    {
        let t = saturationMidInverse * saturation
        let k1 = saturationMid * stops.zero
        let k2 = 1 - k1 / stops.mid
        return t * k1 / (1 - k2 * t)
    }
    let t = (saturation - saturationMid) / (1 - saturationMid)
    let k1 = (1 - saturationMid) * stops.mid * stops.mid * saturationMidInverse * saturationMidInverse / stops.zero
    let k2 = 1 - k1 / (stops.max - stops.mid)
    return stops.mid + t * k1 / (1 - k2 * t)
}

private func clampUnit(_ value: Double) -> CGFloat
{
    return CGFloat(min(max(value, 0), 1))
}

// A color in OKHSL, with every component in 0–1.
public struct OKHSL
{
    public var hue: Double = 0
    public var saturation: Double = 0
    public var lightness: Double = 0

    public init(hue: Double, saturation: Double, lightness: Double)
    {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }

    // Converts a color's sRGB components to OKHSL, ignoring alpha.
    public init(_ color: NSColor)
    {
        let srgb = color.usingColorSpace(.sRGB) ?? NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let linear = Vector3(
            x: srgbTransferInverse(Double(srgb.redComponent)),
            y: srgbTransferInverse(Double(srgb.greenComponent)),
            z: srgbTransferInverse(Double(srgb.blueComponent))
        )
        let lab = linearRGBToOklab(linear)
        let labChroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        var direction = HueDirection()
        if labChroma > achromaticChroma
        {
            direction = HueDirection(a: lab.a / labChroma, b: lab.b / labChroma)
        }

        self.hue = 0.5 + 0.5 * atan2(-lab.b, -lab.a) / Double.pi
        self.lightness = toe(lab.lightness)
        // Black and white have no chroma range to measure saturation against.
        if lab.lightness > 0 && lab.lightness < 1
        {
            self.saturation = okhslSaturation(chroma: labChroma, stops: chromaStops(direction, lightness: lab.lightness))
        }
    }

    // Returns the opaque sRGB color, clamped to the sRGB gamut.
    public var color: NSColor
    {
        if self.lightness >= 1
        {
            return NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        }
        if self.lightness <= 0
        {
            return NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        }

        let direction = HueDirection(a: cos(2 * Double.pi * self.hue), b: sin(2 * Double.pi * self.hue))
        let labLightness = toeInverse(self.lightness)
        let labChroma = oklabChroma(saturation: self.saturation, stops: chromaStops(direction, lightness: labLightness))
        let linear = oklabToLinearRGB(Oklab(lightness: labLightness, a: labChroma * direction.a, b: labChroma * direction.b))
        return NSColor(
            srgbRed: clampUnit(srgbTransfer(linear.x)),
            green: clampUnit(srgbTransfer(linear.y)),
            blue: clampUnit(srgbTransfer(linear.z)),
            alpha: 1
        )
    }
}
