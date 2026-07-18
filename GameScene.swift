//
// GameScene.swift
//
// Mise en place SceneKit : skybox, champ d'étoiles procédural, éclairage,
// chargement des modèles .dae et hiérarchie de base de la scène. Ne contient
// aucune logique de jeu (déléguée à PlayerShipController/CameraRig/
// AlienFormation/ProjectileManager/GameState).
//

import SceneKit
import UIKit

final class GameScene {

    // MARK: - Constantes ajustables

    static let starfieldBirthRate: CGFloat = 700
    static let starfieldRadius: CGFloat = 220
    static let starfieldParticleSize: CGFloat = 0.35
    static let shipStartPosition = SCNVector3(0, 0, 0)

    let scene = SCNScene()
    let cameraRig = CameraRig()
    /// Parent commun des aliens, projectiles et explosions.
    let playfieldNode = SCNNode()
    let shipNode: SCNNode

    private let alienTemplateNode: SCNNode
    var alienTemplate: SCNNode { alienTemplateNode }

    init() {
        shipNode = GameScene.loadModelNode(named: "craft_speederA")
        alienTemplateNode = GameScene.loadModelNode(named: "craft_miner")

        shipNode.position = Self.shipStartPosition

        scene.rootNode.addChildNode(playfieldNode)
        scene.rootNode.addChildNode(shipNode)
        scene.rootNode.addChildNode(cameraRig.cameraNode)

        setupBackground()
        setupLighting()
        setupStarfield()
    }

    private func setupBackground() {
        // Ordre requis par SCNScene.background.contents : [+X, -X, +Y, -Y, +Z, -Z]
        let faces = ["skybox_px", "skybox_nx", "skybox_py", "skybox_ny", "skybox_pz", "skybox_nz"]
        let images = faces.compactMap { name -> UIImage? in
            guard let url = Bundle.assetURL(name, withExtension: "png") else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
        if images.count == 6 {
            scene.background.contents = images
        }
    }

    private func setupLighting() {
        let ambientNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.35, alpha: 1)
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let keyNode = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.color = UIColor(white: 1.0, alpha: 1)
        keyLight.intensity = 900
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyNode)
    }

    private func setupStarfield() {
        let system = SCNParticleSystem()
        system.birthRate = Self.starfieldBirthRate
        system.particleLifeSpan = 30
        system.particleLifeSpanVariation = 5
        system.particleSize = Self.starfieldParticleSize
        system.particleSizeVariation = Self.starfieldParticleSize * 0.5
        system.particleColor = .white
        system.particleVelocity = 0
        system.emitterShape = SCNSphere(radius: Self.starfieldRadius)
        system.birthLocation = .volume
        system.loops = true
        system.isLightingEnabled = false
        system.blendMode = .additive
        system.particleImage = GameScene.generateStarParticleImage()

        let node = SCNNode()
        node.addParticleSystem(system)
        scene.rootNode.addChildNode(node)
    }

    /// Point blanc simple généré en code (pas d'asset externe pour le champ d'étoiles).
    private static func generateStarParticleImage() -> UIImage {
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func loadModelNode(named name: String) -> SCNNode {
        guard let url = Bundle.assetURL(name, withExtension: "dae") else {
            print("⚠️ SpaceInvaders3D: \(name).dae introuvable dans le bundle (Assets/)")
            return placeholderNode()
        }
        do {
            let source = try SCNScene(url: url, options: [.checkConsistency: true])
            let node = source.rootNode.clone()
            // Certains exports .dae ont un winding order inversé : sans double-face,
            // SceneKit peut culler la totalité des triangles et rendre le modèle invisible
            // tout en le gardant fonctionnellement en place (transform/collisions correctes).
            node.enumerateHierarchy { child, _ in
                child.geometry?.materials.forEach { $0.isDoubleSided = true }
            }
            return node
        } catch {
            print("⚠️ SpaceInvaders3D: échec de chargement de \(name).dae : \(error)")
            return placeholderNode()
        }
    }

    /// Repère visuel volontairement voyant : si un modèle ne charge pas, ça doit se voir
    /// (plutôt qu'un nœud vide invisible qui masque complètement le problème).
    private static func placeholderNode() -> SCNNode {
        let box = SCNBox(width: 1, height: 0.4, length: 1.6, chamferRadius: 0.05)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.magenta
        material.emission.contents = UIColor.magenta
        material.isDoubleSided = true
        box.materials = [material]
        return SCNNode(geometry: box)
    }
}

extension Bundle {
    /// Les fichiers de Resources/Assets sont copiés à plat sous Assets/ à la racine du bundle par Theos.
    static func assetURL(_ name: String, withExtension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Assets")
    }
}
