//
// StereoView.swift
//
// Mode stéréogramme (vision parallèle) — EXPÉRIMENTAL (branche dédiée). Rend
// la même SCNScene depuis deux caméras légèrement décalées horizontalement
// (CameraRig.leftEyeCameraNode/rightEyeCameraNode), affichées dans deux
// petites vignettes rapprochées et centrées : en divergeant le regard (vision
// parallèle), le cerveau fusionne les deux images en une seule, en relief.
//
// Les contrôles interactifs (joystick, tir, boutons) restent sur le
// HUDOverlay normal en taille normale, pas dupliqués ici — seuls les
// éléments d'affichage passifs (viseur, score) sont dupliqués à l'identique
// sur chaque vignette, comme il est d'usage pour un HUD en rendu stéréo
// (ils apparaissent alors "à plat", au niveau de l'écran, une fois fusionnés).
//

import SceneKit
import UIKit

final class StereoView: UIView {

    // MARK: - Constantes ajustables (mise en page)

    /// Largeur de chaque vignette œil, en fraction de la largeur de la vue.
    static let eyeWidthFraction: CGFloat = 0.32
    /// Hauteur de chaque vignette œil, en fraction de la hauteur de la vue.
    static let eyeHeightFraction: CGFloat = 0.7
    /// Écart entre les deux vignettes — reste petit pour permettre la
    /// divergence oculaire en vision parallèle (rapprochées, pas plein écran).
    static let eyeGap: CGFloat = 10
    static let miniCrosshairSize: CGFloat = 18
    static let miniLabelFontSize: CGFloat = 11

    private let leftSceneView = SCNView()
    private let rightSceneView = SCNView()
    private let leftCrosshair = UIImageView()
    private let rightCrosshair = UIImageView()
    private let leftScoreLabel = UILabel()
    private let rightScoreLabel = UILabel()
    private let hintLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        // Aucune interaction ici : les contrôles restent sur le HUD principal.
        isUserInteractionEnabled = false

        for sceneView in [leftSceneView, rightSceneView] {
            sceneView.backgroundColor = .black
            sceneView.isUserInteractionEnabled = false
            addSubview(sceneView)
        }

        for crosshair in [leftCrosshair, rightCrosshair] {
            let config = UIImage.SymbolConfiguration(pointSize: Self.miniCrosshairSize * 0.8, weight: .light)
            crosshair.image = UIImage(systemName: "scope", withConfiguration: config)
            crosshair.tintColor = UIColor.white.withAlphaComponent(0.75)
            crosshair.contentMode = .scaleAspectFit
            addSubview(crosshair)
        }

        for label in [leftScoreLabel, rightScoreLabel] {
            label.font = .monospacedSystemFont(ofSize: Self.miniLabelFontSize, weight: .bold)
            label.textColor = .white
            label.textAlignment = .center
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOpacity = 0.8
            label.layer.shadowRadius = 1
            label.layer.shadowOffset = .zero
            addSubview(label)
        }

        hintLabel.text = "DIVERGE LE REGARD POUR FUSIONNER LES 2 IMAGES"
        hintLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        hintLabel.textAlignment = .center
        addSubview(hintLabel)

        updateScore(0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supporté") }

    func configure(scene: SCNScene, leftCamera: SCNNode, rightCamera: SCNNode) {
        leftSceneView.scene = scene
        leftSceneView.pointOfView = leftCamera
        rightSceneView.scene = scene
        rightSceneView.pointOfView = rightCamera
    }

    /// Piloté uniquement quand la vue est visible : les deux caméras œil
    /// n'ont besoin d'être rendues que si le mode stéréo est actif. La boucle
    /// de jeu elle-même reste pilotée par le SCNView principal, jamais mis en
    /// pause (voir GameViewController) — ce booléen ne fait qu'économiser du
    /// rendu GPU quand ces vignettes ne sont pas affichées.
    var isPlaying: Bool {
        get { leftSceneView.isPlaying }
        set {
            leftSceneView.isPlaying = newValue
            rightSceneView.isPlaying = newValue
        }
    }

    func updateScore(_ score: Int) {
        let text = String(format: "%04d", score)
        leftScoreLabel.text = text
        rightScoreLabel.text = text
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let eyeWidth = bounds.width * Self.eyeWidthFraction
        let eyeHeight = bounds.height * Self.eyeHeightFraction
        let totalWidth = eyeWidth * 2 + Self.eyeGap
        let originX = bounds.midX - totalWidth / 2
        let originY = bounds.midY - eyeHeight / 2

        leftSceneView.frame = CGRect(x: originX, y: originY, width: eyeWidth, height: eyeHeight)
        rightSceneView.frame = CGRect(x: originX + eyeWidth + Self.eyeGap, y: originY, width: eyeWidth, height: eyeHeight)

        leftCrosshair.frame = CGRect(
            x: leftSceneView.frame.midX - Self.miniCrosshairSize / 2,
            y: leftSceneView.frame.midY - Self.miniCrosshairSize / 2,
            width: Self.miniCrosshairSize, height: Self.miniCrosshairSize
        )
        rightCrosshair.frame = CGRect(
            x: rightSceneView.frame.midX - Self.miniCrosshairSize / 2,
            y: rightSceneView.frame.midY - Self.miniCrosshairSize / 2,
            width: Self.miniCrosshairSize, height: Self.miniCrosshairSize
        )

        leftScoreLabel.frame = CGRect(x: leftSceneView.frame.minX, y: leftSceneView.frame.minY - 20, width: eyeWidth, height: 16)
        rightScoreLabel.frame = CGRect(x: rightSceneView.frame.minX, y: rightSceneView.frame.minY - 20, width: eyeWidth, height: 16)

        hintLabel.frame = CGRect(x: 0, y: leftSceneView.frame.maxY + 16, width: bounds.width, height: 20)
    }
}
