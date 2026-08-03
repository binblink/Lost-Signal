# Composants tiers et état des droits

Inventaire vérifié le 2 août 2026.

> **À finaliser avant commercialisation :** remplacez l’icône Godot utilisée comme placeholder et la musique Pixabay temporaire, renseignez l’identité du titulaire, puis documentez le modèle ayant généré les images. Ce document doit être mis à jour à chaque ajout, remplacement ou suppression de dépendance ou d’asset.

Ce fichier recense les composants tiers détectés dans le dépôt du Lost Signal Narrative Framework. Il ne remplace pas les textes de licence originaux.

## 1. Godot Engine

Le Framework est conçu pour **Godot Engine 4.7.1**.

Godot Engine est distribué sous licence MIT :

```text
Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

-- Godot Engine <https://godotengine.org>
```

Sources officielles :

- licence : <https://godotengine.org/license/> ;
- code source : <https://github.com/godotengine/godot>.

### Obligations lors de l’export

Un Jeu exporté avec Godot redistribue le binaire du moteur. La notice de copyright et la licence MIT de Godot doivent donc être incluses dans la documentation, les crédits ou les notices légales du Jeu.

Godot intègre également des bibliothèques tierces. Lors de la préparation d’une distribution, consultez les fichiers `COPYRIGHT.txt` et les notices correspondant exactement à la version du modèle d’export utilisée.

## 2. Icône Godot utilisée comme placeholder

Fichier concerné :

- `icon.svg`

Ce fichier contient l’icône de Godot Engine dans une composition dérivée du visuel par défaut. Les logos et icônes officiels de Godot sont annoncés sous licence **Creative Commons Attribution 4.0 International (CC BY 4.0)**.

Sources :

- kit de presse et règles d’utilisation : <https://godotengine.org/press/> ;
- licence CC BY 4.0 : <https://creativecommons.org/licenses/by/4.0/>.

Les règles de marque de Godot indiquent que le logo et l’icône doivent représenter Godot Engine et non servir d’identité à un autre projet. L’icône actuelle est donc un **placeholder à remplacer avant toute commercialisation ou publication de Maeve — Lost Signal ou d’un Jeu créé avec le Framework**.

## 3. Musique Pixabay temporaire

Fichier concerné :

- `assets/music/leberch-history-ambient-375201.mp3`

Informations identifiées :

- titre : **History Ambient** ;
- auteur/contributeur : **leberch** ;
- identifiant Pixabay : **375201** ;
- date de publication indiquée par Pixabay : 16 juillet 2025 ;
- page source : <https://pixabay.com/music/modern-classical-history-ambient-375201/> ;
- licence annoncée : **Pixabay Content License** ;
- résumé de licence : <https://pixabay.com/service/license-summary/>.

Pixabay autorise notamment l’utilisation et l’adaptation du contenu, y compris dans certaines œuvres commerciales, mais interdit sa vente ou sa distribution autonome et signale que des droits supplémentaires peuvent s’appliquer. La page de la piste indique également un enregistrement Content ID.

### Politique du Framework

Cette piste est un média temporaire de démonstration. Elle n’est pas accordée aux acheteurs comme asset réutilisable par la licence du Framework et doit être remplacée avant la publication d’un Jeu.

Une personne souhaitant malgré tout l’utiliser doit l’obtenir directement depuis Pixabay, accepter la licence Pixabay applicable au moment du téléchargement, conserver la preuve de téléchargement ou le certificat disponible et assumer la vérification des droits et risques de Content ID.

## 4. Média audio original du Concédant

Fichier concerné :

- `assets/sounds/Splorch.mp3`

Déclaration du Concédant : ce morceau est une création originale de Benjamin Sotier et aucun média audio tiers n’y est incorporé.

Copyright © 2026 Benjamin Sotier. Tous droits réservés.

Ce fichier appartient au Contenu de démonstration. Il peut être écouté et utilisé localement pour apprendre à manipuler les messages audio, mais la licence du Framework n’autorise pas sa réutilisation dans un Jeu publié.

Avant publication, confirmez par écrit dans les archives de propriété intellectuelle :

