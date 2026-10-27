import SwiftUI
import SceneKit
import AppKit

/// A19 style smart bulb: glowing dome on a frosted white body, rose gold band,
/// ridged E27 screw base and a black contact tip.
public struct Bulb3DView: NSViewRepresentable {
    let isOn: Bool
    let color: NSColor
    let brightness: Double
    let visualChangeToken: UInt
    let bulbLabel: String

    public init(isOn: Bool, color: NSColor, brightness: Double, visualChangeToken: UInt = 0, bulbLabel: String = "PHILIPS") {
        self.isOn = isOn
        self.color = color
        self.brightness = brightness
        self.visualChangeToken = visualChangeToken
        self.bulbLabel = bulbLabel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.wantsLayer = true
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false

        let coordinator = context.coordinator
        scnView.scene = coordinator.buildScene()
        scnView.pointOfView = coordinator.cameraNode

        let pan = NSPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(pan)

        coordinator.updateBulbLabel(bulbLabel)
        coordinator.updateState(isOn: isOn, color: color, brightness: brightness, visualChangeToken: visualChangeToken, animated: false)
        return scnView
    }

    public func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.updateBulbLabel(bulbLabel)
        context.coordinator.updateState(isOn: isOn, color: color, brightness: brightness, visualChangeToken: visualChangeToken, animated: true)
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject {
        let cameraNode = SCNNode()

        private let floatNode = SCNNode()
        private let pivotNode = SCNNode()
        private let animNode = SCNNode()

        private let domeMaterial = SCNMaterial()
        private let bodyMaterial = SCNMaterial()
        private var logoNode: SCNNode?
        private var currentBulbLabel = ""
        private let innerLight = SCNLight()

        private var angleX: Float = 0
        private var angleY: Float = 0
        private var interactionToken = 0
        private var lastIsOn: Bool?
        private var lastInputColor = SIMD3<Float>(-1, -1, -1)
        private var lastBrightness: Float = -1
        private var lastVisualChangeToken: UInt = 0

        // Animated visual state
        private let offDomeColor = SIMD3<Float>(0.80, 0.82, 0.86)
        private var domeColor = SIMD3<Float>(0.80, 0.82, 0.86)
        private var glow: Float = 0
        private var tint = SIMD3<Float>(1.0, 0.85, 0.6)

        // MARK: Scene

        func buildScene() -> SCNScene {
            let scene = SCNScene()
            scene.lightingEnvironment.contents = Coordinator.makeEnvironment()
            scene.lightingEnvironment.intensity = 1.1

            scene.rootNode.addChildNode(animNode)

            // Node hierarchy: response motion -> pivot (user drag) -> bulb
            scene.rootNode.addChildNode(floatNode)
            floatNode.addChildNode(pivotNode)
            buildBulb(in: pivotNode)

            // Camera
            let camera = SCNCamera()
            camera.fieldOfView = 28
            camera.zNear = 0.1
            camera.zFar = 50
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, -0.2, 7.2)
            scene.rootNode.addChildNode(cameraNode)

            // Lights
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = NSColor(white: 1.0, alpha: 1.0)
            ambient.light?.intensity = 200
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.color = NSColor(white: 1.0, alpha: 1.0)
            key.light?.intensity = 800
            key.eulerAngles = SCNVector3(-0.6, 0.6, 0)
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .directional
            fill.light?.color = NSColor(white: 0.8, alpha: 1.0)
            fill.light?.intensity = 350
            fill.eulerAngles = SCNVector3(-0.2, -0.9, 0)
            scene.rootNode.addChildNode(fill)

            apply()
            return scene
        }

