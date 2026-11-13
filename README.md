# Minage iPhone ⛏️

Application iOS 15+ expérimentale de minage Duino-Coin (DUCO-S1), adaptée à l'iPhone 7. Code source SwiftUI et compilation GitHub Actions.

**Statut** : prototype. La compilation GitHub Actions peut générer une IPA **non signée**, mais le fonctionnement du minage sur un iPhone 7 physique et l'obtention de récompenses ne sont pas encore validés. Aucune rentabilité n'est garantie.

- [Code source et instructions](Minage-iPhone/README.md)
- [Application SwiftUI](Minage-iPhone/MinageApp)
- [Compilation IPA sur GitHub Actions](../../actions/workflows/build-minage-iphone.yml)

La compilation ne constitue pas une installation directe : l'IPA doit être signée sur le compte Apple de l'utilisateur, puis installée avec un outil compatible.

**Sécurité et réseau** : l'app est une expérimentation locale. Duino-Coin interdit certains clients non vérifiés ; obtenir l'autorisation du réseau avant de soumettre des parts sur un compte réel. Ne jamais saisir de phrase de récupération ni de mot de passe de portefeuille dans cette application.
