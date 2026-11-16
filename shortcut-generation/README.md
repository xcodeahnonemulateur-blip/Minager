# 🍎 Shortcut Génération 0.2 — Prototype public

**Projet expérimental** publié dans un dossier de la branche `shortcut-generation` du dépôt public `xcodeahnonemulateur-blip/Minager`. La branche principale `main` de Minager n'est pas modifiée.

> Ce dépôt n'est pas un nouveau dépôt indépendant. GitHub permet de lire les fichiers de cette branche sans connexion.

## Le défi : assembler des actions à partir d'une idée

Le catalogue `action-catalog.json` associe les actions logiques (par exemple `select_photo`) à leurs identifiants Apple, paramètres et sorties.

Le moteur `assemble.py` transforme une recette JSON en fichier .shortcut avec :
- sorties reliées aux entrées par UUID, y compris les champs de texte dynamique ;
- menus avec branches ;
- conditions « a une valeur », avec branche Sinon ;
- validation structurelle et détection de références inconnues ;
- compatibilité de schémas ciblée iOS 27 pour la reconnaissance du texte des photos.

### Démonstration « Centre de commandes iPhone »

Recette : `examples/centre-iphone.json`

Trois choix dans un menu :
1. **Lire le texte d'une photo :** Sélectionner une photo → Extraire texte → Si le texte existe → Afficher → Copier → Notifier.
2. **Archiver un document :** Sélectionner une photo → Créer PDF → Ouvrir le dialogue d'enregistrement.
3. **Créer un QR code :** Demander du texte → Générer QR code → Aperçu → Partager.

### Générer le fichier depuis Windows ou GitHub Actions

Depuis la racine du dépôt :

```sh
python shortcut-generation/assemble.py shortcut-generation/examples/centre-iphone.json -o centre-iphone.unsigned.shortcut
python -m unittest discover -s shortcut-generation/tests -v
```

Aucune API payante ou modèle à installer. La traduction d'une demande en français vers une recette JSON s'effectue actuellement via ChatGPT et le fichier `SKILL.md`.

### Intégrer une photo/logo fourni par l'utilisateur

```sh
python shortcut-generation/add_logo.py shortcut-generation/examples/centre-iphone.json chemin/mon-logo.png -o ma-recette-privee.json
python shortcut-generation/assemble.py ma-recette-privee.json -o centre-logo.unsigned.shortcut
```

Prend en charge un logo PNG/JPEG de 400 Ko au maximum. Le script crée une branche de menu « Afficher mon logo » avec image intégrée en Base64. Il ne publie pas automatiquement ton image.

**Important :** le logo intégré dans le contenu n'est pas automatiquement l'icône sur l'écran d'accueil. Apple permet de choisir la photo au moment d'ajouter le raccourci à l'écran d'accueil.

## État réel et limites

Le logiciel génère un **fichier .shortcut NON SIGNÉ**. Celui-ci ne peut PAS être importé directement dans Raccourcis sur un iPhone récent. La structure est testable localement mais aucun lancement sur iPhone n'a encore été validé. Les références et paramètres peuvent varier selon la version d'iOS.

Pour rendre le raccourci importable, il faut normalement un Mac connecté à iCloud et la commande officielle :

```sh
shortcuts sign --mode anyone --input centre-iphone.unsigned.shortcut --output centre-iphone.signed.shortcut
```

La signature ne publie pas un lien `icloud.com/shortcuts/...`, qui doit être généré depuis l'app Raccourcis. GitHub Actions seul ne garantit ni signature ni lien iCloud.

**Notre catalogue n'est pas exhaustif.** Apple ne publie pas de catalogue public stable avec tous les identifiants et paramètres d'actions. Les actions tierces changent selon les apps et les versions d'iOS.

Documentation utilisée :
- https://support.apple.com/guide/shortcuts/welcome/ios
- https://github.com/viticci/shortcuts-playground-plugin
- https://github.com/sebj/iOS-Shortcuts-Reference
- https://docs.scpl.dev/actions

## Sécurité

Le dépôt est public. Ne pas y ajouter de photos privées, de mots de passe, de comptes Apple ou de données iCloud. Les recettes générées avec logo personnel doivent rester locales sauf consentement explicite.


## Essai depuis un iPhone sans ordinateur : Cherri Playground

Une seconde implémentation expérimentale de la même démonstration se trouve dans `examples/centre-iphone.cherri`.

1. Ouvre https://github.com/xcodeahnonemulateur-blip/Minager/blob/shortcut-generation/shortcut-generation/examples/centre-iphone.cherri pour copier le code source.
2. Ouvre https://playground.cherrilang.org dans Safari, colle le code dans l'éditeur.
3. Lance la compilation avec le bouton marteau du Playground.
4. Si la compilation réussit, utilise Share / Sign pour demander la signature distante HubSign, puis télécharge le raccourci signé.
5. Dans Fichiers sur ton iPhone, ouvre le fichier signé, examine les blocs proposés et confirme son ajout dans Raccourcis.

Ceci est une **possibilité à tester**, pas un raccourci déjà signé. La signature dépend de la disponibilité et de l'acceptation du service externe HubSign. Ne colle pas de secrets, mots de passe, données personnelles ou images privées dans un service web sans vérifier leur traitement.

Documentation : https://cherrilang.org/faq.html et https://cherrilang.org/language/menus.html