        func updateBulbLabel(_ label: String) {
            let trimmed = String(label.prefix(18)).trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == currentBulbLabel && (trimmed.isEmpty ? logoNode == nil : logoNode != nil) { return }
            currentBulbLabel = trimmed
            guard !trimmed.isEmpty else {
                logoNode?.removeFromParentNode()
                logoNode = nil
                return
            }

            let logo = SCNText(string: trimmed, extrusionDepth: 0.004)
            logo.font = NSFont(name: "Philips Sans", size: 0.15)
                ?? NSFont.systemFont(ofSize: 0.15, weight: .bold)
            logo.flatness = 0.005
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = NSColor(white: 0.27, alpha: 1)
            material.emission.contents = NSColor(white: 0.27, alpha: 1)
            material.isDoubleSided = true
            logo.materials = [material]

            if logoNode == nil {
                logoNode = SCNNode()
                pivotNode.addChildNode(logoNode!)
            }
            logoNode?.geometry = logo
            let (minBound, maxBound) = logo.boundingBox
            let width = maxBound.x - minBound.x
            let scale: CGFloat = min(1, 0.90 / max(width, 0.001))
            logoNode?.scale = SCNVector3(scale, scale, scale)
            logoNode?.position = SCNVector3(-width * scale / 2, -0.30, 0.735)
        }

        private func buildBulb(in root: SCNNode) {
            let domeCenterY: CGFloat = 0.55
            let domeRadius: CGFloat = 0.80
            let seamY: CGFloat = 0.20

            // 1. Glowing dome (spherical cap, profile listed top to bottom)
            let phiMax = acos((seamY - domeCenterY) / domeRadius)
            let domeSteps = 48
            var domeProfile: [CGPoint] = []
            for i in 0...domeSteps {
                let phi = phiMax * CGFloat(i) / CGFloat(domeSteps)
                domeProfile.append(CGPoint(x: domeRadius * sin(phi),
                                           y: domeCenterY + domeRadius * cos(phi)))
            }
            domeMaterial.lightingModel = .constant
            domeMaterial.shaderModifiers = [.fragment: Coordinator.domeShader]
            domeMaterial.setValue(NSValue(scnVector3: SCNVector3(0.8, 0.82, 0.86)), forKey: "glowColor")
            domeMaterial.setValue(NSNumber(value: Float(0)), forKey: "glowAmount")
            let domeGeo = Coordinator.lathe(domeProfile)
            domeGeo.materials = [domeMaterial]
            let domeNode = SCNNode(geometry: domeGeo)
            domeNode.name = "dome"
            root.addChildNode(domeNode)

            // 2. Frosted white body with a smooth taper into the base
            let bodyControl: [CGPoint] = [
                CGPoint(x: 0.719, y: 0.20),
                CGPoint(x: 0.736, y: 0.02),
                CGPoint(x: 0.715, y: -0.22),
                CGPoint(x: 0.640, y: -0.48),
                CGPoint(x: 0.530, y: -0.72),
                CGPoint(x: 0.450, y: -0.90),
                CGPoint(x: 0.415, y: -1.04)
            ]
            let bodyProfile = Coordinator.spline(bodyControl, steps: 14)
            bodyMaterial.lightingModel = .physicallyBased
            bodyMaterial.diffuse.contents = NSColor(white: 0.97, alpha: 1.0)
            bodyMaterial.roughness.contents = 0.55
            bodyMaterial.metalness.contents = 0.0
            let bodyGeo = Coordinator.lathe(bodyProfile)
            bodyGeo.materials = [bodyMaterial]
            root.addChildNode(SCNNode(geometry: bodyGeo))

            updateBulbLabel(currentBulbLabel.isEmpty ? "PHILIPS" : currentBulbLabel)

            // 3. Rose gold band that follows the body curve
            var bandProfile: [CGPoint] = []
            let bandTop: CGFloat = -0.50
            let bandBottom: CGFloat = -0.67
            let bandSteps = 18
            for k in 0...bandSteps {
                let u = CGFloat(k) / CGFloat(bandSteps)
                let y = bandTop - (bandTop - bandBottom) * u
                let r = Coordinator.radius(at: y, in: bodyProfile) + 0.003 + 0.008 * sqrt(sin(.pi * u))
                bandProfile.append(CGPoint(x: r, y: y))
            }
            let roseGold = SCNMaterial()
            roseGold.lightingModel = .physicallyBased
            roseGold.diffuse.contents = NSColor(red: 0.86, green: 0.58, blue: 0.50, alpha: 1.0)
            roseGold.metalness.contents = 1.0
            roseGold.roughness.contents = 0.30
            let bandGeo = Coordinator.lathe(bandProfile)
            bandGeo.materials = [roseGold]
            root.addChildNode(SCNNode(geometry: bandGeo))

            // 4. Ridged E27 screw base
            var baseProfile: [CGPoint] = [
                CGPoint(x: 0.410, y: -1.04),
                CGPoint(x: 0.405, y: -1.07),
                CGPoint(x: 0.375, y: -1.09)
            ]
            let threadStart: CGFloat = -1.10
            let threadEnd: CGFloat = -1.56
            let ridges: CGFloat = 5
            let threadSteps = 100
            let sharp: CGFloat = 1.8
            for i in 0...threadSteps {
                let u = CGFloat(i) / CGFloat(threadSteps)
                let y = threadStart + (threadEnd - threadStart) * u
                let center = 0.355 - 0.045 * u
                let wave = tanh(sharp * cos(2 * .pi * ridges * u)) / tanh(sharp)
                baseProfile.append(CGPoint(x: center + 0.022 * wave, y: y))
            }
            baseProfile.append(CGPoint(x: 0.300, y: -1.60))
            baseProfile.append(CGPoint(x: 0.270, y: -1.62))

            let metal = SCNMaterial()
            metal.lightingModel = .physicallyBased
            metal.diffuse.contents = NSColor(white: 0.82, alpha: 1.0)
            metal.metalness.contents = 1.0
            metal.roughness.contents = 0.28
            let baseGeo = Coordinator.lathe(baseProfile)
            baseGeo.materials = [metal]
            root.addChildNode(SCNNode(geometry: baseGeo))

            // 5. Black insulator and contact tip
            let tipProfile: [CGPoint] = [
                CGPoint(x: 0.270, y: -1.62),
                CGPoint(x: 0.240, y: -1.66),
                CGPoint(x: 0.170, y: -1.74),
                CGPoint(x: 0.150, y: -1.78),
                CGPoint(x: 0.0, y: -1.78)
            ]
            let black = SCNMaterial()
            black.lightingModel = .physicallyBased
            black.diffuse.contents = NSColor(white: 0.06, alpha: 1.0)
            black.metalness.contents = 0.0
            black.roughness.contents = 0.45
            let tipGeo = Coordinator.lathe(tipProfile)
            tipGeo.materials = [black]
            root.addChildNode(SCNNode(geometry: tipGeo))

            // 6. Inner light that tints the surroundings
            innerLight.type = .omni
            innerLight.attenuationStartDistance = 0
            innerLight.attenuationEndDistance = 4
            innerLight.intensity = 0
            let lightNode = SCNNode()
            lightNode.light = innerLight
            lightNode.position = SCNVector3(0, 0.55, 0)
            root.addChildNode(lightNode)
        }

