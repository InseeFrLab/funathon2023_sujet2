# Funathon 2023 - Sujet 2

## Explorer la géographie des cultures agricoles françaises

Ce sujet s'articule autour de la question suivante : dans quelle mesure notre système actuel de cultures est-il exposé au changement climatique ? Il est composé de plusieurs applications décrites ci-dessous qui sont disponibles **sur ce [site](https://inseefrlab.github.io/funathon2023_sujet2/)**.

### Les données utilisées

Ce sujet propose de manipuler :

- Le [Registre Parcellaire Graphique (RPG)](https://www.data.gouv.fr/fr/datasets/registre-parcellaire-graphique-rpg-contours-des-parcelles-et-ilots-culturaux-et-leur-groupe-de-cultures-majoritaire/);
- Des données du [Drias](http://www.drias-climat.fr/decouverte) de simulation de l'évolution climatique pour le siècle en cours sur la France;
- Des données [ERA5](https://cds.climate.copernicus.eu/cdsapp#!/dataset/sis-agrometeorological-indicators) agro-météorologiques de surface **quotidiens** pour la période allant de 1979 à aujourd'hui.

### Etape 0 (optionnel) : Création d'une base de données PostgreSQL

Les données du RPG étant volumineuses, il faut pouvoir les requêter depuis une base de données. Les gentils organisateurs vous ont déjà préparé une base de données PostgreSQL (avec l'extension PostGIS) prête à l'emploi pour ce sujet. Néanmoins, nous vous expliquons comment procéder si vous souhaitez être en mesure de le faire vous-mêmes sur la plateforme SSP Cloud.

### Etape 1 : Première manipulation du RPG

L'objectif de cette première étape est d'effectuer des premières requêtes géographiques permettant d'examiner les cultures à proximité d'un point géographique donné, et de comparer la composition observée avec les compositions départementale, régionale, etc..

Suggestion d'approfondissement : proposer une interface de type tableau de bord permettant d'obtenir ces informations interactivement.

### Etape 2 : Exposition des cultures au déficit de précipitations

Cette deuxième étape est fortement inspirée de l'excellente [étude](https://www.insee.fr/fr/statistiques/6522912) réalisée par C. Fontès-Rousseau, R. Lardellier (DR Occitanie Insee) et JM Soubeyroux (Météo France). Son objectif est de mettre en regard cultures et prévisions climatiques localement, pour identifier des cultures particulièrement mises en danger par le changement climatique en France.

### Etape 3 : Evolution des cultures, lien avec le climat passé

Après avoir regardé vers l'avenir, il est temps de jeter un coup d'oeil dans le rétroviseur, et de regarder comment l'évolution des températures au cours des 40 dernières années a pu influencer certaines cultures en France. On estimera l'évolution des dates potentielles de récolte du maïs grain dans les différents bassins de productions français depuis 1980.

