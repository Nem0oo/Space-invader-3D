//
// HUDOverlay.swift
//
// Overlay tactile UIKit (pas de storyboard) : virage bas-gauche (2 zones,
// maintien), tir bas-droit (tap), cycle caméra en haut, score/vies dans le
// coin opposé, écran de game over. Tout en code, layout à base de frames
// recalculé dans layoutSubviews (orientation landscape fixe).
//

import UIKit

protocol HUDOverlayDelegate: AnyObject {
    func hudDidChangeTurningLeft(_ isPressed: Bool)
    func hudDidChangeTurningRight(_ isPressed: Bool)
    func hudDidChangeAimingUp(_ isPressed: Bool)
    func hudDidChangeAimingDown(_ isPressed: Bool)
    func hudDidTapFire()
    func hudDidTapCameraModeCycle()
    func hudDidTapReplay()
}

final class HUDOverlay: UIView {

    // MARK: - Constantes ajustables (mise en page)

    /// Boutons du D-pad (gauche/droite/haut/bas), plus petits qu'avant pour que les 4 tiennent en croix.
    static let dpadButtonSize: CGFloat = 76
    static let fireButtonSize: CGFloat = 96
    static let cameraButtonSize: CGFloat = 56
    static let edgeMargin: CGFloat = 28
    static let buttonSpacing: CGFloat = 14
    static let controlAlpha: CGFloat = 0.32
    static let controlAlphaPressed: CGFloat = 0.55
    static let crosshairSize: CGFloat = 34

    weak var delegate: HUDOverlayDelegate?

    private let turnLeftButton = UIButton(type: .custom)
    private let turnRightButton = UIButton(type: .custom)
    private let aimUpButton = UIButton(type: .custom)
    private let aimDownButton = UIButton(type: .custom)
    private let fireButton = UIButton(type: .custom)
    private let cameraModeButton = UIButton(type: .custom)
    private let cameraModeLabel = UILabel()
    private let scoreLabel = UILabel()
    private let livesLabel = UILabel()
    private let crosshairView = UIImageView()

    private let gameOverView = UIView()
    private let gameOverTitleLabel = UILabel()
    private let gameOverScoreLabel = UILabel()
    private let replayButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupCrosshair()
        setupControls()
        setupHUDLabels()
        setupGameOverView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supporté") }

    // MARK: - Setup

    /// Viseur fixe au centre de l'écran : le tir part toujours tout droit depuis le
    /// nez du vaisseau (pas de visée indépendante), donc un repère central suffit à
    /// indiquer où on tire.
    private func setupCrosshair() {
        let config = UIImage.SymbolConfiguration(pointSize: Self.crosshairSize * 0.8, weight: .light)
        crosshairView.image = UIImage(systemName: "scope", withConfiguration: config)
        crosshairView.tintColor = UIColor.white.withAlphaComponent(0.75)
        crosshairView.contentMode = .scaleAspectFit
        crosshairView.isUserInteractionEnabled = false
        addSubview(crosshairView)
    }

