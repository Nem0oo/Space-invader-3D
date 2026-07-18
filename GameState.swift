//
// GameState.swift
//
// Score, vies, game over et progression de vague. Ne connaît rien de
// SceneKit : notifie ses changements via GameStateDelegate.
//

import Foundation

protocol GameStateDelegate: AnyObject {
    func gameStateDidUpdateScore(_ score: Int)
    func gameStateDidUpdateLives(_ lives: Int)
    func gameStateDidStartWave(_ waveIndex: Int)
    func gameStateDidEndGame(finalScore: Int)
}

final class GameState {

    // MARK: - Constantes ajustables
    static let startingLives = 3
    static let invincibilityDuration: TimeInterval = 1.5
    static let pointsPerAlien = 10

    weak var delegate: GameStateDelegate?

    private(set) var score = 0 {
        didSet { delegate?.gameStateDidUpdateScore(score) }
    }
    private(set) var lives = GameState.startingLives {
        didSet { delegate?.gameStateDidUpdateLives(lives) }
    }
    private(set) var waveIndex = 1
    private(set) var isGameOver = false
    private(set) var isInvincible = false
    private var invincibilityRemaining: TimeInterval = 0

    func reset() {
        score = 0
        lives = GameState.startingLives
        waveIndex = 1
        isGameOver = false
        isInvincible = false
        invincibilityRemaining = 0
        delegate?.gameStateDidStartWave(waveIndex)
    }

    func addKill() {
        guard !isGameOver else { return }
        score += GameState.pointsPerAlien
    }

    func startNextWave() {
        guard !isGameOver else { return }
        waveIndex += 1
        delegate?.gameStateDidStartWave(waveIndex)
    }

    /// Retourne true si le hit a effectivement retiré une vie (false si invincible/déjà game over).
    @discardableResult
    func registerHit() -> Bool {
        guard !isGameOver, !isInvincible else { return false }
        lives -= 1
        if lives <= 0 {
            isGameOver = true
            delegate?.gameStateDidEndGame(finalScore: score)
        } else {
            isInvincible = true
            invincibilityRemaining = GameState.invincibilityDuration
        }
        return true
    }

    func update(deltaTime: TimeInterval) {
        guard isInvincible else { return }
        invincibilityRemaining -= deltaTime
        if invincibilityRemaining <= 0 {
            isInvincible = false
            invincibilityRemaining = 0
        }
    }
}
