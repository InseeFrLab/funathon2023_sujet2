###
# Prétraitement des données Drias pour avoir un format simple à utiliser :
# formats SIG et projections homogènes
###
library(raster)
library(tidyverse)
library(janitor)
library(sf)
library(readxl)
library(aws.s3)
library(RPostgres)


# Données sur MinIO
aws.s3::get_bucket("projet-funathon", region = "",  prefix = "2023/sujet2/diffusion")

# http://www.drias-climat.fr/commande
# Indicateurs 'DRIAS-2020' par horizon - secteur Agriculture
# Horizon proche - indicateurs calculés sur la période [2021-2050]
# RCP8.5 : Scénario sans politique climatique
# Modèle ALADIN63_CNRM-CM5
drias <- s3read_using(
    FUN = readr::read_delim,
    skip = 33,
    col_names = c("Point", "Latitude", "Longitude", "Contexte", "Période",
                  "NORRRA", "NORSTM6", "NORSTM0", "NORSDA", "NORDATEVEG",
                  "NORDATEDG", "NORDATEPG", "ARRA", "ASTM6", "ASTM0",
                  "ASDA", "ADATEVEG", "ADATEDG", "ADATEPG"),
    object = "2023/sujet2/diffusion/drias/indicesALADIN63_CNRM-CM5_23050511192547042.KEYuUdx3UA39Av7f1U7u7O.txt",
    bucket = "projet-funathon",
    opts = list("region" = "")) %>%
  clean_names() %>%
  dplyr::select(-x20)

# Les points lon/lat ne sont pas précisément sur une grille régulière qui
# était à l'origine en Lambert2 étendu (grille Safran). On ne peut donc pas
# créer facilement de raster, sauf en interpolant.
#
# On récupère plutôt les coordonnées d'origine puis on reprojettera en Lambert93
# https://drias-prod.meteo.fr/okapi/_composantsHTML/simulations/refGeoSimulations/aide_safran_drias2021.html
# https://drias-prod.meteo.fr/serveur/simulations_climatiques/grilles/safran/grilleSafran_complete_drias2021.xls
grille <- s3read_using(
    readxl::read_xls,
    skip = 9,
    col_names = c("id", "x_n", "y_n", "x_l2e", "y_l2e",
                 "x_l93", "y_l93", "lon", "lat",
                 "alti", "unused"),
    object = "2023/sujet2/diffusion/drias/grilleSafran_complete_drias2021.xls",
    bucket = "projet-funathon",
    opts = list("region" = "")) %>%
  dplyr::select(-unused)

# Contours admin simplifiés d'après adminexpress
fr <- s3read_using(
    FUN = sf::read_sf,
    layer = "region",
    object = "2023/sujet2/diffusion/ign/adminexpress_cog_simpl_000_2023.gpkg",
    bucket = "projet-funathon",
    opts = list("region" = "")) %>%
  filter(insee_reg > "06") %>%
  summarise() %>%
  st_transform("EPSG:2154")

# Prétraitement  ----------------------------------------------------------

# Points
drias_sf <- drias %>%
  inner_join(grille, by = c("point" = "id")) %>%
  st_as_sf(coords = c("x_l2e", "y_l2e"),
           crs = "EPSG:27572",
           remove = FALSE) %>%
  st_transform("EPSG:2154")

drias_sf %>% 
  aws.s3::s3write_using(
  sf::write_sf,
  object = "2023/sujet2/diffusion/resultats/drias.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = ""))

# Raster
drias_raster <- drias_sf %>%
  st_drop_geometry() %>%
  dplyr::select(-c(point, contexte, periode, x_n, y_n, latitude, longitude,
            x_l93, y_l93, lon, lat)) %>%
  `coordinates<-`(~ x_l2e + y_l2e) %>%
  `projection<-`("EPSG:27572") %>%
  SpatialPixelsDataFrame(.@data) %>%
  brick() %>%
  projectRaster(res = 8000, crs = "EPSG:2154")

drias_raster %>% 
  aws.s3::s3write_using(
    raster::writeRaster,
    overwrite = TRUE,
    object = "2023/sujet2/diffusion/resultats/drias.tif",
    bucket = "projet-funathon",
    opts = list("region" = ""))

drias_raster %>% 
  aws.s3::s3write_using(
    readr::write_rds,
    object = "2023/sujet2/diffusion/resultats/drias.rds",
    bucket = "projet-funathon",
    opts = list("region" = ""))

# Voronoï à partir des points
g <- st_combine(st_geometry(drias_sf))
v <- st_voronoi(g)
v <- st_collection_extract(v)
v <- v[unlist(st_intersects(drias_sf, v))]
drias_sf <- st_set_geometry(drias_sf, v)

# On récupère les régions françaises pour réduire la taille des cellules aux frontières
query <- "SELECT * FROM adminexpress.region"
region_sf <- st_read(cnx, query = query)
region_sf <- region_sf %>% st_transform(
  "EPSG:2154"
)
metropole_sf <- region_sf %>%
  dplyr::filter(!(insee_reg %in% c("03", "04", "06", "01", "02", "01_SBSM")))

# Intersection
drias_sf_intersected <- st_intersection(drias_sf, st_combine(metropole_sf))

# Export PostgreSQL  ----------------------------------------------------------
cnx <- dbConnect(Postgres(),
                 user = "projet-funathon",
                 password = Sys.getenv("PASS_POSTGRESQL"),
                 host = "postgresql-758156",
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
dbExecute(cnx, "CREATE SCHEMA IF NOT EXISTS drias")
write_sf(drias_sf_intersected, cnx, Id(schema = "drias", table = "previsions"))
