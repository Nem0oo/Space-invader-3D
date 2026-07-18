//
// GameViewController.swift
//
// Héberge le SCNView et le HUDOverlay, et orchestre la boucle de jeu :
// avance ship/caméra/formation/projectiles, résout les collisions (tests de
// distance simples, pas de moteur physique), fait progresser GameState.
//

import SceneKit
import UIKit

final class GameViewController: UIViewController {

    // MARK: - Constantes ajustables

    /// Décalage du canon depuis le centre du vaisseau (repère local), axe -Z = vers l'avant.
    static let muzzleOffset = SCNVector3(0, 0.15, -1.4)
    /// Rayon de collision approximatif du vaisseau pour les tirs aliens.
    static let playerHitRadius: Float = 0.7
    /// Delta-temps max pris en compte par frame (évite les gros sauts après une pause/retour d'arrière-plan).
    static let maxDeltaTime: TimeInterval = 1.0 / 20.0

    private var sceneKitView: SCNView!
    private var hud: HUDOverlay!

    private let gameScene = GameScene()
    private lazy var shipController = PlayerShipController(shipNode: gameScene.shipNode)
    private lazy var projectileManager = ProjectileManager(parentNode: gameScene.playfieldNode)
    private lazy var alienFormation = AlienFormation(
        templateNode: gameScene.alienTemplate,
        config: LevelData.wave(for: 1),
        parent: gameScene.playfieldNode
    )
    private let gameState = GameState()

    private var lastUpdateTime: TimeInterval?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupHUD()
        wireCallbacks()
        gameState.reset()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var shouldAutorotate: Bool { true }

    // MARK: - Setup

    private func setupSceneView() {
        let scnView = SCNView(frame: view.bounds)
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.scene = gameScene.scene
        scnView.pointOfView = gameScene.cameraRig.cameraNode
        scnView.backgroundColor = .black
        scnView.delegate = self
        scnView.isPlaying = true
        view.addSubview(scnView)
        sceneKitView = scnView
    }

    private func setupHUD() {
        let overlay = HUDOverlay(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.delegate = self
        view.addSubview(overlay)
        hud = overlay
    }

    private func wireCallbacks() {
        gameState.delegate = self

        alienFormation.onAlienFire = { [weak self] worldPosition in
            self?.projectileManager.fireAlienProjectile(from: worldPosition)
        }
        alienFormation.onReachedDefenseLine = { [weak self] in
            self?.gameState.registerHit()
        }
    }

    // MARK: - Boucle de jeu (appelée depuis le thread de rendu SceneKit)

    private func advance(deltaTime: TimeInterval) {
        guard !gameState.isGameOver else { return }

        shipController.update(deltaTime: deltaTime)
        gameScene.cameraRig.update(deltaTime: deltaTime, shipPositionX: shipController.positionX)
        alienFormation.update(deltaTime: deltaTime)
        projectileManager.update(deltaTime: deltaTime)
        gameState.update(deltaTime: deltaTime)

        resolveCollisions()
        checkWaveCleared()
    }

    private func resolveCollisions() {
        if let playerShot = projectileManager.playerProjectile {
            let shotPosition = playerShot.node.worldPosition
            for alien in alienFormation.aliens where alien.isAlive {
                let alienPosition = alien.node.worldPosition
                if (shotPosition - alienPosition).length() < AlienFormation.alienCollisionRadius {
                    alienFormation.destroyAlien(alien.node)
                    projectileManager.spawnExplosion(at: alienPosition)
                    projectileManager.removePlayerProjectile()
                    gameState.addKill()
                    break
                }
            }
        }

        let shipPosition = gameScene.shipNode.worldPosition
        for projectile in projectileManager.alienProjectiles {
            if (projectile.node.worldPosition - shipPosition).length() < Self.playerHitRadius {
                projectileManager.removeAlienProjectile(projectile)
                projectileManager.spawnExplosion(at: shipPosition)
                gameState.registerHit()
                break
            }
        }
    }

    private func checkWaveCleared() {
        guard alienFormation.isCleared else { return }
        gameState.startNextWave()
        alienFormation.spawn(config: LevelData.wave(for: gameState.waveIndex))
    }

    private func resetGame() {
        gameState.reset()
        alienFormation.spawn(config: LevelData.wave(for: 1))
        projectileManager.removePlayerProjectile()
        for projectile in projectileManager.alienProjectiles {
            projectileManager.removeAlienProjectile(projectile)
        }
        shipController.isTurningLeft = false
        shipController.isTurningRight = false
        hud.hideGameOver()
    }
}

// MARK: - SCNSceneRendererDelegate

extension GameViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        defer { lastUpdateTime = time }
        guard let last = lastUpdateTime else { return }
        let deltaTime = min(time - last, Self.maxDeltaTime)
        advance(deltaTime: deltaTime)
    }
}

// MARK: - HUDOverlayDelegate

extension GameViewController: HUDOverlayDelegate {
    func hudDidChangeTurningLeft(_ isPressed: Bool) {
        shipController.isTurningLeft = isPressed
    }

    func hudDidChangeTurningRight(_ isPressed: Bool) {
        shipController.isTurningRight = isPressed
    }

    func hudDidTapFire() {
        let muzzlePosition = gameScene.shipNode.convertPosition(Self.muzzleOffset, to: gameScene.playfieldNode)
        projectileManager.firePlayerProjectile(from: muzzlePosition)
    }

    func hudDidTapCameraModeCycle() {
        gameScene.cameraRig.cycleMode()
        hud.updateCameraMode(gameScene.cameraRig.mode)
    }

    func hudDidTapReplay() {
        resetGame()
    }
}

// MARK: - GameStateDelegate

extension GameViewController: GameStateDelegate {
    func gameStateDidUpdateScore(_ score: Int) {
        DispatchQueue.main.async { [weak self] in self?.hud.updateScore(score) }
    }

    func gameStateDidUpdateLives(_ lives: Int) {
        DispatchQueue.main.async { [weak self] in self?.hud.updateLives(lives) }
    }

    func gameStateDidStartWave(_ waveIndex: Int) {
        // Point d'extension pour un futur bandeau "VAGUE N" ; score/vies suffisent pour ce POC.
    }

    func gameStateDidEndGame(finalScore: Int) {
        DispatchQueue.main.async { [weak self] in self?.hud.showGameOver(finalScore: finalScore) }
    }
}

// MARK: - SCNVector3 helpers

private extension SCNVector3 {
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    func length() -> Float {
        sqrt(x * x + y * y + z * z)
    }
}
