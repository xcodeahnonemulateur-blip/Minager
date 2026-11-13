# Minager · iPhone 7 · Monero XMR

Application iOS 15+ open-source expérimentale pour l'iPhone 7 : associe ton portefeuille **Cake Wallet** via son QR code Monero, puis **tente un minage CPU RandomX light** tant que l'app est au premier plan.

**Ce projet n'est pas un portefeuille, un service financier, ou une promesse de gains.** L'IPA et le minage doivent encore être validés sur un appareil réel.

- Scanner caméra ou importer une capture du QR si Cake Wallet est sur le même téléphone ; jamais besoin de dévoiler les mots secrets.
- Démarrage après association du QR, statistiques de calcul / parts reçues du pool, arrêt manuel et surveillance thermique.
- Onglets **Minage**, **Transfert**, **Réglages**.
- L'onglet **Transfert** affiche les seuils officiels de HashVault. Les versements sont faits par le pool après seuil, **pas par l'app** ; pas de fausse transaction.
- Compilation automatique macOS par GitHub Actions, puis signature personnelle sous Windows. Pas d'Apple Developer payant requis pour le test de 7 jours.

[Instructions détaillées](Minage-iPhone/README.md) · [Code Swift de l'app](Minage-iPhone/MinageApp) · [Compiler une IPA](../../actions/workflows/build-minage-iphone.yml)