        // MARK: Animation and interaction

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                interactionToken += 1
                pivotNode.removeAction(forKey: "recenter")
                angleX = Float(pivotNode.eulerAngles.x)
                angleY = Float(pivotNode.eulerAngles.y)
            case .changed:
                let sensitivity: Float = 0.012
                angleY += Float(translation.x) * sensitivity
                angleX += Float(-translation.y) * sensitivity
                angleX = max(-0.8, min(0.8, angleX))
                pivotNode.eulerAngles = SCNVector3(CGFloat(angleX), CGFloat(angleY), 0)
                gesture.setTranslation(.zero, in: gesture.view)
            case .ended, .cancelled:
                interactionToken += 1
                let token = interactionToken
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self = self, token == self.interactionToken else { return }
                    let back = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.9, usesShortestUnitArc: true)
                    back.timingMode = .easeInEaseOut
                    self.pivotNode.runAction(back, forKey: "recenter")
                }
            default:
                break
            }
        }

        // MARK: State

        func updateState(isOn: Bool, color: NSColor, brightness: Double, visualChangeToken: UInt, animated: Bool) {
            let rgb = Coordinator.rgb(color)
            let level = Float(min(max(brightness, 0), 100) / 100)
            let changed = lastIsOn.map { $0 != isOn } ?? false
                || simd_distance(lastInputColor, rgb) > 0.005
                || abs(lastBrightness - level) > 0.005
                || lastVisualChangeToken != visualChangeToken
            lastIsOn = isOn
            lastInputColor = rgb
            lastBrightness = level
            lastVisualChangeToken = visualChangeToken
            let dim = 0.30 + 0.70 * level

            let targetDome = isOn ? rgb * dim : offDomeColor
            let targetGlow: Float = isOn ? dim : 0
            let targetTint = isOn ? rgb : tint

            animNode.removeAction(forKey: "state")

            if animated && changed {
                floatNode.removeAction(forKey: "response")
                floatNode.position.y = 0
                let up = SCNAction.moveBy(x: 0, y: 0.09, z: 0, duration: 0.16)
                up.timingMode = .easeOut
                let down = SCNAction.moveBy(x: 0, y: -0.09, z: 0, duration: 0.22)
                down.timingMode = .easeInEaseOut
                floatNode.runAction(.sequence([up, down]), forKey: "response")
            }

            if !animated {
                domeColor = targetDome
                glow = targetGlow
                tint = targetTint
                apply()
                return
            }

            let fromDome = domeColor
            let fromGlow = glow
            let fromTint = tint
            let duration: CGFloat = 0.35

            let action = SCNAction.customAction(duration: TimeInterval(duration)) { [weak self] _, elapsed in
                guard let self = self else { return }
                let t = Float(min(elapsed / duration, 1))
                let e = t * t * (3 - 2 * t)
                self.domeColor = fromDome + (targetDome - fromDome) * e
                self.glow = fromGlow + (targetGlow - fromGlow) * e
                self.tint = fromTint + (targetTint - fromTint) * e
                self.apply()
            }
            animNode.runAction(action, forKey: "state")
        }

        private func apply() {
            domeMaterial.setValue(
                NSValue(scnVector3: SCNVector3(CGFloat(domeColor.x), CGFloat(domeColor.y), CGFloat(domeColor.z))),
                forKey: "glowColor")
            domeMaterial.setValue(NSNumber(value: glow), forKey: "glowAmount")

            let tintColor = NSColor(srgbRed: CGFloat(tint.x), green: CGFloat(tint.y), blue: CGFloat(tint.z), alpha: 1.0)
            bodyMaterial.emission.contents = tintColor
            bodyMaterial.emission.intensity = CGFloat(0.12 * glow)

            innerLight.color = tintColor
            innerLight.intensity = CGFloat(500 * glow)

        }

        // MARK: Helpers

        /// Fragment shader for the dome: bright core, soft rim and a glossy highlight.
        private static let domeShader = """
        #pragma arguments
        float3 glowColor;
        float glowAmount;
        #pragma body
        float3 n = normalize(_surface.normal);
        float3 v = normalize(_surface.view);
        float ndv = saturate(dot(n, v));
        float3 lit = glowColor * (0.62 + 0.55 * pow(ndv, 1.2));
        lit = mix(lit, float3(1.0), pow(ndv, 5.0) * 0.28 * glowAmount);
        lit += glowColor * pow(1.0 - ndv, 3.0) * 0.18;
        float hl1 = smoothstep(0.70, 0.95, dot(n, normalize(float3(-0.55, 0.65, 0.55))));
        float hl2 = smoothstep(0.80, 0.98, dot(n, normalize(float3(0.60, 0.30, 0.70))));
        lit += float3(hl1 * 0.35 + hl2 * 0.10);
        _output.color = float4(lit, 1.0);
        """

        static func rgb(_ color: NSColor) -> SIMD3<Float> {
            let c = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) ?? NSColor.white
            return SIMD3<Float>(Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent))
        }

        /// Revolves a profile (x = radius, y = height, listed top to bottom) around the Y axis.
        static func lathe(_ profile: [CGPoint], segments: Int = 96) -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uvs: [CGPoint] = []
            var indices: [Int32] = []

            let count = profile.count
            for i in 0..<count {
                let prev = profile[max(i - 1, 0)]
                let next = profile[min(i + 1, count - 1)]
                let dr = next.x - prev.x
                let dy = next.y - prev.y
                var nr = -dy
                var ny = dr
                let len = hypot(nr, ny)
                if len > 0 { nr /= len; ny /= len }

                for s in 0...segments {
                    let a = 2 * CGFloat.pi * CGFloat(s) / CGFloat(segments)
                    let c = cos(a)
                    let sn = sin(a)
                    vertices.append(SCNVector3(profile[i].x * c, profile[i].y, profile[i].x * sn))
                    normals.append(SCNVector3(nr * c, ny, nr * sn))
                    uvs.append(CGPoint(x: CGFloat(s) / CGFloat(segments),
                                       y: CGFloat(i) / CGFloat(max(count - 1, 1))))
                }
            }

            let stride = segments + 1
            for i in 0..<(count - 1) {
                for s in 0..<segments {
                    let a = Int32(i * stride + s)
                    let b = Int32((i + 1) * stride + s)
                    let c = Int32(i * stride + s + 1)
                    let d = Int32((i + 1) * stride + s + 1)
                    indices.append(contentsOf: [a, c, b, b, c, d])
                }
            }

            let geometry = SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: vertices),
                    SCNGeometrySource(normals: normals),
                    SCNGeometrySource(textureCoordinates: uvs)
                ],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
            )
            return geometry
        }

        private static func cr(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat, _ t: CGFloat) -> CGFloat {
            let t2 = t * t
            let t3 = t2 * t
            let a = 2 * p1
            let b = (-p0 + p2) * t
            let c = (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
            let d = (-p0 + 3 * p1 - 3 * p2 + p3) * t3
            return 0.5 * (a + b + c + d)
        }

        /// Catmull-Rom spline through the control points.
        static func spline(_ pts: [CGPoint], steps: Int) -> [CGPoint] {
            guard pts.count > 1 else { return pts }
            var out: [CGPoint] = []
            for i in 0..<(pts.count - 1) {
                let p0 = pts[max(i - 1, 0)]
                let p1 = pts[i]
                let p2 = pts[i + 1]
                let p3 = pts[min(i + 2, pts.count - 1)]
                for s in 0..<steps {
                    let t = CGFloat(s) / CGFloat(steps)
                    out.append(CGPoint(x: cr(p0.x, p1.x, p2.x, p3.x, t),
                                       y: cr(p0.y, p1.y, p2.y, p3.y, t)))
                }
            }
            out.append(pts[pts.count - 1])
            return out
        }

        static func radius(at y: CGFloat, in pts: [CGPoint]) -> CGFloat {
            for i in 0..<(pts.count - 1) {
                let a = pts[i]
                let b = pts[i + 1]
                if a.y >= y && y >= b.y {
                    let span = a.y - b.y
                    let t = span == 0 ? 0 : (a.y - y) / span
                    return a.x + (b.x - a.x) * t
                }
            }
            return pts.last?.x ?? 0
        }

        /// Simple studio style environment so the metal and plastic have something to reflect.
        static func makeEnvironment() -> NSImage {
            let size = NSSize(width: 1024, height: 512)
            return NSImage(size: size, flipped: false) { rect in
                let gradient = NSGradient(
                    colors: [NSColor(white: 0.10, alpha: 1), NSColor(white: 0.32, alpha: 1), NSColor(white: 0.62, alpha: 1)],
                    atLocations: [0, 0.5, 1],
                    colorSpace: .genericGray)
                gradient?.draw(in: rect, angle: 90)
                NSColor.white.setFill()
                NSBezierPath(rect: NSRect(x: 100, y: 180, width: 140, height: 220)).fill()
                NSBezierPath(rect: NSRect(x: 700, y: 200, width: 160, height: 190)).fill()
                NSBezierPath(rect: NSRect(x: 300, y: 450, width: 400, height: 50)).fill()
                return true
            }
        }

    }
}
