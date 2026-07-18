//
// PlayerShipController.swift
//
// Mouvement du vaisseau joueur : trois lissages indépendants à vitesses
// différentes (roll rapide > position moyenne > caméra lente, cette dernière
// gérée par CameraRig). Déplacement latéral uniquement, pas de contrôle
// vertical. Toutes les constantes de tuning sont regroupées ci-dessous.
//

import SceneKit

final class PlayerShipController {

    // MARK: - Constantes ajustables (tuning visuel)

    /// Angle de roulis max atteint en virage plein, en degrés.
    static let rollAngleMaxDegrees: Float = 22
    /// Vitesse de lissage exponentiel du roulis (plus haut = plus réactif).
    static let rollSmoothingSpeed: Float = 10.0
    /// Accélération latérale appliquée tant que le bouton de virage est maintenu (unités/s²).
    static let lateralAcceleration: Float = 14.0
    /// Vitesse latérale maximale atteignable (unités/s).
    static let lateralMaxSpeed: Float = 6.0
    /// Vitesse de freinage exponentiel une fois le bouton relâché.
    static let lateralDamping: Float = 6.0
    /// Distance latérale max depuis le centre (clamp de la position X).
    static let lateralBounds: Float = 9.0

    let shipNode: SCNNode

    /// Maintenu à true tant que le bouton gauche est pressé (piloté par HUDOverlay).
    var isTurningLeft = false
    /// Maintenu à true tant que le bouton droit est pressé (piloté par HUDOverlay).
    var isTurningRight = false

    /// Position latérale courante (miroir de shipNode.position.x), exposée pour CameraRig.
    private(set) var positionX: Float = 0
    private var currentRollDegrees: Float = 0
    private var lateralVelocity: Float = 0

    init(shipNode: SCNNode) {
        self.shipNode = shipNode
    }

    func update(deltaTime: TimeInterval) {
        let dt = Float(deltaTime)
        let inputDirection: Float = isTurningRight ? 1 : (isTurningLeft ? -1 : 0)

        updateRoll(inputDirection: inputDirection, dt: dt)
        updatePosition(inputDirection: inputDirection, dt: dt)

        shipNode.position.x = positionX
        shipNode.eulerAngles.z = currentRollDegrees * .pi / 180
    }

    private func updateRoll(inputDirection: Float, dt: Float) {
        let targetRoll = inputDirection * Self.rollAngleMaxDegrees
        let t = 1 - exp(-Self.rollSmoothingSpeed * dt)
        currentRollDegrees += (targetRoll - currentRollDegrees) * t
    }

    private func updatePosition(inputDirection: Float, dt: Float) {
        if inputDirection != 0 {
            lateralVelocity += inputDirection * Self.lateralAcceleration * dt
            lateralVelocity = max(-Self.lateralMaxSpeed, min(Self.lateralMaxSpeed, lateralVelocity))
        } else {
            let dampT = 1 - exp(-Self.lateralDamping * dt)
            lateralVelocity -= lateralVelocity * dampT
        }

        positionX += lateralVelocity * dt

        if positionX > Self.lateralBounds {
            positionX = Self.lateralBounds
            lateralVelocity = min(lateralVelocity, 0)
        } else if positionX < -Self.lateralBounds {
            positionX = -Self.lateralBounds
            lateralVelocity = max(lateralVelocity, 0)
        }
    }
}
