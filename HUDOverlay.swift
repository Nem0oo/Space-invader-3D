//
// HUDOverlay.swift
//
// Overlay tactile UIKit (pas de storyboard) : joystick analogique bas-gauche
// (mouvement latéral + vertical), tir bas-droit (tap), cycle caméra en haut,
// score/vies dans le coin opposé, écran de game over. Tout en code, layout à
// base de frames recalculé dans layoutSubviews (orientation landscape fixe).
//

import UIKit

protocol HUDOverlayDelegate: AnyObject {
    /// vector.dx/dy dans [-1, 1] : latéral (droite positif) / vertical (haut positif).
    func hudDidChangeMovementVector(_ vector: CGVector)
    func hudDidTapFire()
    func hudDidTapCameraModeCycle()
    func hudDidTapStereoToggle()
    func hudDidTapReplay()
}

final class HUDOverlay: UIView {

    // MARK: - Constantes ajustables (mise en page)

    static let joystickDiameter: CGFloat = 150
    static let fireButtonSize: CGFloat = 96
    static let cameraButtonSize: CGFloat = 56
    static let edgeMargin: CGFloat = 28
    static let controlAlpha: CGFloat = 0.32
    static let controlAlphaPressed: CGFloat = 0.55
    static let crosshairSize: CGFloat = 34

    weak var delegate: HUDOverlayDelegate?

    private let joystickView: JoystickView
    private let fireButton = UIButton(type: .custom)
    private let cameraModeButton = UIButton(type: .custom)
    private let cameraModeLabel = UILabel()
    private let stereoButton = UIButton(type: .custom)
    private let scoreLabel = UILabel()
    private let livesLabel = UILabel()
    private let crosshairView = UIImageView()

    private let debugLabel = UILabel()

    private let gameOverView = UIView()
    private let gameOverTitleLabel = UILabel()
    private let gameOverScoreLabel = UILabel()
    private let replayButton = UIButton(type: .system)