    private func setupControls() {
        styleControlButton(turnLeftButton, systemImage: "chevron.left.circle.fill", size: Self.dpadButtonSize)
        styleControlButton(turnRightButton, systemImage: "chevron.right.circle.fill", size: Self.dpadButtonSize)
        styleControlButton(aimUpButton, systemImage: "chevron.up.circle.fill", size: Self.dpadButtonSize)
        styleControlButton(aimDownButton, systemImage: "chevron.down.circle.fill", size: Self.dpadButtonSize)
        styleControlButton(fireButton, systemImage: "bolt.fill", size: Self.fireButtonSize)
        styleControlButton(cameraModeButton, systemImage: "camera.rotate.fill", size: Self.cameraButtonSize)

        turnLeftButton.addTarget(self, action: #selector(turnLeftDown), for: .touchDown)
        turnLeftButton.addTarget(self, action: #selector(turnLeftUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        turnRightButton.addTarget(self, action: #selector(turnRightDown), for: .touchDown)
        turnRightButton.addTarget(self, action: #selector(turnRightUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        aimUpButton.addTarget(self, action: #selector(aimUpDown), for: .touchDown)
        aimUpButton.addTarget(self, action: #selector(aimUpUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        aimDownButton.addTarget(self, action: #selector(aimDownDown), for: .touchDown)
        aimDownButton.addTarget(self, action: #selector(aimDownUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        fireButton.addTarget(self, action: #selector(fireTapped), for: .touchUpInside)
        cameraModeButton.addTarget(self, action: #selector(cameraModeTapped), for: .touchUpInside)

        addSubview(turnLeftButton)
        addSubview(turnRightButton)
        addSubview(aimUpButton)
        addSubview(aimDownButton)
        addSubview(fireButton)
        addSubview(cameraModeButton)

        cameraModeLabel.text = CameraMode.full.label
        cameraModeLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        cameraModeLabel.textColor = .white
        cameraModeLabel.textAlignment = .center
        cameraModeLabel.layer.shadowColor = UIColor.black.cgColor
        cameraModeLabel.layer.shadowOpacity = 0.8
        cameraModeLabel.layer.shadowRadius = 2
        cameraModeLabel.layer.shadowOffset = .zero
        addSubview(cameraModeLabel)
    }

    private func styleControlButton(_ button: UIButton, systemImage: String, size: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: size * 0.36, weight: .bold)
        button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlpha)
        button.layer.cornerRadius = size / 2
        button.frame.size = CGSize(width: size, height: size)
    }

    private func setupHUDLabels() {
        scoreLabel.font = .monospacedSystemFont(ofSize: 20, weight: .bold)
        livesLabel.font = .monospacedSystemFont(ofSize: 18, weight: .semibold)
        for label in [scoreLabel, livesLabel] {
            label.textColor = .white
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOpacity = 0.8
            label.layer.shadowRadius = 2
            label.layer.shadowOffset = .zero
            addSubview(label)
        }
        updateScore(0)
        updateLives(GameState.startingLives)
    }

    private func setupGameOverView() {
        gameOverView.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        gameOverView.isHidden = true

        gameOverTitleLabel.text = "GAME OVER"
        gameOverTitleLabel.font = .monospacedSystemFont(ofSize: 34, weight: .heavy)
        gameOverTitleLabel.textColor = .white
        gameOverTitleLabel.textAlignment = .center

        gameOverScoreLabel.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
        gameOverScoreLabel.textColor = .white
        gameOverScoreLabel.textAlignment = .center

        replayButton.setTitle("REJOUER", for: .normal)
        replayButton.titleLabel?.font = .monospacedSystemFont(ofSize: 20, weight: .bold)
        replayButton.tintColor = .white
        replayButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        replayButton.layer.cornerRadius = 12
        replayButton.addTarget(self, action: #selector(replayTapped), for: .touchUpInside)

        gameOverView.addSubview(gameOverTitleLabel)
        gameOverView.addSubview(gameOverScoreLabel)
        gameOverView.addSubview(replayButton)
        addSubview(gameOverView)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        crosshairView.frame = CGRect(
            x: bounds.midX - Self.crosshairSize / 2,
            y: bounds.midY - Self.crosshairSize / 2,
            width: Self.crosshairSize,
            height: Self.crosshairSize
        )

        // D-pad en croix : gauche/droite virent (roll + latéral), haut/bas visent
        // les différentes lignes de la formation (pitch + vertical).
        let dpadStep = Self.dpadButtonSize + Self.buttonSpacing
        let dpadCenterX = Self.edgeMargin + Self.dpadButtonSize / 2 + dpadStep
        let dpadCenterY = bounds.maxY - Self.edgeMargin - Self.dpadButtonSize / 2 - dpadStep

        turnLeftButton.center = CGPoint(x: dpadCenterX - dpadStep, y: dpadCenterY)
        turnRightButton.center = CGPoint(x: dpadCenterX + dpadStep, y: dpadCenterY)
        aimUpButton.center = CGPoint(x: dpadCenterX, y: dpadCenterY - dpadStep)
        aimDownButton.center = CGPoint(x: dpadCenterX, y: dpadCenterY + dpadStep)

        fireButton.center = CGPoint(
            x: bounds.maxX - Self.edgeMargin - Self.fireButtonSize / 2,
            y: bounds.maxY - Self.edgeMargin - Self.fireButtonSize / 2
        )

        cameraModeButton.center = CGPoint(
            x: bounds.maxX - Self.edgeMargin - Self.cameraButtonSize / 2,
            y: Self.edgeMargin + Self.cameraButtonSize / 2
        )
        cameraModeLabel.frame = CGRect(
            x: cameraModeButton.frame.minX - 60,
            y: cameraModeButton.frame.maxY + 4,
            width: Self.cameraButtonSize + 120,
            height: 16
        )

        scoreLabel.frame = CGRect(x: Self.edgeMargin, y: Self.edgeMargin, width: 200, height: 28)
        livesLabel.frame = CGRect(x: Self.edgeMargin, y: scoreLabel.frame.maxY + 4, width: 200, height: 24)

        gameOverView.frame = bounds
        gameOverTitleLabel.frame = CGRect(x: 0, y: bounds.midY - 70, width: bounds.width, height: 44)
        gameOverScoreLabel.frame = CGRect(x: 0, y: gameOverTitleLabel.frame.maxY + 8, width: bounds.width, height: 28)
        replayButton.frame = CGRect(x: bounds.midX - 90, y: gameOverScoreLabel.frame.maxY + 24, width: 180, height: 48)
    }

    // MARK: - Public updates

    func updateScore(_ score: Int) {
        scoreLabel.text = String(format: "SCORE %04d", score)
    }

    func updateLives(_ lives: Int) {
        livesLabel.text = "VIES " + String(repeating: "♥ ", count: max(lives, 0)).trimmingCharacters(in: .whitespaces)
    }

    func updateCameraMode(_ mode: CameraMode) {
        cameraModeLabel.text = mode.label
    }

    func showGameOver(finalScore: Int) {
        gameOverScoreLabel.text = String(format: "SCORE FINAL : %04d", finalScore)
        gameOverView.isHidden = false
    }

    func hideGameOver() {
        gameOverView.isHidden = true
    }

    // MARK: - Actions

    @objc private func turnLeftDown() {
        turnLeftButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlphaPressed)
        delegate?.hudDidChangeTurningLeft(true)
    }

    @objc private func turnLeftUp() {
        turnLeftButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlpha)
        delegate?.hudDidChangeTurningLeft(false)
    }

    @objc private func turnRightDown() {
        turnRightButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlphaPressed)
        delegate?.hudDidChangeTurningRight(true)
    }

    @objc private func turnRightUp() {
        turnRightButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlpha)
        delegate?.hudDidChangeTurningRight(false)
    }

    @objc private func aimUpDown() {
        aimUpButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlphaPressed)
        delegate?.hudDidChangeAimingUp(true)
    }

    @objc private func aimUpUp() {
        aimUpButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlpha)
        delegate?.hudDidChangeAimingUp(false)
    }

    @objc private func aimDownDown() {
        aimDownButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlphaPressed)
        delegate?.hudDidChangeAimingDown(true)
    }

    @objc private func aimDownUp() {
        aimDownButton.backgroundColor = UIColor.white.withAlphaComponent(Self.controlAlpha)
        delegate?.hudDidChangeAimingDown(false)
    }

    @objc private func fireTapped() {
        delegate?.hudDidTapFire()
    }

    @objc private func cameraModeTapped() {
        delegate?.hudDidTapCameraModeCycle()
    }

    @objc private func replayTapped() {
        delegate?.hudDidTapReplay()
    }
}
