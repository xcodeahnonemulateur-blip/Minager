---
name: shortcut-generation
description: À utiliser pour transformer une idée de raccourci Apple en langage SGEN puis en fichier .shortcut non signé.
---

# Skill Shortcut Génération

Déclencheur: l'utilisateur demande « Crée-moi un raccourci Apple qui… ».

## Marche à suivre
1. Traduire la demande en langage SGEN, avec uniquement des instructions implémentées dans compile.py.
2. Si une action demandée n'est pas encore disponible, l'indiquer. Ne jamais inventer les paramètres des actions Apple.
3. Créer le fichier source .sgen dans shortcut-generation/examples ou dans un dossier de demandes.
4. Compiler avec Python standard : python shortcut-generation/compile.py source.sgen -o sortie.unsigned.shortcut
5. Vérifier le plist et lancer : python -m unittest discover -s shortcut-generation/tests -v
6. Ne jamais présenter le fichier comme installable sur iOS tant qu'il n'est pas signé.
7. Pour une signature réelle, utiliser sur un Mac connecté à iCloud :
   shortcuts sign --mode anyone --input sortie.unsigned.shortcut --output sortie.signed.shortcut
8. L'import du raccourci dans l'application Raccourcis doit être confirmé sur l'appareil.
9. Ne pas inventer de lien https://www.icloud.com/shortcuts/… : la création du lien demande un partage réel par Raccourcis.

## Langage SGEN
Une instruction par ligne, valeurs entre guillemets :
- NOM "Nom"
- TEXTE "Bonjour"
- AFFICHER
- AFFICHER "Autre texte"
- NOTIFIER "Titre" "Message"
- ALERTE "Titre" "Message"
- ACTION is.workflow.actions.showresult {"Text":"Bonjour"} (mode expert non vérifié)
- # Ceci est un commentaire.

## Limites
Aucune intelligence artificielle additionnelle dans le compilateur : ChatGPT traduit la phrase en SGEN.
SGEN v0.1 ne gère pas encore les conditions, variables, menus, déclencheurs ou toutes les actions d'applications.
Les fichiers sont NON SIGNÉS. Les runners GitHub Actions ne permettent pas de garantir la signature ni la création de liens iCloud.
