# Lecture des données du RPG 2021
# De la documentation est disponible ici : https://geoservices.ign.fr/documentation/donnees/vecteur/rpg
library(sf)
library(aws.s3)
library(RPostgres)

aws.s3::get_bucket("projet-funathon", region = "", prefix = "2023/sujet2/ign/rpg")

# Ilots
# Un îlot de culture correspond à un groupe de parcelles contiguës,
# cultivées par le même agriculteur

# Couches dispo dans le .gpkg
s3read_using(
  FUN = sf::st_layers,
  object = "2023/sujet2/ign/rpg/ILOTS_ANONYMES.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = "")
)

# Récupération du fichier ILOTS_ANONYMES
ilots <- s3read_using(
  FUN = sf::read_sf,
  query = 'SELECT * FROM ilots_anonymes LIMIT 10',
  object = "2023/sujet2/ign/rpg/ILOTS_ANONYMES.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = "")
)

# On n'a que l'information géographique sur les ilots (et identifiant)

# Fichier sur les parcelles
# Couches dispo dans le .gpkg
s3read_using(
  FUN = sf::st_layers,
  object = "2023/sujet2/ign/rpg/PARCELLES_GRAPHIQUES.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = "")
)

# Récupération du fichier sur les parcelles
parcelles <- s3read_using(
  FUN = sf::read_sf,
  query = 'SELECT * FROM parcelles_graphiques LIMIT 10',
  object = "2023/sujet2/ign/rpg/PARCELLES_GRAPHIQUES.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = "")
  )

# Variables disponibles (en plus de l'information géographique) :
# - Identifiant
# - Surface
# - Code culture
# - Code de la culture dérobée (culture intercalée entre 2 moissons de culture
# principale) sur la parcelle
# - Code de la seconde culture dérobée

parcelles %>% st_crs()
# Lambert 93

# Le fichier est trop gros pour être chargé en mémoire, on veut créer un table 
# dans un BDD PostgreSQL

# La base PostgreSQL est créée sur le SSP Cloud, et le mot de passe est stocké
# dans un secret Vault
postgresql_password <- rstudioapi::askForPassword(prompt = "Entrez le password PostgreSQL")

# Connection à PostgreSQL
cnx <- dbConnect(Postgres(),
                 user = "projet-funathon",
                 password = postgresql_password,
                 host = "postgresql-438832",
                 dbname = "defaultdb",
                 port = 5432,
                 check_interrupts = TRUE,
                 application_name = paste(paste0(version[["language"]], " ",
                                                 version[["major"]], ".",
                                                 version[["minor"]]),
                                          tryCatch(basename(rstudioapi::getActiveDocumentContext()[["path"]]),
                                                   error = function(e) ''),
                                          sep = " - "))

# On peuple la table PostgreSQL
dbSendQuery(cnx, "CREATE SCHEMA IF NOT EXISTS rpg")

offsets <- c(0, 1, 2, 3, 4, 5, 6, 7, 8, 9) * 1000000
for (offset in offsets) {
  query <- paste0("SELECT * FROM parcelles_graphiques LIMIT 1000000 OFFSET ", format(offset, scientific = FALSE))
  parcelles_part <- s3read_using(
    FUN = sf::read_sf,
    query = query,
    object = "2023/sujet2/ign/rpg/PARCELLES_GRAPHIQUES.gpkg",
    bucket = "projet-funathon",
    opts = list("region" = "")
  )
  write_sf(parcelles_part, cnx, Id(schema = "rpg", table = "parcelles"), append = T)
}
