//
// CameraRig.swift
//
// Rig caméra unique à 2 modes (vue complète / vue partielle), chacun défini
// par un offset et un FOV. Le lag caméra (suivi continu, écart plafonné) est
// une seule et même logique appliquée quel que soit le mode.
//

import SceneKit

enum CameraMode {
    case full
    case partial

    /// Offset (x additionnel au lag, y, z) appliqué relativement au centre de la voie du vaisseau.
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

    /// Écart maximum plafonné entre la caméra et la position latérale du vaisseau.
    static let maxLagDistance: Float = 1.4
    /// Vitesse de lissage du suivi caméra (lent, indépendant du roll/position du vaisseau).
    static let followSmoothingSpeed: Float = 2.2
    /// Légère inclinaison vers le bas pour bien cadrer le vaisseau.
    static let downwardTiltRadians: Float = -0.12

    let cameraNode: SCNNode
    private(set) var mode: CameraMode = .full
    private var laggedX: Float = 0

    init() {
        let camera = SCNCamera()
        camera.zNear = 0.05
        camera.zFar = 400
        camera.fieldOfView = CameraMode.full.fieldOfView
        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.eulerAngles.x = Self.downwardTiltRadians
        applyOffset(targetX: 0)
    }

    func cycleMode() {
        mode = (mode == .full) ? .partial : .full
        cameraNode.camera?.fieldOfView = mode.fieldOfView
    }

    func update(deltaTime: TimeInterval, shipPositionX: Float) {
        let dt = Float(deltaTime)
        let t = 1 - exp(-Self.followSmoothingSpeed * dt)
        laggedX += (shipPositionX - laggedX) * t

        // L'écart se stabilise vite puis reste constant, quelle que soit la durée du virage.
        let delta = shipPositionX - laggedX
        if abs(delta) > Self.maxLagDistance {
            laggedX = shipPositionX - Self.maxLagDistance * (delta >= 0 ? 1 : -1)
        }

        applyOffset(targetX: laggedX)
    }

    private func applyOffset(targetX: Float) {
        let offset = mode.offset
        cameraNode.position = SCNVector3(targetX + offset.x, offset.y, offset.z)
    }
}