    override init(frame: CGRect) {
        joystickView = JoystickView(diameter: Self.joystickDiameter, alpha: Self.controlAlpha)
        super.init(frame: frame)
        backgroundColor = .clear
        setupCrosshair()
        setupJoystick()
        setupControls()
        setupHUDLabels()
        setupDebugLabel()
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

    private func setupJoystick() {
        joystickView.onVectorChanged = { [weak self] vector in
            self?.delegate?.hudDidChangeMovementVector(vector)
        }
        addSubview(joystickView)
    }

    private func setupControls() {
        styleControlButton(fireButton, systemImage: "bolt.fill", size: Self.fireButtonSize)
        styleControlButton(cameraModeButton, systemImage: "camera.rotate.fill", size: Self.cameraButtonSize)
        styleControlButton(stereoButton, systemImage: "rectangle.split.2x1.fill", size: Self.cameraButtonSize)

        fireButton.addTarget(self, action: #selector(fireTapped), for: .touchUpInside)
        cameraModeButton.addTarget(self, action: #selector(cameraModeTapped), for: .touchUpInside)
        stereoButton.addTarget(self, action: #selector(stereoTapped), for: .touchUpInside)

        addSubview(fireButton)
        addSubview(cameraModeButton)
        addSubview(stereoButton)

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

    /// Bandeau de diagnostic temporaire : affiche directement dans l'app la vraie
    /// erreur de chargement d'asset (voir GameScene.loadDiagnostics), pour ne pas
    /// dépendre d'un accès aux logs système selon l'outil de sideload utilisé.
    private func setupDebugLabel() {
        debugLabel.numberOfLines = 0
        debugLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        debugLabel.textColor = .white
        debugLabel.backgroundColor = UIColor.red.withAlphaComponent(0.55)
        debugLabel.textAlignment = .center
        debugLabel.isHidden = true
        addSubview(debugLabel)
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

        joystickView.center = CGPoint(
            x: Self.edgeMargin + Self.joystickDiameter / 2,
            y: bounds.maxY - Self.edgeMargin - Self.joystickDiameter / 2
        )

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

        // Sous le bouton/label caméra, expérimental (branche stéréogramme).
        stereoButton.center = CGPoint(
            x: bounds.maxX - Self.edgeMargin - Self.cameraButtonSize / 2,
            y: cameraModeLabel.frame.maxY + Self.edgeMargin / 2 + Self.cameraButtonSize / 2
        )

        scoreLabel.frame = CGRect(x: Self.edgeMargin, y: Self.edgeMargin, width: 200, height: 28)
        livesLabel.frame = CGRect(x: Self.edgeMargin, y: scoreLabel.frame.maxY + 4, width: 200, height: 24)

        // Sous le bandeau score/vies/caméra, au-dessus du joystick/viseur : évite tout chevauchement.
        debugLabel.frame = CGRect(x: 12, y: 128, width: bounds.width - 24, height: 90)

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

    /// Reflète l'état on/off du mode stéréogramme sur le bouton (c'est un
    /// bascule, pas une action ponctuelle — l'état visuel doit persister), et
    /// masque le viseur central (pertinent uniquement pour la vue simple
    /// plein écran — StereoView a ses propres petits viseurs par vignette).
    func setStereoActive(_ isActive: Bool) {
        stereoButton.backgroundColor = UIColor.white.withAlphaComponent(isActive ? Self.controlAlphaPressed : Self.controlAlpha)
        crosshairView.isHidden = isActive
    }

    func showGameOver(finalScore: Int) {
        gameOverScoreLabel.text = String(format: "SCORE FINAL : %04d", finalScore)
        gameOverView.isHidden = false
    }

    func hideGameOver() {
        gameOverView.isHidden = true
    }

    /// Affiche les diagnostics de chargement d'assets directement dans l'app.
    /// À retirer une fois le chargement des modèles fiabilisé.
    func showDebugMessages(_ messages: [String]) {
        guard !messages.isEmpty else {
            debugLabel.isHidden = true
            return
        }
        debugLabel.text = messages.joined(separator: "\n")
        debugLabel.isHidden = false
    }

    // MARK: - Actions

    @objc private func fireTapped() {
        delegate?.hudDidTapFire()
    }

    @objc private func cameraModeTapped() {
        delegate?.hudDidTapCameraModeCycle()
    }

    @objc private func stereoTapped() {
        delegate?.hudDidTapStereoToggle()
    }

    @objc private func replayTapped() {
        delegate?.hudDidTapReplay()
    }
}

/// Joystick virtuel : base fixe + poignée qui suit le doigt, plafonnée au rayon
/// de la base. Émet un vecteur normalisé [-1, 1] par axe à chaque déplacement,
/// (0, 0) au relâché. Écran → jeu : l'axe Y est inversé (UIKit vers le bas,
/// "haut" du joystick = valeur positive).
private final class JoystickView: UIView {

    var onVectorChanged: ((CGVector) -> Void)?

    private let knobView = UIView()
    private let radius: CGFloat
    private let restingAlpha: CGFloat

    init(diameter: CGFloat, alpha: CGFloat) {
        radius = diameter / 2
        restingAlpha = alpha
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))

        backgroundColor = UIColor.white.withAlphaComponent(alpha)
        layer.cornerRadius = radius
        isMultipleTouchEnabled = false

        let knobDiameter = diameter * 0.48
        knobView.frame = CGRect(
            x: (diameter - knobDiameter) / 2, y: (diameter - knobDiameter) / 2,
            width: knobDiameter, height: knobDiameter
        )
        knobView.backgroundColor = UIColor.white.withAlphaComponent(alpha + 0.3)
        knobView.layer.cornerRadius = knobDiameter / 2
        knobView.isUserInteractionEnabled = false
        addSubview(knobView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supporté") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        backgroundColor = UIColor.white.withAlphaComponent(restingAlpha + 0.1)
        updateKnob(touches: touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateKnob(touches: touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetKnob()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetKnob()
    }

    private func updateKnob(touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var dx = point.x - center.x
        var dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance > radius {
            dx *= radius / distance
            dy *= radius / distance
        }
        knobView.center = CGPoint(x: center.x + dx, y: center.y + dy)
        onVectorChanged?(CGVector(dx: dx / radius, dy: -dy / radius))
    }

    private func resetKnob() {
        backgroundColor = UIColor.white.withAlphaComponent(restingAlpha)
        knobView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        onVectorChanged?(.zero)
    }
}
