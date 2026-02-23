# Dubuc & CO - Application Android

Application mobile pour la gestion des jobs de l'usine Dubuc & CO.

## Fonctionnalités

- **Scanner de codes-barres**
  - Scan de code job (6 chiffres, ex: `154595`)
  - Scan de code palette (3 lettres + tiret, ex: `DAN-12345`)
  
- **Consultation des jobs**
  - Liste des jobs en cours
  - Détails complets (essence, coupe, dimension, etc.)
  - Liste des palettes associées

- **Modification des quantités**
  - Ajustement (+/-) des quantités sur chaque palette
  - Synchronisation en temps réel avec le serveur

## Prérequis

- Flutter SDK 3.0+
- Android SDK
- Serveur API Dubuc

## Installation (Développement)

```bash
# Cloner le repo
git clone https://github.com/djmx3tr/DubucApp.git
cd DubucApp

# Installer les dépendances
flutter pub get

# Lancer l'app en mode debug
flutter run
```

## Build APK

### Localement

```bash
# APK Debug
flutter build apk --debug

# APK Release
flutter build apk --release
```

L'APK sera dans `build/app/outputs/flutter-apk/`

### Via GitHub Actions

1. Push sur la branche `main` → Build automatique
2. Créer un tag `v1.0.0` → Release automatique avec APK

## Configuration

Au premier lancement, configurez l'URL du serveur dans **Paramètres**.


## API Endpoints utilisés

| Endpoint | Description |
|----------|-------------|
| `GET /api/job/{id}` | Détails d'un job |
| `GET /api/palette/{id}` | Trouver job par palette |
| `GET /api/jobs/current` | Jobs en cours |
| `POST /api/quantity` | Modifier quantité |

## Structure du projet

```
lib/
├── main.dart           # Point d'entrée
├── models/
│   └── job.dart        # Modèles de données
├── screens/
│   ├── home_screen.dart       # Accueil + liste jobs
│   ├── scanner_screen.dart    # Scanner code-barres
│   ├── job_detail_screen.dart # Détails job + palettes
│   └── settings_screen.dart   # Paramètres
└── services/
    └── api_service.dart       # Appels API
```

## Licence

Propriétaire - Usine Dubuc & CO
