# Minage iPhone : XMR sur iPhone 7 (iOS 15+)

**Statut : prototype compilable à tester sur un iPhone 7 physique, pas une source de revenus garantie.**

## Nouveau parcours : QR de Cake Wallet

1. Dans Cake Wallet, ouvrir le portefeuille **Monero XMR** puis **Receive / Recevoir** : il affiche l'adresse publique et un QR code.
2. Dans **Minage iPhone**, au premier démarrage, toucher **Scanner le QR code** et viser le code depuis **un deuxième écran**. Si tu utilises le même iPhone, sauvegarde une capture d'écran du QR puis touche **Importer une photo du QR**. La saisie de l'adresse publique reste possible.
3. Seules les adresses publiques XMR de 95 caractères sont acceptées. Les formats `monero:...` et `cakewallet:monero?address=...` sont pris en charge. Les QR de récupération, mots de passe et clés privées sont refusés.
4. L'adresse est conservée dans le trousseau de l'iPhone (Keychain). Une fois l'adresse enregistrée, l'app **essaie automatiquement** de lancer le minage, sans demander de confirmation supplémentaire, comme demandé par l'utilisateur. Le bouton **Arrêter** reste toujours disponible.
5. Le minage cesse dès que l'app passe en arrière-plan ou si l'iPhone surchauffe.

## Moteur de minage et sécurité

- Moteur CPU **RandomX light** : `256 MiB` pour le cache, VM interprétée, un seul worker, sans JIT ni dataset de 2 GiB, pauses pour limiter la chaleur ; versions `rx/0` et `rx/2` selon le travail du pool.
- Source : projet RandomX officiel `tevador/RandomX`, dépendance **BSD-3-Clause** clonée à une révision épinglée au moment du build. Sa licence est embarquée dans l'application. Voir `RandomXBridge.c` et `MoneroMineEngine.swift`.
- Pool expérimental : **HashVault** `pool.hashvault.pro:443`, Stratum JSON-RPC sur **TLS**, adresse publique XMR comme identifiant. Partages de calcul (`shares`) soumis via `submit` ; seuls les retours du serveur comptent pour les parts acceptées.
- Les calculs et la connexion Stratum sont codés et compilés, mais **aucune part acceptée sur un iPhone 7 physique n'a encore été démontrée**. Les performances et la compatibilité du protocole restent à valider sur matériel réel.
- Ne jamais laisser un iPhone 7 ancien charger et miner sans surveillance ; vérifier l'état et la température de la batterie. Aucune exécution en tâche de fond ni contournement d'iOS.
- Pas de pub, pas de code payant, pas de réseau tiers autre que le pool et l'API utilisée pour les statistiques.

## Onglet Transfert

Les XMR ne sont pas détenus par cette application. Les récompenses accumulées au pool sont versées à **la même adresse XMR qui a été scannée**, automatiquement lorsque les conditions de paiement du pool sont remplies.

- L'écran **Transfert** lit les seuils (`minimum`, `defaultWallet`) directement depuis `https://api.hashvault.pro/v3/monero` et essaie de lire les gains depuis l'API publique de statistiques associée à l'adresse.
- Le seuil minimum technique et le seuil configuré pour un portefeuille sont différents. Un solde absent de l'API n'est pas interprété comme `0`.
- Le bouton **Gérer le transfert sur HashVault** ouvre le site officiel du pool pour consulter les paiements et les réglages. **Il ne réalise pas une transaction Monero** : aucun endpoint public permettant de forcer un paiement à la demande n'a été confirmé. Ne pas donner une fausse confirmation de retrait.
- Cake Wallet reçoit les XMR sur l'adresse associée, quand le pool envoie réellement une transaction. Le compte Cake Wallet doit être synchronisé pour afficher les fonds.

## Compiler / installer depuis Windows

Un workflow GitHub Actions télécharge le code RandomX officiel épinglé, le compile pour iPhone arm64, génère le projet Xcode et produit une **IPA non signée**.

1. Sur le dépôt public `Minager`, ouvrir **Actions**, sélectionner `Minage iPhone - IPA (non signée)` et lancer le workflow si aucun build récent n'est disponible.
2. Si le workflow passe à l'état **Success**, télécharger l'artefact `Minage-iPhone-unsigned.zip` puis en extraire le fichier `.ipa`.
3. Sur un PC Windows, signer et installer l'IPA avec Sideloadly ou AltStore, depuis le site officiel de l'outil. Un compte Apple gratuit nécessite en général un renouvellement de la signature après **7 jours**.
4. Déverrouiller l'iPhone 7 et accorder l'accès à la caméra uniquement pour scanner le QR Monero si la fonction est utilisée.

**Ne pas présenter une IPA comme installable tant que la compilation Xcode n'a pas réussi.** La publication sur l'App Store est distincte, et Apple n'autorise pas le minage CPU directement sur l'appareil dans les apps distribuées via l'App Store.

## Références techniques

- https://github.com/tevador/RandomX (BSD-3-Clause)
- https://github.com/xmrig/xmrig-proxy/blob/master/doc/STRATUM.md
- https://hashvault.pro/monero/ports
- https://hashvault.pro/monero/api
- https://docs.cakewallet.com/faq/glossary/uri-scheme/


## Gains visibles et bouton « Envoyer »

La page principale affiche le **solde XMR réel en attente sur HashVault** lorsque l'API le fournit, avec une valeur approximative en euros si le cours EUR est disponible. Ne jamais inventer 0 XMR, des récompenses à partir du nombre de hachages, ni un succès de transfert.

L'onglet **Transfert** contient un bouton **« Envoyer vers Cake Wallet »** : cette version ne peut PAS envoyer les fonds en un clic, parce que l'API publique de HashVault ne documente aucun endpoint de paiement manuel. Le bouton actualise les informations et montre une alerte explicite. Les gains sont **versés automatiquement par HashVault** dès qu'ils sont éligibles selon le seuil et le traitement des paiements. Il faut éviter de tromper les utilisateurs avec un succès fictif.

API officielle : https://hashvault.pro/monero/api
