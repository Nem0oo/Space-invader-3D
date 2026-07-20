//
// CameraRig.swift
//
// Rig caméra unique à 2 modes (vue complète / vue partielle), chacun défini
// par un offset et un FOV. Le lag caméra (suivi continu, écart plafonné) est
// une seule et même logique appliquée quel que soit le mode, sur X et Y.
//

import SceneKit

enum CameraMode {
    case full
    case partial

    /// Offset (x/y additionnels au lag, z) appliqué relativement à la position du vaisseau.
    var offset: SCNVector3 {
        switch self {
        case .full: return SCNVector3(0, 3.2, 9.0)    // reculée/au-dessus, vaisseau entièrement visible
        case .partial: return SCNVector3(0, 1.1, 3.4) // proche, légèrement derrière, on voit l'arrière/les ailes
        }
    }

    var fieldOfView: CGFloat {
        switch self {
        case .full: return 60
        case .partial: return 70
        }
    }

    var label: String {
        switch self {
        case .full: return "VUE COMPLÈTE"
        case .partial: return "VUE PARTIELLE"
        }
    }
}

final class CameraRig {

    // MARK: - Constantes ajustables (tuning visuel)

    /// Écart maximum plafonné entre la caméra et la position (latérale/verticale) du vaisseau.
    static let maxLagDistance: Float = 1.4
    /// Vitesse de lissage du suivi caméra (lent, indépendant du roll/position du vaisseau).
    static let followSmoothingSpeed: Float = 2.2
    /// Légère inclinaison vers le bas pour bien cadrer le vaisseau.
    static let downwardTiltRadians: Float = -0.12

    /// Écart entre les deux caméras œil du mode stéréogramme (vision parallèle),
    /// en unités monde. Volontairement très exagéré par rapport à l'écart
    /// interoculaire humain réel (~0.063) : à ces distances de jeu (aliens à
    /// 10-70 unités de la caméra), un écart réaliste donnerait un relief
    /// quasi imperceptible. Départ à ajuster après test visuel.
    static let stereoEyeSeparation: Float = 0.7

    let cameraNode: SCNNode
    /// Enfants de cameraNode : héritent automatiquement de sa position/rotation
    /// (mode, lag) chaque frame, sans code de synchronisation supplémentaire.
    let leftEyeCameraNode = SCNNode()
    let rightEyeCameraNode = SCNNode()

    private(set) var mode: CameraMode = .full
    private var laggedX: Float = 0
    private var laggedY: Float = 0

    init() {
        let camera = SCNCamera()
        camera.zNear = 0.05
        camera.zFar = 400
        camera.fieldOfView = CameraMode.full.fieldOfView
        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.eulerAngles.x = Self.downwardTiltRadians
        applyOffset(targetX: 0, targetY: 0)

        let leftCamera = SCNCamera()
        leftCamera.zNear = camera.zNear
        leftCamera.zFar = camera.zFar
        leftCamera.fieldOfView = camera.fieldOfView
        leftEyeCameraNode.camera = leftCamera
        leftEyeCameraNode.position = SCNVector3(-Self.stereoEyeSeparation / 2, 0, 0)
        cameraNode.addChildNode(leftEyeCameraNode)

        let rightCamera = SCNCamera()
        rightCamera.zNear = camera.zNear
        rightCamera.zFar = camera.zFar
        rightCamera.fieldOfView = camera.fieldOfView
        rightEyeCameraNode.camera = rightCamera
        rightEyeCameraNode.position = SCNVector3(Self.stereoEyeSeparation / 2, 0, 0)
        cameraNode.addChildNode(rightEyeCameraNode)
    }

    func cycleMode() {
        mode = (mode == .full) ? .partial : .full
        let fov = mode.fieldOfView
        cameraNode.camera?.fieldOfView = fov
        leftEyeCameraNode.camera?.fieldOfView = fov
        rightEyeCameraNode.camera?.fieldOfView = fov
    }

    func update(deltaTime: TimeInterval, shipPositionX: Float, shipPositionY: Float) {
        let dt = Float(deltaTime)
        let t = 1 - exp(-Self.followSmoothingSpeed * dt)
        laggedX += (shipPositionX - laggedX) * t
        laggedY += (shipPositionY - laggedY) * t

        // L'écart se stabilise vite puis reste constant, quelle que soit la durée du virage.
        laggedX = clampLag(target: shipPositionX, lagged: laggedX)
        laggedY = clampLag(target: shipPositionY, lagged: laggedY)

        applyOffset(targetX: laggedX, targetY: laggedY)
    }

    private func clampLag(target: Float, lagged: Float) -> Float {
        let delta = target - lagged
        guard abs(delta) > Self.maxLagDistance else { return lagged }
        return target - Self.maxLagDistance * (delta >= 0 ? 1 : -1)
    }

    private func applyOffset(targetX: Float, targetY: Float) {
        let offset = mode.offset
        cameraNode.position = SCNVector3(targetX + offset.x, targetY + offset.y, offset.z)
    }
}
