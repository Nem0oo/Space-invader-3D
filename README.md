# SpaceInvaders3D

Space Invaders en 3D pour iOS (SceneKit), compilé via Theos (pas Xcode). Le
joueur pilote un vaisseau à l'avant d'un espace ouvert ; les aliens avancent
en formation depuis le fond de la scène et grossissent naturellement avec la
perspective. Tir joueur manuel (un seul projectile actif à la fois), tirs
aliens automatiques à fréquence croissante à mesure que la vague se vide.

## Fonctionnalités

- Déplacement du vaisseau au joystick analogique (latéral + vertical, pour
  viser les différentes lignes de la formation), avec roulis/tangage lissés
  et caméra à lag plafonné
- Deux modes caméra (vue complète / vue partielle), cyclables en jeu
- Formation d'aliens en grille, tir automatique par colonne, cadence qui
  augmente quand il reste peu d'aliens vivants
- Score, vies, invincibilité courte après un hit, vagues progressives
  (JSON pour les 3 premières, générées par palier ensuite)
- Skybox en cube map + champ d'étoiles procédural (généré en code)
- Explosions en `SCNParticleSystem`

## Aperçu technique

| Fichier | Rôle |
|---|---|
| `AppDelegate.swift` | Point d'entrée UIKit, pas de storyboard |
| `GameViewController.swift` | Héberge le `SCNView`/`HUDOverlay`, boucle de jeu et collisions |
| `GameScene.swift` | Setup SceneKit : skybox, étoiles, éclairage, chargement des modèles `.obj` |
| `PlayerShipController.swift` | Mouvement du vaisseau (latéral/vertical, roulis/tangage) |
| `CameraRig.swift` | Rig caméra à 2 modes, suivi à écart plafonné |
| `AlienFormation.swift` | Spawn/mouvement/tir de la formation d'aliens |
| `ProjectileManager.swift` | Tirs joueur/alien et explosions |
| `HUDOverlay.swift` | Joystick, tir, cycle caméra, score/vies, écran de game over |
| `GameState.swift` | Score, vies, game over, progression des vagues |
| `LevelData.swift` | Parsing des vagues JSON (`Resources/Assets/Levels`) |

Les constantes de tuning (vitesses, angles, clamp caméra, cadences de tir)
sont regroupées en haut de chaque fichier concerné, pour ajustement facile
après test.

## Assets

`Resources/Assets/` : modèles `craft_speederA`/`craft_miner` en `.obj` + `.mtl`
(SceneKit ne charge pas fiablement le `.dae` d'origine sur device), skybox
(6 faces), texture d'explosion, et les JSON de vague sous `Levels/`.

## Prérequis

- [Theos](https://theos.dev/) installé et configuré (variable d'environnement `THEOS`)
- Un SDK/toolchain iOS compatible avec la cible du `Makefile` (déploiement iOS 15.5)
- Docker, pour compiler via l'image `nem0oo/theos` sans installation locale

## Compilation

```bash
docker run --rm -v ./:/home/builder/code -w /home/builder/code docker.io/nem0oo/theos make package PACKAGE_FORMAT=ipa
```

`make package` seul compile et génère le `.ipa`/`.deb` dans `packages/` ;
`make` seul compile sans empaqueter.

L'identifiant du bundle est `fr.gcourtot.spaceinvaders3d`.

## CI

- `.github/workflows/build.yml` : build de sideload (signature ldid, comme en local) à chaque push/tag `v*`, publie une Release GitHub avec l'IPA.
- `.github/workflows/appstore.yml` : publication App Store — Theos compile non signé, un job macOS signe avec un vrai certificat Apple Distribution et uploade vers App Store Connect/TestFlight. Déclenchement manuel uniquement. Voir [`APPSTORE_SETUP.md`](APPSTORE_SETUP.md) pour la mise en place (certificat, profil, clé API).

## Licence

Projet personnel, non destiné à une distribution publique.
