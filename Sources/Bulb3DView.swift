import SwiftUI
import SceneKit
import AppKit

public struct Bulb3DView: NSViewRepresentable {
    let isOn: Bool
    let color: NSColor
    let brightness: Double

    public init(isOn: Bool, color: NSColor, brightness: Double) {
        self.isOn = isOn
        self.color = color
        self.brightness = brightness
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false

        let scene = SCNScene()
        scnView.scene = scene

        // Root Pivot Node for user rotation & idle rotation
        let pivotNode = SCNNode()
        pivotNode.name = "pivotNode"
        scene.rootNode.addChildNode(pivotNode)
        context.coordinator.pivotNode = pivotNode

        // Construct the 3D Bulb
        setupBulb(in: pivotNode, coordinator: context.coordinator)

        // Camera setup
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 38
        cameraNode.position = SCNVector3(x: 0, y: 0.15, z: 4.8)
        scene.rootNode.addChildNode(cameraNode)

        // Environment Lighting for realistic metallic and glass reflections
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.25, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.color = NSColor(white: 0.6, alpha: 1.0)
        rimLight.position = SCNVector3(x: 3, y: 5, z: 3)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)

        // Add Pan Gesture for interactive drag rotation
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)

        // Start idle rotation animation
        context.coordinator.startIdleAnimation()

        // Initial state update
        context.coordinator.updateState(isOn: isOn, color: color, brightness: brightness)

        return scnView
    }

    public func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.updateState(isOn: isOn, color: color, brightness: brightness)
    }

    private func setupBulb(in root: SCNNode, coordinator: Coordinator) {
        let bulbAssembly = SCNNode()
        bulbAssembly.name = "bulbAssembly"
        root.addChildNode(bulbAssembly)

        // 1. Frosted Glass Dome
        let glassGeometry = SCNSphere(radius: 0.78)
        glassGeometry.segmentCount = 64
        let glassMaterial = SCNMaterial()
        glassMaterial.lightingModel = .physicallyBased
        glassMaterial.roughness.contents = 0.25
        glassMaterial.metalness.contents = 0.05
        glassMaterial.specular.contents = NSColor.white
        glassMaterial.fresnelExponent = 1.8
        glassGeometry.materials = [glassMaterial]

        let glassNode = SCNNode(geometry: glassGeometry)
        glassNode.position = SCNVector3(0, 0.58, 0)
        glassNode.scale = SCNVector3(1, 0.92, 1)
        glassNode.name = "glassNode"
        bulbAssembly.addChildNode(glassNode)
        coordinator.glassNode = glassNode

        // 2. Bulb Taper/Neck (connecting globe to base)
        let neckGeometry = SCNCone(topRadius: 0.68, bottomRadius: 0.34, height: 0.92)
        neckGeometry.radialSegmentCount = 48
        let neckMaterial = SCNMaterial()
        neckMaterial.lightingModel = .physicallyBased
        neckMaterial.roughness.contents = 0.28
        neckGeometry.materials = [neckMaterial]

        let neckNode = SCNNode(geometry: neckGeometry)
        neckNode.position = SCNVector3(0, -0.36, 0)
        neckNode.name = "neckNode"
        bulbAssembly.addChildNode(neckNode)
        coordinator.neckNode = neckNode

        // 3. Inner Glowing Filament / Diode Core
        let filamentGeometry = SCNTorus(ringRadius: 0.32, pipeRadius: 0.032)
        filamentGeometry.ringSegmentCount = 48
        filamentGeometry.pipeSegmentCount = 24
        let filamentMat = SCNMaterial()
        filamentMat.lightingModel = .constant
        filamentGeometry.materials = [filamentMat]

        let filamentNode = SCNNode(geometry: filamentGeometry)
        filamentNode.position = SCNVector3(0, 0.58, 0)
        filamentNode.rotation = SCNVector4(1, 0, 0, Float.pi / 2.3)
        filamentNode.name = "filamentNode"
        bulbAssembly.addChildNode(filamentNode)
        coordinator.filamentNode = filamentNode

        // 4. Internal Omni Light
        let innerLightNode = SCNNode()
        innerLightNode.light = SCNLight()
        innerLightNode.light?.type = .omni
        innerLightNode.position = SCNVector3(0, 0.58, 0)
        innerLightNode.name = "innerLight"
        bulbAssembly.addChildNode(innerLightNode)
        coordinator.innerLightNode = innerLightNode

        // 5. Metallic Screw Base (E27 Collar)
        let baseHeight: CGFloat = 0.55
        let baseGeometry = SCNCylinder(radius: 0.36, height: baseHeight)
        baseGeometry.radialSegmentCount = 48
        let metalMaterial = SCNMaterial()
        metalMaterial.lightingModel = .physicallyBased
        metalMaterial.metalness.contents = 0.92
        metalMaterial.roughness.contents = 0.22
        metalMaterial.diffuse.contents = NSColor(white: 0.75, alpha: 1.0)
        baseGeometry.materials = [metalMaterial]

        let baseNode = SCNNode(geometry: baseGeometry)
        baseNode.position = SCNVector3(0, -0.98, 0)
        bulbAssembly.addChildNode(baseNode)

        // 6. Screw Thread Rings
        for i in 0..<3 {
            let threadTorus = SCNTorus(ringRadius: 0.37, pipeRadius: 0.025)
            threadTorus.materials = [metalMaterial]
            let threadNode = SCNNode(geometry: threadTorus)
            threadNode.position = SCNVector3(0, -0.82 - (Double(i) * 0.12), 0)
            bulbAssembly.addChildNode(threadNode)
        }

        // 7. Ceramic Black Insulator & Contact Tip
        let insulatorGeometry = SCNCylinder(radius: 0.38, height: 0.1)
        let blackMaterial = SCNMaterial()
        blackMaterial.diffuse.contents = NSColor(white: 0.1, alpha: 1.0)
        blackMaterial.roughness.contents = 0.6
        insulatorGeometry.materials = [blackMaterial]
        let insulatorNode = SCNNode(geometry: insulatorGeometry)
        insulatorNode.position = SCNVector3(0, -1.30, 0)
        bulbAssembly.addChildNode(insulatorNode)

        let contactGeometry = SCNSphere(radius: 0.18)
        let copperMaterial = SCNMaterial()
        copperMaterial.lightingModel = .physicallyBased
        copperMaterial.metalness.contents = 0.85
        copperMaterial.diffuse.contents = NSColor(red: 0.78, green: 0.52, blue: 0.35, alpha: 1.0)
        contactGeometry.materials = [copperMaterial]
        let contactNode = SCNNode(geometry: contactGeometry)
        contactNode.position = SCNVector3(0, -1.38, 0)
        contactNode.scale = SCNVector3(1, 0.4, 1)
        bulbAssembly.addChildNode(contactNode)
    }

    public class Coordinator: NSObject {
        var pivotNode: SCNNode?
        var glassNode: SCNNode?
        var neckNode: SCNNode?
        var filamentNode: SCNNode?
        var innerLightNode: SCNNode?

        private var currentAngleX: Float = 0.0
        private var currentAngleY: Float = 0.0
        private var isUserInteracting: Bool = false

        func startIdleAnimation() {
            guard let pivot = pivotNode else { return }
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 18)
            let floatUp = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 2.2)
            floatUp.timingMode = .easeInEaseOut
            let floatDown = floatUp.reversed()

            let floatSequence = SCNAction.repeatForever(SCNAction.sequence([floatUp, floatDown]))
            let rotateForever = SCNAction.repeatForever(rotate)

            pivot.runAction(rotateForever, forKey: "idleRotation")
            pivot.runAction(floatSequence, forKey: "idleFloat")
        }

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let pivot = pivotNode else { return }
            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                isUserInteracting = true
                pivot.removeAction(forKey: "idleRotation")
            case .changed:
                let sensitivity: Float = 0.012
                currentAngleY += Float(translation.x) * sensitivity
                currentAngleX += Float(-translation.y) * sensitivity
                // Clamp X angle to prevent flipping
                currentAngleX = max(-0.8, min(0.8, currentAngleX))

                pivot.eulerAngles = SCNVector3(currentAngleX, currentAngleY, 0)
                gesture.setTranslation(.zero, in: gesture.view)
            case .ended, .cancelled:
                isUserInteracting = false
                // Resume gentle idle rotation after 2.5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    guard let self = self, !self.isUserInteracting else { return }
                    self.startIdleAnimation()
                }
            default:
                break
            }
        }

        func updateState(isOn: Bool, color: NSColor, brightness: Double) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35

            let targetColor = color
            let dimmingFactor = CGFloat(max(0.1, brightness / 100.0))

            guard let glassMat = glassNode?.geometry?.materials.first,
                  let neckMat = neckNode?.geometry?.materials.first,
                  let filamentMat = filamentNode?.geometry?.materials.first,
                  let innerLight = innerLightNode?.light else {
                SCNTransaction.commit()
                return
            }

            if isOn {
                // Glass glow
                glassMat.diffuse.contents = targetColor.withAlphaComponent(0.85)
                glassMat.emission.contents = targetColor
                glassMat.emission.intensity = 1.4 * dimmingFactor
                glassMat.transparency = 0.88

                // Neck subtle glow
                neckMat.diffuse.contents = targetColor.withAlphaComponent(0.7)
                neckMat.emission.contents = targetColor
                neckMat.emission.intensity = 0.7 * dimmingFactor
                neckMat.transparency = 0.92

                // Filament brilliant glow
                filamentMat.emission.contents = targetColor
                filamentMat.emission.intensity = 3.5 * dimmingFactor
                filamentMat.diffuse.contents = NSColor.white

                // Omni light emission
                innerLight.color = targetColor
                innerLight.intensity = 850.0 * Double(dimmingFactor)
            } else {
                // Off state: sleek cool frosted translucent glass
                let offGlassColor = NSColor(white: 0.28, alpha: 0.45)
                glassMat.diffuse.contents = offGlassColor
                glassMat.emission.contents = NSColor.black
                glassMat.emission.intensity = 0.0
                glassMat.transparency = 0.55

                neckMat.diffuse.contents = offGlassColor
                neckMat.emission.contents = NSColor.black
                neckMat.emission.intensity = 0.0
                neckMat.transparency = 0.65

                filamentMat.diffuse.contents = NSColor(white: 0.3, alpha: 1.0)
                filamentMat.emission.contents = NSColor.black
                filamentMat.emission.intensity = 0.0

                innerLight.intensity = 0.0
            }

            SCNTransaction.commit()
        }
    }
}
