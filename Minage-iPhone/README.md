# Minage iPhone • expérimentation iOS 15

Une application SwiftUI destinée à l'iPhone 7 (A10 Fusion) et à iOS 15+.

## Monero dans Cake Wallet (nouveau)

Le projet propose désormais, au premier lancement, le choix **Monero (XMR)** compatible avec le portefeuille Cake Wallet, ou **Duino-Coin (DUCO)**. Pour XMR, aller dans Cake Wallet → Monero → Receive et copier l'**adresse publique XMR** (95 caractères, commençant par 4 ou 8). L'application n'enregistre que l'adresse, jamais une phrase de récupération ni un mot de passe.

**Important : le minage Monero n'est PAS implémenté dans ce projet.** L'interface permet d'associer une adresse XMR, mais **aucun XMR n'est miné ni transféré** ; le bouton de minage XMR n'existe pas. Il faudra écrire/intégrer un moteur **RandomX en mode light** compatible iOS, valider les performances et le protocole d'un pool réel, puis tester sur iPhone 7.

L'iPhone 7 dispose de 2 Go RAM. RandomX fast demande ~2080 MiB, RandomX light 256 MiB mais est très lent, et la rentabilité pourrait être inférieure aux frais d'électricité. Aucun revenu ni délai de paiement garanti.

Sources : https://cakewallet.com/ , https://github.com/tevador/RandomX et https://docs.cakewallet.com/cryptos/monero/

## Statut honnête

**Prototype de minage DUCO-S1 (SHA-1), non encore validé sur un iPhone 7 physique.**
Le code effectue réellement le hachage et essaie de soumettre les parts au pool officiel Duino-Coin. La compatibilité du protocole doit être confirmée lors d'un premier lancement.
Aucun gain en euros n'est promis ou simulé. L'App n'affiche **pas de faux solde**.

## Portefeuille et gains

1. Ouvrir https://wallet.duinocoin.com/ (site officiel).
2. Créer un compte ou se connecter selon les conditions du service.
3. À la première ouverture, saisir le **nom d'utilisateur DUCO** et la **Mining key** si elle est activée. Appuyer sur « Continuer ». Ces deux valeurs sont conservées localement dans le trousseau iOS (Keychain), jamais dans GitHub. Le bouton « Changer » efface l'association locale.
4. Démarrer l'app **au premier plan**. Les gains éventuels sont crédités au compte DUCO par le réseau, pas à Cake Wallet.
5. Consulter le solde et les options de transfert/conversion sur le site officiel. Les frais, seuils, liquidité et conditions d'âge peuvent empêcher la conversion en EUR.

**Ne jamais inscrire une phrase de récupération de portefeuille dans l'application.**

## Connexion au démarrage

Un écran d'accueil élégant demande le nom d'utilisateur du **portefeuille Duino-Coin**, plus une **Mining key facultative**. Il ne demande **jamais** le mot de passe du wallet, sa phrase de récupération, ni une carte d'identité. Le terme « connexion » signifie **configurer l'identifiant destinataire** : l'application ne se connecte pas au compte Duino-Coin avec un mot de passe et ne vérifie pas l'identité du détenteur. L'utilisateur peut changer de profil dans le tableau de bord. Le minage ne commence pas automatiquement.

> La Mining key doit être celle configurée dans wallet.duinocoin.com ; elle est différente du mot de passe du portefeuille.

## Construire sans Mac

Dans le dépôt GitHub public Minager, ouvrir **Actions > Minage iPhone - IPA (non signée) > Run workflow**.
Le workflow génère un artefact `Minage-iPhone-unsigned.ipa` grâce à XcodeGen et `xcodebuild` sous macOS.
Sur Windows, installer cet IPA avec Sideloadly ou AltStore et son propre identifiant Apple. Une signature gratuite doit être renouvelée tous les 7 jours. Le dépôt est public, et le workflow ne transmet aucune clé Apple.

## Technique

- Cible : iOS 15+, SwiftUI, CryptoKit, Network.framework
- Algorithme : DUCO-S1, SHA-1 du précédent hash concaténé au nonce décimal (selon le mineur officiel)
- Pool : `https://server.duinocoin.com/getPool`
- Protocole : `JOB,username,MEDIUM,key,` puis `nonce,hashrate,minerName,identifier,,sessionID`
- Une seule tâche CPU à la fois, pauses de refroidissement, arrêt sur état thermique sérieux ou critique
- Arrêt à la mise en arrière-plan : iOS ne garantit pas l'exécution continuelle sans premier plan
- Aucun suivi analytique, publicité, abonnement, API payante ou clé privée dans l'app

## Conditions du réseau : important avant utilisation

Les conditions Duino-Coin du 11 janvier 2026 indiquent que les programmes miniers communautaires non vérifiés peuvent entraîner un **blocage de compte**. Ce projet iOS est expérimental et **n'est pas validé par l'équipe Duino-Coin**. Faire approuver ou vérifier le logiciel auprès du réseau avant de soumettre des parts avec son compte réel : https://duinocoin.com/terms

Le compte DUCO demande une adresse e-mail. Pour envoyer les DUCO ou en demander l'échange, une vérification est obligatoire : photo du matériel minier et d'un papier indiquant l'identifiant et la date. La page officielle explique qu'elle ne requiert pas de carte d'identité ni de photo du visage : https://server.duinocoin.com/verify.html

## Limites

DUCO est une monnaie expérimentale et centralisée. Les frais de retrait/conversion peuvent dépasser les gains d'un téléphone aussi ancien. Ce dépôt **ne doit pas** être présenté comme une source de revenu fiable. Un usage intensif peut accélérer l'usure de la batterie ; ne pas laisser le téléphone charger sous une couverture ou sans surveillance. Apple's App Store interdit le minage on-device dans les applications distribuées sur sa boutique ; le projet cible une installation personnelle de test.

Sources : https://github.com/duino-coin/duino-coin et https://developer.apple.com/app-store/review/guidelines/
