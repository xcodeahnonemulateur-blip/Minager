# Minage iPhone ⛏️

Application SwiftUI iOS 15+ expérimentale pour iPhone 7. Configuration de **Monero (XMR)** via une adresse publique Cake Wallet, ou **Duino-Coin (DUCO)**. Compilation avec GitHub Actions.

**Statut** : prototype. **Monero : adresse Cake Wallet prise en charge, moteur RandomX non implémenté, aucun XMR miné.** DUCO : moteur de minage expérimental non validé sur iPhone physique ni approuvé par le réseau. Les compilations produisent des IPA non signées, sans garantie de fonctionnement ni de revenus.

- [Code source et instructions](Minage-iPhone/README.md)
- [Application SwiftUI](Minage-iPhone/MinageApp)
- [Compilation IPA sur GitHub Actions](../../actions/workflows/build-minage-iphone.yml)

La compilation ne constitue pas une installation directe : l'IPA doit être signée sur le compte Apple de l'utilisateur, puis installée avec un outil compatible.

**Sécurité et réseau** : l'app est une expérimentation locale. Duino-Coin interdit certains clients non vérifiés ; obtenir l'autorisation du réseau avant de soumettre des parts sur un compte réel. Ne jamais saisir de phrase de récupération ni de mot de passe de portefeuille dans cette application.
