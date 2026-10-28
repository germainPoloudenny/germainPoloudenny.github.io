# Publication des écrits

Les données du tome publié proviennent exclusivement de l’ouvrage Écrire dont
`.ecritoire-name.json` porte `publicationId: les-esclaves-tome-1`. Un renommage du
dossier, du livre ou de la saga ne change pas cet identifiant.

`sync_writing.py` lit le titre et le numéro de tome via les métadonnées canoniques
d’Écrire, le résumé depuis `text/input/4eme_de_couverture.txt`, la couverture et le
manuscrit complet. Il génère le PDF depuis ce manuscrit, sans réassembler ni
modifier le texte de l’auteur. Les exports PDF et EPUB utilisent les frontières
de sections de l’éditeur. Les anciennes URL publiques sont conservées pour les liens existants.

À l’ouverture d’Écrire, le client de bureau lance une vérification toutes les
30 secondes. Après stabilisation des fichiers, le PDF et les données modifiés
sont publiés automatiquement sur `origin/main` du portfolio. GitHub Pages doit
ensuite terminer son déploiement : ce n’est pas une diffusion instantanée.
Le manuscrit privé et les autres changements Git ne sont jamais indexés.

Une erreur réseau, des changements locaux étrangers ou une branche divergente
suspendent la publication et sont signalés dans les journaux du gestionnaire et
dans `.publication-state.json` (non versionné). Une nouvelle tentative a lieu au
passage suivant. Ne pas considérer l’état `generated` comme une publication.

Commandes manuelles :

```powershell
py -3 scripts/sync_writing.py           # génère localement seulement
py -3 scripts/sync_writing.py --check   # vérifie, sans modification
py -3 scripts/sync_writing.py --publish # génère si nécessaire puis publie
```