- le nom légal de l’auteur et du titulaire ;
- la date de création ;
- les éventuels logiciels, banques de sons ou collaborateurs utilisés ;
- le cas échéant, les licences de toute composante incorporée.

## 5. Images et avatars générés localement par IA

Fichiers concernés :

```text
assets/avatars/maeve.png
assets/avatars/mom.png
assets/avatars/salesman.png
assets/images/maeve_pic_1.jpg
assets/images/mave_lost_signal_icon.png
```

Déclaration du Concédant : ces images ont été générées localement au moyen d’un système d’intelligence artificielle, sous la direction de Benjamin Sotier. Aucun fichier image provenant d’une banque d’assets tierce n’a été incorporé directement.

**Statut dans le produit : contenu de démonstration non redistribuable.** Ces fichiers servent exclusivement à illustrer le fonctionnement des avatars, images de conversation et éléments visuels de la démonstration.

La qualification juridique des contenus générés par IA et les droits résultant de leur génération peuvent dépendre du modèle, de ses données, de ses conditions d’utilisation et de l’intervention humaine. Avant publication, conservez pour chaque série d’images :

- le nom et la version du logiciel de génération ;
- le nom exact du modèle ou checkpoint et sa source ;
- la licence du logiciel et du modèle au moment de la génération ;
- la date de génération ;
- les prompts, réglages et principales étapes de retouche humaine ;
- une confirmation qu’aucune image source non autorisée, personne réelle reconnaissable, marque ou personnage protégé n’a été demandé ou incorporé ;
- les fichiers de travail permettant de retracer le processus créatif.

La présence de contenu généré par IA doit être déclarée sur itch.io au moyen du champ **AI Disclosure**, conformément aux [règles de qualité de la plateforme](https://itch.io/docs/creators/quality-guidelines).

## 6. Polices système

Le code référence des familles de polices installées par le système, notamment :

```text
Segoe UI Emoji
Apple Color Emoji
Noto Color Emoji
Consolas
Courier New
DejaVu Sans Mono
Liberation Mono
```

Ces polices ne sont pas présentes comme fichiers dans le dépôt au moment de l’inventaire. Elles sont demandées via `SystemFont` et restent fournies, lorsqu’elles existent, par le système de l’utilisateur.

Ne copiez et ne distribuez aucun fichier de police provenant d’un système d’exploitation sans vérifier séparément sa licence. Si une police doit être embarquée ultérieurement, ajoutez son fichier de licence et son attribution à ce document.

## 7. Addons et code du dépôt

L’inventaire n’a détecté aucun addon tiers accompagné de sa propre licence dans `addons/`. Le plugin `addons/story_editor/` est actuellement traité comme un composant original du Framework.

Cette constatation doit être confirmée par le titulaire avant publication. Tout extrait de code, shader, script ou ressource provenant d’un tiers doit être ajouté à cet inventaire avec sa licence complète.

## 8. Tableau de validation avant sortie

| Élément | Statut actuel | Action requise |
|---|---|---|
| Godot Engine | Licence identifiée | Inclure la notice MIT dans les Jeux exportés |
| `icon.svg` | Origine identifiée, usage inadapté comme icône du Jeu | Remplacer avant publication |
| Musique `History Ambient` | Source et licence identifiées, média temporaire | Remplacer ou acquérir directement et documenter séparément |
| `Splorch.mp3` | Création originale déclarée par le Concédant | Compléter l’identité et archiver la preuve de création |
| Avatars et images de démonstration | Générés localement par IA, non redistribuables | Documenter le modèle et effectuer la déclaration IA itch.io |
| Polices système | Non embarquées | Ne rien redistribuer sans licence distincte |
| Story Editor | Présumé original | Confirmer la chaîne de propriété intellectuelle |

## 9. Informations du titulaire à compléter

- Titulaire/éditeur : Benjamin Sotier
- Contact licences : benjaminsotier@gmail.com
- Site officiel : N/A
- Version du Framework couverte : **[1.0.0]**

## 10. Conservation des preuves

Conservez hors du dépôt public une archive durable comprenant les factures, certificats, captures des pages de licence, fichiers de licence originaux, dates de téléchargement et échanges d’autorisation.

Une URL seule n’est pas une preuve suffisante à long terme : une page peut être modifiée ou supprimée.
