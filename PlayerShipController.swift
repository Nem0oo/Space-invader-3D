//
// PlayerShipController.swift
//
// Mouvement du vaisseau joueur : lissages indépendants à vitesses différentes
// (roll/pitch rapides > position moyenne > caméra lente, cette dernière gérée
// par CameraRig). Déplacement latéral ET vertical (nécessaire pour viser les
// différentes lignes de la formation alien). Toutes les constantes de tuning
// sont regroupées ci-dessous.
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

    /// Angle de tangage (pitch) max atteint en montée/descente pleine, en degrés.
    static let pitchAngleMaxDegrees: Float = 16
    /// Vitesse de lissage exponentiel du tangage.
    static let pitchSmoothingSpeed: Float = 10.0
    /// Accélération verticale appliquée tant que le bouton haut/bas est maintenu (unités/s²).
    static let verticalAcceleration: Float = 12.0
    /// Vitesse verticale maximale atteignable (unités/s).
    static let verticalMaxSpeed: Float = 5.0
    /// Vitesse de freinage exponentiel une fois le bouton relâché.
    static let verticalDamping: Float = 6.0
    /// Distance verticale max depuis le centre (clamp de la position Y) — couvre les
    /// lignes de la formation la plus large (voir verticalSpacing/rows dans les WaveConfig).
    static let verticalBounds: Float = 4.0

    let shipNode: SCNNode

    /// Entrée latérale analogique du joystick HUD, -1 (gauche) à +1 (droite).
    var lateralInput: Float = 0
    /// Entrée verticale analogique du joystick HUD, -1 (bas) à +1 (haut).
    var verticalInput: Float = 0

    /// Position latérale courante (miroir de shipNode.position.x), exposée pour CameraRig.
    private(set) var positionX: Float = 0
    /// Position verticale courante (miroir de shipNode.position.y), exposée pour CameraRig.
    private(set) var positionY: Float = 0
    private var currentRollDegrees: Float = 0
    private var currentPitchDegrees: Float = 0
    private var lateralVelocity: Float = 0
    private var verticalVelocity: Float = 0

    init(shipNode: SCNNode) {
        self.shipNode = shipNode
    }

    func update(deltaTime: TimeInterval) {
        let dt = Float(deltaTime)
        let lateral = max(-1, min(1, lateralInput))
        let vertical = max(-1, min(1, verticalInput))

        // Signe négatif : avec le forward -Z / up +Y / right +X standard de SceneKit,
        // une rotation Z positive lève le côté droit (bank gauche) — on veut l'inverse
        // (bank à droite, côté droit qui descend) quand on tourne à droite.
        currentRollDegrees = smoothed(current: currentRollDegrees, target: -lateral * Self.rollAngleMaxDegrees, speed: Self.rollSmoothingSpeed, dt: dt)
        currentPitchDegrees = smoothed(current: currentPitchDegrees, target: vertical * Self.pitchAngleMaxDegrees, speed: Self.pitchSmoothingSpeed, dt: dt)

        (positionX, lateralVelocity) = updatedAxis(
            position: positionX, velocity: lateralVelocity, input: lateral,
            acceleration: Self.lateralAcceleration, maxSpeed: Self.lateralMaxSpeed,
            damping: Self.lateralDamping, bounds: Self.lateralBounds, dt: dt
        )
        (positionY, verticalVelocity) = updatedAxis(
            position: positionY, velocity: verticalVelocity, input: vertical,
            acceleration: Self.verticalAcceleration, maxSpeed: Self.verticalMaxSpeed,
            damping: Self.verticalDamping, bounds: Self.verticalBounds, dt: dt
        )

        shipNode.position.x = positionX
        shipNode.position.y = positionY
        // Tangage sur l'axe X local, roulis sur l'axe Z local : montée/descente
        // n'affecte pas le roulis de virage, et inversement.
        shipNode.eulerAngles = SCNVector3(
            currentPitchDegrees * .pi / 180,
            0,
            currentRollDegrees * .pi / 180
        )
    }

    private func smoothed(current: Float, target: Float, speed: Float, dt: Float) -> Float {
        let t = 1 - exp(-speed * dt)
        return current + (target - current) * t
    }

    private func updatedAxis(
        position: Float, velocity: Float, input: Float,
        acceleration: Float, maxSpeed: Float, damping: Float, bounds: Float, dt: Float
    ) -> (position: Float, velocity: Float) {
        var newVelocity = velocity
        if input != 0 {
            // La vitesse max est plafonnée proportionnellement à l'inclinaison du
            // joystick, pas seulement le temps pour l'atteindre : une déviation
            // partielle donne une vitesse de croisière plus lente, pas juste plus lente à atteindre.
            let targetMaxSpeed = maxSpeed * abs(input)
            newVelocity += input * acceleration * dt
            newVelocity = max(-targetMaxSpeed, min(targetMaxSpeed, newVelocity))
        } else {
            let dampT = 1 - exp(-damping * dt)
            newVelocity -= newVelocity * dampT
        }

        var newPosition = position + newVelocity * dt

        if newPosition > bounds {
            newPosition = bounds
            newVelocity = min(newVelocity, 0)
        } else if newPosition < -bounds {
            newPosition = -bounds
            newVelocity = max(newVelocity, 0)
        }

        return (newPosition, newVelocity)
    }
}
