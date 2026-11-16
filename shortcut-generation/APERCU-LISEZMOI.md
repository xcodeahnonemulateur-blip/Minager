# Deux raccourcis Apple avec fenêtre intégrée (expérimental)

- `Banque Demo - Apercu.cherri` : présente le tableau de bord fictif via `showWebpage`.
- `Transfert Demo - Apercu.cherri` : présente le formulaire de transfert fictif via `showWebpage`.

Ils utilisent l'action native **Afficher la page web** (`is.workflow.actions.showwebpage`) qui ouvre une fenêtre `SFSafariViewController` depuis Raccourcis. Cela évite de basculer explicitement dans Safari, **mais ne cache pas nécessairement l'adresse ni les commandes de navigation**.

Les deux écrans utilisent le même site. Selon l'isolation des données iOS entre Safari, les fenêtres intégrées et les PWA, **on ne garantit pas** que les données locales soient partagées entre tous les contextes. Utiliser le même contexte d'ouverture pour tester.

Pour tester sans ordinateur : ouvrir https://playground.cherrilang.org/ sur iPhone, coller le contenu d'un fichier `.cherri`, compiler, puis essayer la signature et l'import. Une connexion réseau et un service de signature disponible sont nécessaires.

Pour une vue réellement sans barre de navigateur, passer par `Safari > Partager > Ajouter à l'écran d'accueil > Ouvrir comme une app`. L'installation comme web app conserve une interface de simulation explicite. Les raccourcis Apple ne peuvent pas imposer cette vue sans utiliser une vraie app native ou une PWA installée.

Nous n'avons pas encore testé ces fichiers compilés et signés sur iOS 27. Aucun raccourci iCloud n'est publié à ce stade. Ne demande jamais d'identifiants bancaires réels.
