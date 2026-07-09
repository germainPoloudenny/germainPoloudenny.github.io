# AGENTS.md

Instructions locales pour `Portfolio`.

Ce fichier complete les regles communes definies dans `../AGENTS.md`. Appliquer
d'abord le socle parent, puis ces regles locales pour les fichiers de ce depot.

## Role Du Depot

- `Portfolio` est le site public principal publie via GitHub Pages.
- Les fichiers visibles du site doivent rester autonomes dans ce depot apres
  synchronisation: ne pas ajouter de dependance runtime vers un chemin local
  `../Ecrire` ou `../ReVillage`.
- Les chemins locaux vers `Ecrire` ou `ReVillage` servent seulement de sources
  pour les scripts de synchronisation.

## Publication Et Synchronisation

- Utiliser `gacp` pour publier le portfolio quand l'utilisateur demande commit
  et push depuis ce depot.
- `gacp` synchronise les assets publics necessaires depuis `Ecrire` et
  `ReVillage` avant de commit/push le portfolio.
- Ne pas pousser le depot `Ecrire` depuis un travail sur `Portfolio`.
- Ne pas publier le depot complet `ReVillage` depuis un travail sur `Portfolio`;
  seule la branche publique `public-visible` peut etre mise a jour par la
  synchronisation prevue.
- Quand un asset source garde le meme nom mais change de contenu, mettre a jour
  la reference publique avec un suffixe `?v=` derive du contenu pour eviter le
  cache navigateur.

## Contenu Public

- Les images, PDF et textes importes depuis d'autres depots doivent etre copies
  dans `Portfolio` avant publication.
- Les genres, titres, couvertures et liens visibles doivent venir des sources
  canoniques synchronisees.
- Quand un ecrit n'a pas encore de description source, afficher explicitement
  `En cours` dans la carte au lieu d'inventer une description.
- Pour les cartes projets, garder le texte lisible comme contenu normal; rendre
  cliquable seulement l'element demande par l'utilisateur quand il precise une
  cible comme un poster, une image ou un bouton.
- Ne pas ajouter une action qui depend d'un serveur local dans le site portfolio
  public.
