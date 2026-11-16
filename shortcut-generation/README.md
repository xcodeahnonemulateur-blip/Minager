# 🍎 Shortcut Génération (prototype public)

**Accès public sans compte GitHub :** ce dossier est publié dans la branche `shortcut-generation` du dépôt public `xcodeahnonemulateur-blip/Minager`. Le dépôt principal `Minager` n'a pas été modifié sur sa branche `main`.

Ce n'est **pas un nouveau dépôt indépendant**. C'est un espace public séparé à l'intérieur d'un dépôt existant.

## Concept

Écrire une idée de raccourci Apple, la traduire en langage simple **SGEN**, puis compiler un fichier `.shortcut`.

Exemple dans `examples/bonjour.sgen` :

```text
NOM "Mon premier raccourci"
TEXTE "Bonjour depuis Shortcut Génération !"
AFFICHER
NOTIFIER "Shortcut Génération" "Exemple de notification."
```

## Compiler (Python standard, sans abonnement)

```sh
python shortcut-generation/compile.py shortcut-generation/examples/bonjour.sgen -o bonjour.unsigned.shortcut
python -m unittest discover -s shortcut-generation/tests -v
```

- `compile.py` : compilateur expérimental
- `SKILL.md` : directives pour ChatGPT/Codex
- `examples/` : exemples
- `tests/` : tests
- `.github/workflows/shortcut-generation.yml` : compilation GitHub Actions (disponibilité des exécutions à vérifier)

## ⚠️ Limites actuelles

**Ce prototype n'est pas encore un générateur de liens iCloud installables.**

Les fichiers créés sont **non signés**. Ils ne sont donc pas directement importables sur un iPhone récent. Pour signer sur un Mac connecté à iCloud :

```sh
shortcuts sign --mode anyone --input bonjour.unsigned.shortcut --output bonjour.signed.shortcut
```

La signature ne crée pas automatiquement un lien `icloud.com/shortcuts/...`. Ce lien doit être partagé depuis l'application Raccourcis, car Apple ne documente pas d'API publique de publication.

Le langage ne prend en charge que quelques actions au départ : texte, affichage, notification, alerte et une instruction experte générique. Les déclencheurs, menus, boucles, variables et actions de nombreuses applications restent à développer.

Ne mettez jamais des identifiants Apple, secrets ou fichiers privés dans ce dépôt public.
