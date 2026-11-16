---
name: shortcut-generation
description: Assemble des raccourcis iPhone à partir d'une idée en français via un catalogue d'actions, une recette JSON, un compilateur Python et un contrôle de câblage.
---

# Skill Shortcut Génération 0.2 (iOS 27)

## Quand l'utiliser
L'utilisateur dit : « Crée un raccourci qui prend une photo, en récupère le texte, en fait un PDF, etc. »

## Processus
1. Décomposer la demande en actions Apple, données échangées et conditions.
2. Consulter action-catalog.json : chaque clé décrit l'identifiant Apple, les paramètres et le nom de la sortie.
3. Vérifier l'action et ses paramètres dans la documentation Apple et les schémas exportés de Shortcuts Playground (https://github.com/viticci/shortcuts-playground-plugin).
4. Ne pas inventer d'identifiants. Si une action manque, étendre le catalogue après vérification de son schéma.
5. Créer une recette JSON dans examples, sur le modèle de examples/centre-iphone.json.
6. Référencer les sorties avec {"ref":"nom"} et définir leur nom avec "as".
7. Compiler : python shortcut-generation/assemble.py shortcut-generation/examples/centre-iphone.json -o centre-iphone.unsigned.shortcut
8. Tester : python -m unittest discover -s shortcut-generation/tests -v
9. Examiner les blocs et les références; sur iPhone iOS 27 il faut ensuite tester réellement les paramètres et les autorisations.
10. NE PAS prétendre que le raccourci est prêt à être importé : le compilateur produit uniquement un plist NON SIGNÉ.
11. Un Mac connecté à iCloud est normalement requis pour la signature Apple : shortcuts sign --mode anyone --input SOURCE.shortcut --output FINAL.shortcut.
12. Le lien iCloud ne se génère pas automatiquement depuis le serveur GitHub et l'import demande confirmation sur l'iPhone.

## Syntaxe de la recette
- {"action":"select_photo","as":"p"}
- {"action":"extract_text","as":"ocr","params":{"source":{"ref":"p"}}}
- {"if_present":{"ref":"ocr","then":[...],"else":[...]}}
- {"menu":{"prompt":"Choisis","cases":[{"title":"Choix 1","actions":[...]},{"title":"Choix 2","actions":[...]}]}}
- Ne pas référencer une action produite plus loin dans le fichier.

## Images et logos
Une photo fournie par l'utilisateur peut être embarquée sous forme Base64 dans un raccourci :
python shortcut-generation/add_logo.py shortcut-generation/examples/centre-iphone.json logo.png -o ma-recette-privee.json
python shortcut-generation/assemble.py ma-recette-privee.json -o mon-raccourci.unsigned.shortcut

Cette opération n'a PAS été testée sur un iPhone réel. La photo devient une action Text + Decode Base64 + Quick Look, pas l'icône native du raccourci.
Pour afficher une photo comme icône sur l'écran d'accueil, l'utilisateur choisit son image dans Raccourcis > Ajouter à l'écran d'accueil.
Ne jamais publier d'image personnelle dans le dépôt GitHub sans accord explicite.

## Périmètre
Le catalogue actuel est partiel. Apple n'expose pas une API officielle documentée pour décrire toutes les actions iOS et leurs schémas. Les métadonnées ToolKit peuvent différer selon la version iOS et les apps installées. Les tests Python valident la structure, PAS l'exécution réelle sur iPhone.
