# Publication App Store — mise en place

Le workflow `.github/workflows/appstore.yml` compile avec Theos (non signé),
puis un job macOS signe avec un vrai certificat Apple et uploade vers App
Store Connect/TestFlight (upload seulement, pas de soumission automatique
pour App Review). Ce document liste tout ce qu'il faut créer côté Apple avant
de pouvoir le lancer, avec des commandes en ligne de commande (`openssl`)
utilisables sans Mac — seul le job de signature tourne sur macOS (runner
GitHub, pas ta machine).

**Prérequis** : un compte [Apple Developer Program](https://developer.apple.com/programs/) payant (99$/an), actif pour l'équipe qui possédera l'app.

## 1. App ID

Sur [developer.apple.com](https://developer.apple.com/account) → Certificates,
Identifiers & Profiles → Identifiers → **+** :
- Type : App IDs → App
- Bundle ID : **explicit**, `fr.gcourtot.spaceinvaders3d` (doit correspondre
  exactement à `CFBundleIdentifier` dans `Resources/Info.plist` et à `Package`
  dans `control`)
- Capabilities : aucune requise pour ce projet (pas de push, pas d'iCloud, etc.)

## 2. Certificat de distribution (`APPSTORE_CERTIFICATE_P12` / `APPSTORE_CERTIFICATE_PASSWORD` / `APPSTORE_SIGNING_IDENTITY`)

Génération de la clé privée + CSR en ligne de commande (fonctionne sur
Linux/Windows/macOS, pas besoin de Keychain Access) :

```bash
openssl genrsa -out appstore_distribution.key 2048
openssl req -new -key appstore_distribution.key -out appstore_distribution.csr \
  -subj "/emailAddress=TON_EMAIL/CN=TON_NOM/C=FR"
```

Puis sur developer.apple.com → Certificates → **+** → **Apple Distribution**
→ upload `appstore_distribution.csr` → télécharger le certificat généré
(`distribution.cer`).

Conversion et export en `.p12` (choisis un mot de passe, ce sera
`APPSTORE_CERTIFICATE_PASSWORD`) :

```bash
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
openssl pkcs12 -export \
  -out appstore_distribution.p12 \
  -inkey appstore_distribution.key \
  -in distribution.pem \
  -password pass:CHOISIS_UN_MOT_DE_PASSE
```

`APPSTORE_SIGNING_IDENTITY` est le nom complet de l'identité tel que macOS le
verra, généralement de la forme `Apple Distribution: Ton Nom (TEAMID)` — visible
sur la page du certificat dans developer.apple.com (colonne "Name"), ou en
inspectant le `.cer` :

```bash
openssl x509 -in distribution.cer -inform DER -noout -subject
```

## 3. Profil de provisioning App Store (`APPSTORE_PROVISIONING_PROFILE`)

developer.apple.com → Profiles → **+** → **App Store** (sous Distribution) →
sélectionner l'App ID `fr.gcourtot.spaceinvaders3d` → sélectionner le
certificat de distribution créé à l'étape 2 → générer → télécharger le
`.mobileprovision`.

## 4. Fiche app dans App Store Connect

[App Store Connect](https://appstoreconnect.apple.com) → My Apps → **+** →
New App :
- Bundle ID : `fr.gcourtot.spaceinvaders3d` (doit apparaître dans la liste,
  donc l'étape 1 doit être faite avant)
- SKU : libre, ex. `spaceinvaders3d`

C'est cette fiche qui reçoit les builds uploadés par le workflow — sans elle,
l'upload échoue.

## 5. Clé API App Store Connect (`APP_STORE_CONNECT_KEY_ID` / `APP_STORE_CONNECT_ISSUER_ID` / `APP_STORE_CONNECT_API_KEY`)

App Store Connect → Users and Access → **Integrations** → **Keys** → **+** :
- Rôle : *App Manager* suffit pour l'upload de builds
- Télécharger le `.p8` **immédiatement** — Apple ne permet de le télécharger
  qu'une seule fois
- `APP_STORE_CONNECT_KEY_ID` : la colonne "Key ID" de cette page
- `APP_STORE_CONNECT_ISSUER_ID` : affiché en haut de la page "Keys"

## 6. Encoder et ajouter les secrets GitHub

Repo GitHub → Settings → Secrets and variables → Actions → **New repository
secret**, un par ligne ci-dessous. Encodage base64 (le workflow décode côté
CI) :

```bash
base64 -w0 appstore_distribution.p12      # -> APPSTORE_CERTIFICATE_P12
base64 -w0 chemin/vers/profil.mobileprovision  # -> APPSTORE_PROVISIONING_PROFILE
base64 -w0 chemin/vers/AuthKey_XXXXXXXXXX.p8   # -> APP_STORE_CONNECT_API_KEY
```

(sur macOS, remplace `base64 -w0` par `base64 -i <fichier>`)

| Secret | Valeur |
|---|---|
| `APPSTORE_CERTIFICATE_P12` | `.p12` encodé en base64 (étape 2) |
| `APPSTORE_CERTIFICATE_PASSWORD` | Mot de passe choisi à l'export du `.p12` |
| `APPSTORE_SIGNING_IDENTITY` | Ex. `Apple Distribution: Ton Nom (TEAMID)` |
| `APPSTORE_PROVISIONING_PROFILE` | `.mobileprovision` encodé en base64 (étape 3) |
| `KEYCHAIN_PASSWORD` | N'importe quel mot de passe fort — sert uniquement au trousseau temporaire créé pendant le run CI |
| `APP_STORE_CONNECT_KEY_ID` | Étape 5 |
| `APP_STORE_CONNECT_ISSUER_ID` | Étape 5 |
| `APP_STORE_CONNECT_API_KEY` | `.p8` encodé en base64 (étape 5) |

## 7. Lancer le workflow

Repo GitHub → Actions → **App Store Release** → Run workflow → renseigner la
version (ex. `1.0.0`) → Run. Le numéro de build (`CFBundleVersion`) est
généré automatiquement à partir du numéro de run GitHub, donc toujours unique.

## Point bloquant connu : icône d'app manquante

Ce projet n'a pas d'icône d'app configurée (`Resources/Info.plist` n'a pas de
`CFBundleIconFile`, aucun asset d'icône dans `Resources/Assets/`) — c'était
volontaire pour un POC de sideload. **App Store Connect refusera le build**
sans icône (1024×1024 minimum, plus les tailles par appareil). Le pipeline CI
ci-dessus fonctionne mécaniquement sans, mais la validation Apple à l'upload
échouera tant qu'une vraie icône n'est pas ajoutée au projet.
