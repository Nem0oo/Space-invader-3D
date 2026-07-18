//
// ProjectileManager.swift
//
// Tir joueur (primitive géométrique, un seul projectile actif à la fois) et
// tirs aliens (multiples, automatiques). Gère aussi le spawn des explosions
// (SCNParticleSystem sur la texture explosion07.png, pas de géométrie dédiée).
//

import SceneKit
import UIKit

final class ProjectileManager {

    enum Owner { case player, alien }

    final class Projectile {
        let node: SCNNode
        let owner: Owner
        init(node: SCNNode, owner: Owner) {
            self.node = node
            self.owner = owner
        }
    }

    // MARK: - Constantes ajustables

    static let playerProjectileSpeed: Float = 42
    static let alienProjectileSpeed: Float = 20
    static let projectileRadius: Float = 0.16
    static let projectileLength: Float = 0.9
    static let playerProjectileColor: UIColor = .cyan
    static let alienProjectileColor = UIColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
    /// Distance Z (depuis le vaisseau, ~0) au-delà de laquelle un tir manqué est
    /// nettoyé — juste au-delà de la formation la plus profonde (startZ le plus
    /// négatif défini dans Resources/Assets/Levels), pour que l'attente avant de
    /// pouvoir retirer après un tir raté reste courte.
    static let playerCleanupZ: Float = -75
    /// Distance Z au-delà de laquelle un tir alien est nettoyé (proche caméra).
    static let alienCleanupZ: Float = 20

    static let explosionDuration: TimeInterval = 0.6
    static let explosionBirthRate: CGFloat = 300
    static let explosionParticleSize: CGFloat = 0.35
    static let explosionParticleSpeed: CGFloat = 2.5

    private let parentNode: SCNNode
    private(set) var playerProjectile: Projectile?
    private(set) var alienProjectiles: [Projectile] = []

    init(parentNode: SCNNode) {
        self.parentNode = parentNode
    }

    /// Respecte la règle originale : impossible de spammer, un seul tir joueur actif à la fois.
    var canPlayerFire: Bool { playerProjectile == nil }

    @discardableResult
    func firePlayerProjectile(from position: SCNVector3) -> Bool {
        guard canPlayerFire else { return false }
        let node = makeProjectileNode(color: Self.playerProjectileColor)
        node.position = position
        parentNode.addChildNode(node)
        playerProjectile = Projectile(node: node, owner: .player)
        return true
    }

    func fireAlienProjectile(from position: SCNVector3) {
        let node = makeProjectileNode(color: Self.alienProjectileColor)
        node.position = position
        parentNode.addChildNode(node)
        alienProjectiles.append(Projectile(node: node, owner: .alien))
    }

    private func makeProjectileNode(color: UIColor) -> SCNNode {
        let geometry = SCNCylinder(radius: CGFloat(Self.projectileRadius), height: CGFloat(Self.projectileLength))
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.lightingModel = .constant
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.eulerAngles.x = .pi / 2 // cylindre couché le long de l'axe Z (axe de tir)
        return node
    }

    func update(deltaTime: TimeInterval) {
        let dt = Float(deltaTime)

        if let projectile = playerProjectile {
            projectile.node.position.z -= Self.playerProjectileSpeed * dt
            if projectile.node.position.z < Self.playerCleanupZ {
                removePlayerProjectile()
            }
        }

        var stillAlive: [Projectile] = []
        stillAlive.reserveCapacity(alienProjectiles.count)
        for projectile in alienProjectiles {
            projectile.node.position.z += Self.alienProjectileSpeed * dt
            if projectile.node.position.z > Self.alienCleanupZ {
                projectile.node.removeFromParentNode()
            } else {
                stillAlive.append(projectile)
            }
        }
        alienProjectiles = stillAlive
    }

    func removePlayerProjectile() {
        playerProjectile?.node.removeFromParentNode()
        playerProjectile = nil
    }

    func removeAlienProjectile(_ projectile: Projectile) {
        projectile.node.removeFromParentNode()
        alienProjectiles.removeAll { $0 === projectile }
    }

    // MARK: - Explosions

    func spawnExplosion(at worldPosition: SCNVector3) {
        let explosionNode = SCNNode()
        explosionNode.position = worldPosition
        explosionNode.addParticleSystem(makeExplosionParticleSystem())
        parentNode.addChildNode(explosionNode)

        let wait = SCNAction.wait(duration: Self.explosionDuration)
        let remove = SCNAction.removeFromParentNode()
        explosionNode.runAction(.sequence([wait, remove]))
    }

    private func makeExplosionParticleSystem() -> SCNParticleSystem {
        let system = SCNParticleSystem()
        if let url = Bundle.assetURL("explosion07", withExtension: "png") {
            system.particleImage = url
        }
        system.birthRate = Self.explosionBirthRate
        system.particleLifeSpan = CGFloat(Self.explosionDuration)
        system.particleLifeSpanVariation = CGFloat(Self.explosionDuration * 0.3)
        system.particleSize = Self.explosionParticleSize
        system.particleSizeVariation = Self.explosionParticleSize * 0.4
        system.particleVelocity = Self.explosionParticleSpeed
        system.particleVelocityVariation = Self.explosionParticleSpeed * 0.6
        system.spreadingAngle = 180
        system.emissionDuration = 0.08
        system.loops = false
        system.blendMode = .additive
        system.particleColor = .white
        system.isLightingEnabled = false
        return system
    }
}
