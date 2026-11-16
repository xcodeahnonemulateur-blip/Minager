# Shortcut Génération 🍎

Prototype d'un générateur de raccourcis Apple en langage SGEN, hébergé dans une branche indépendante du dépôt privé X-code. sur le deuxième compte GitHub.

Ce projet ne modifie pas la branche main de X-code.

## But
Tu décris ton idée à ChatGPT. Le skill Shortcut Génération traduit l'idée en petits ordres SGEN.
Le compilateur Python convertit ces ordres en un vrai fichier plist au format .shortcut.

Exemple :
NOM "Mon premier raccourci"
TEXTE "Bonjour !"
AFFICHER
NOTIFIER "Essai" "Tout va bien"

## Tester le compilateur
Windows, Linux ou macOS avec Python 3.10+.
Commande depuis la racine du dépôt :

    python shortcut-generation/compile.py shortcut-generation/examples/bonjour.sgen -o bonjour.unsigned.shortcut
    python -m unittest discover -s shortcut-generation/tests -v

Aucun abonnement ni service IA tiers requis pour compiler.

## Fonctionnement dans GitHub Actions
Le fichier .github/workflows/shortcut-generation.yml lance les tests et génère deux exemples.
Tu peux retrouver les fichiers dans l'artefact shortcuts-unsigned du workflow (si Actions est activé).

## Attention : blocage Apple
Les fichiers créés ici sont NON SIGNÉS. Ils ne sont pas directement importables dans l'application Raccourcis sur les iPhone modernes.

Pour signer un fichier, il faut un Mac qui dispose de l'outil Apple shortcuts et d'une session iCloud connectée :

    shortcuts sign --mode anyone --input bonjour.unsigned.shortcut --output bonjour.signed.shortcut

Les machines temporaires de GitHub Actions n'ont normalement pas de session iCloud connectée, et la commande de signature ne peut donc pas être considérée comme une solution cloud garantie.

La signature du fichier n'est PAS la création d'un lien iCloud. Le lien public se crée normalement dans l'application Raccourcis via Partager > Copier le lien iCloud. Apple ne documente pas d'API publique pour publier ces liens.

N'entre jamais ton mot de passe Apple dans le dépôt ni dans le code d'un workflow.

## Catalogue
SGEN 0.1 gère TEXTE, AFFICHER, NOTIFIER, ALERTE et ACTION en mode expert. Le catalogue complet des actions Apple et les conditions restent à développer. Nous ne prétendons pas prendre en charge toutes les actions d'iOS.

## Suite du projet
Ajouter le support de variables, conditions, menus, répétitions, catalogues versionnés iOS et tests sur iPhone.
Pour un vrai partage automatisé, envisager ultérieurement un Mac personnel connecté à iCloud, avec accès sécurisé.
