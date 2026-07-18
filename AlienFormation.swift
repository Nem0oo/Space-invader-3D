//
// AlienFormation.swift
//
// Spawn/mouvement/tir de la formation d'aliens. La formation avance en bloc
// en Z (grossissement naturel par la perspective, pas de scale-up manuel) et
// oscille latéralement. Un alien aléatoire par colonne peut tirer, avec une
// cadence qui augmente à mesure que la vague se vide.
//

import SceneKit
import UIKit

final class AlienFormation {

    struct Alien {
        let node: SCNNode
        let column: Int
        var isAlive: Bool
    }

    // MARK: - Constantes ajustables

    /// Position Z (proche caméra) au-delà de laquelle la formation est considérée avoir atteint le joueur.
    static let defenseLineZ: Float = -2.0
    /// Rayon approximatif d'un alien pour les tests de collision simple sphère/sphère.
    static let alienCollisionRadius: Float = 0.9
    /// Variation aléatoire de scale individuelle par alien (multiplicatif, autour de alienScale).
    static let individualScaleJitter: ClosedRange<Float> = 0.9...1.1

    private(set) var aliens: [Alien] = []
    let formationNode = SCNNode()
    private let templateNode: SCNNode
    private(set) var config: WaveConfig

    private var swayPhase: Float = 0
    private var elapsedSinceLastFire: [Int: TimeInterval] = [:]
    private var nextFireDelay: [Int: TimeInterval] = [:]

    /// Déclenché quand un alien tire : position monde du tireur.
    var onAlienFire: ((SCNVector3) -> Void)?
    /// Déclenché quand la formation atteint la ligne de défense.
    var onReachedDefenseLine: (() -> Void)?

    init(templateNode: SCNNode, config: WaveConfig, parent: SCNNode) {
        self.templateNode = templateNode
        self.config = config
        parent.addChildNode(formationNode)
        spawn(config: config)
    }

    var aliveCount: Int { aliens.reduce(0) { $0 + ($1.isAlive ? 1 : 0) } }
    var isCleared: Bool { aliveCount == 0 }

    func spawn(config: WaveConfig) {
        formationNode.childNodes.forEach { $0.removeFromParentNode() }
        aliens.removeAll()
        elapsedSinceLastFire.removeAll()
        nextFireDelay.removeAll()
        self.config = config
        swayPhase = 0

        formationNode.position = SCNVector3(0, 0, config.startZ)

        let originX = -Float(config.columns - 1) * config.horizontalSpacing / 2
        let originY = Float(config.rows - 1) * config.verticalSpacing / 2

        for row in 0..<config.rows {
            for column in 0..<config.columns {
                let clone = templateNode.clone()
                let scale = Float.random(in: Self.individualScaleJitter) * config.alienScale
                clone.scale = SCNVector3(scale, scale, scale)
                clone.position = SCNVector3(
                    originX + Float(column) * config.horizontalSpacing,
                    originY - Float(row) * config.verticalSpacing,
                    0
                )
                applyTint(config.alienTint, to: clone)
                formationNode.addChildNode(clone)
                aliens.append(Alien(node: clone, column: column, isAlive: true))
            }
        }

        for column in 0..<config.columns {
            nextFireDelay[column] = fireInterval(ratio: 1.0)
            elapsedSinceLastFire[column] = 0
        }
    }

    private func applyTint(_ tint: [Float], to node: SCNNode) {
        guard tint.count >= 3 else { return }
        let color = UIColor(red: CGFloat(tint[0]), green: CGFloat(tint[1]), blue: CGFloat(tint[2]), alpha: 1)
        node.enumerateHierarchy { child, _ in
            child.geometry?.materials.forEach { $0.multiply.contents = color }
        }
    }

    func update(deltaTime: TimeInterval) {
        guard !isCleared else { return }
        let dt = Float(deltaTime)

        formationNode.position.z += config.advanceSpeed * dt
        swayPhase += config.swaySpeed * dt
        formationNode.position.x = sin(swayPhase) * config.swayRange

        if formationNode.position.z >= Self.defenseLineZ {
            onReachedDefenseLine?()
            formationNode.position.z = config.startZ
        }

        updateFiring(deltaTime: deltaTime)
    }

    private func fireInterval(ratio: Float) -> TimeInterval {
        // ratio = fraction d'aliens encore vivants ; plus il en reste peu, plus l'intervalle se resserre.
        let rampedMin = max(config.minFireInterval * ratio, config.fireIntervalFloor)
        let rampedMax = max(config.maxFireInterval * ratio, config.fireIntervalFloor * 1.5)
        return Double.random(in: Double(min(rampedMin, rampedMax))...Double(max(rampedMin, rampedMax)))
    }

    private func updateFiring(deltaTime: TimeInterval) {
        let ratio = Float(aliveCount) / Float(max(aliens.count, 1))

        for column in 0..<config.columns {
            guard elapsedSinceLastFire[column] != nil else { continue }
            elapsedSinceLastFire[column]! += deltaTime
            guard let delay = nextFireDelay[column], elapsedSinceLastFire[column]! >= delay else { continue }

            elapsedSinceLastFire[column] = 0
            nextFireDelay[column] = fireInterval(ratio: ratio)

            if let shooter = randomAliveAlien(inColumn: column) {
                let worldPos = shooter.node.worldPosition
                onAlienFire?(worldPos)
            }
        }
    }

    private func randomAliveAlien(inColumn column: Int) -> Alien? {
        aliens.filter { $0.isAlive && $0.column == column }.randomElement()
    }

    func destroyAlien(_ node: SCNNode) {
        guard let index = aliens.firstIndex(where: { $0.node === node }) else { return }
        aliens[index].isAlive = false
        aliens[index].node.removeFromParentNode()
    }
}
