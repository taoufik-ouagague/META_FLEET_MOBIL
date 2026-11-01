# META_FLEET_MOBIL

Application mobile Flutter pour la gestion de flotte automobile (**Meta Fleet**), intégrant le suivi des véhicules, entretiens, vidanges, pneumatiques, ordres de réparation (OR), agenda et notifications push.

---

## 🚗 Fonctionnalités Principales

- **Authentification & Session** : Gestion de session utilisateur, tokens et profils avec GetX.
- **Tableau de Bord Flotte** : Indicateurs clés (véhicules en service, immobilisés, alertes d'entretien).
- **Gestion des Véhicules** : Fiches détaillées, affectations, kilométrage et historique.
- **Ordres de Réparation (OR) & Demandes** : Création, suivi, validation et clôture des interventions mécaniques.
- **Entretiens & Vidanges** : Suivi des échéances kilométriques et périodiques.
- **Pneumatiques** : État des pneus par essieu, permutation et remplacement.
- **Agenda & Planning** : Planification des visites techniques, contrôles et entretiens.
- **Journal & Historique** : Suivi chronologique de toutes les actions et événements de la flotte.
- **Messagerie / Chat & Notifications** : Messagerie d'équipe et alertes en temps réel via Firebase Cloud Messaging (FCM).

---

## 🏗️ Architecture & Technologies

- **Framework** : Flutter / Dart
- **Architecture & State Management** : [GetX](https://pub.dev/packages/get) (Controllers permanents, Navigation nommée, Injection de dépendances)
- **Réseau** : Client HTTP personnalisé (`ApiService`) avec logging et persistance des en-têtes
- **Notifications** : Firebase Cloud Messaging (`fcm_service.dart`)
- **Icônes & UI** : [Lucide Icons](https://pub.dev/packages/lucide_icons), [Cupertino Icons](https://pub.dev/packages/cupertino_icons) & [Google Fonts](https://pub.dev/packages/google_fonts) (Poppins)

---

## 📦 Installation & Démarrage

```bash
# Installer les dépendances
flutter pub get

# Lancer les tests
flutter test

# Exécuter l'application
flutter run
```

---

## 📄 Licence
Tous droits réservés.
