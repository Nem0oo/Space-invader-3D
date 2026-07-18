//
// LevelData.swift
//
// Parsing des vagues (formation, vitesse, fréquence de tir) depuis
// Resources/Assets/Levels/waveN.json. Au-delà des vagues fournies en JSON,
// une vague est dérivée par palier depuis la dernière définie.
//

import Foundation

struct WaveConfig: Codable {
    let waveIndex: Int
    let columns: Int
    let rows: Int
    let horizontalSpacing: Float
    let verticalSpacing: Float
    let startZ: Float
    let swayRange: Float
    let swaySpeed: Float
    let advanceSpeed: Float
    let alienScale: Float
    let alienTint: [Float]
    let minFireInterval: Float
    let maxFireInterval: Float
    let fireIntervalFloor: Float
}

enum LevelData {

    // Facteurs appliqués par palier au-delà de la dernière vague JSON bundlée.
    // À ajuster pour la courbe de difficulté finale.
    private static let speedGrowthPerExtraWave: Float = 1.08
    private static let fireRateGrowthPerExtraWave: Float = 0.92
    private static let bundledWaveCount = 3

    static func wave(for index: Int) -> WaveConfig {
        let clampedIndex = max(1, min(index, bundledWaveCount))
        guard let base = loadBundledWave(index: clampedIndex) else {
            return fallbackWave(index: index)
        }
        guard index > bundledWaveCount else { return base }

        let extraSteps = Float(index - bundledWaveCount)
        let speedFactor = pow(speedGrowthPerExtraWave, extraSteps)
        let fireFactor = pow(fireRateGrowthPerExtraWave, extraSteps)
        let extraRows = Int(extraSteps) / 2

        return WaveConfig(
            waveIndex: index,
            columns: base.columns,
            rows: min(base.rows + extraRows, 6),
            horizontalSpacing: base.horizontalSpacing,
            verticalSpacing: base.verticalSpacing,
            startZ: base.startZ,
            swayRange: base.swayRange,
            swaySpeed: base.swaySpeed * speedFactor,
            advanceSpeed: base.advanceSpeed * speedFactor,
            alienScale: base.alienScale,
            alienTint: base.alienTint,
            minFireInterval: max(base.minFireInterval * fireFactor, 0.35),
            maxFireInterval: max(base.maxFireInterval * fireFactor, 0.9),
            fireIntervalFloor: max(base.fireIntervalFloor * fireFactor, 0.2)
        )
    }

    private static func loadBundledWave(index: Int) -> WaveConfig? {
        guard let url = Bundle.main.url(forResource: "wave\(index)", withExtension: "json", subdirectory: "Assets/Levels") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WaveConfig.self, from: data)
    }

    // Filet de sécurité si les JSON de vague sont absents du bundle.
    private static func fallbackWave(index: Int) -> WaveConfig {
        WaveConfig(
            waveIndex: index, columns: 4, rows: 3,
            horizontalSpacing: 2.2, verticalSpacing: 1.6, startZ: -60,
            swayRange: 4.0, swaySpeed: 0.6, advanceSpeed: 1.4,
            alienScale: 1.0, alienTint: [0.35, 0.9, 0.45],
            minFireInterval: 1.8, maxFireInterval: 3.6, fireIntervalFloor: 0.6
        )
    }
}
