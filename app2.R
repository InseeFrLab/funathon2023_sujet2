# Application 2
# Inspiration de https://www.insee.fr/fr/statistiques/6522912
# Certaines cultures sont plus sensibles que d'autres à la sécheresse.
# Idées : degrés jours, https://blog.spotifarm.fr/tour-de-plaine-spotifarm/somme-de-temperature-pourquoi-suivre-levolution-des-degres-jours

library(RPostgres)
library(dplyr)
library(aws.s3)
library(ggplot2)
library(raster)
library(sf)
library(janitor)

# Première idée, on fait un spatial join entre DRIAS et RPG,
# on peut obtenir par carreau DRIAS la surface de parcelles pour chaque type de culture
postgresql_password <- rstudioapi::askForPassword(prompt = "Entrez le password PostgreSQL")
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

# On récupère par point de la grille DRIAS la surface pour chaque type de culture
query <- "
SELECT B.point, code_cultu, Sum(surf_parc) AS surface
FROM rpg.parcelles AS A
JOIN drias.previsions AS B
ON ST_Intersects(A.geom , B.geometry)
GROUP BY B.point, code_cultu
"
res <- dbSendQuery(cnx, query)
results_df <- dbFetch(res)

# On fait un join avec la table DRIAS pour récupérer les indicateurs d'intérêt
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
  janitor::clean_names() %>%
  dplyr::select(-c(x20, latitude, longitude, contexte, periode))

results_df <- results_df %>%
  dplyr::inner_join(drias, by = "point")

# A partir de cette table on souhaiterait calculer des indicateurs agrégés par culture
# Les variables disponibles dans les données DRIAS sont :
# NORRRA : cumul de précipitations d'avril à octobre (mm)
# NORSTM6 : somme de température base 6°C d'avril à octobre (°C)
# NORSTM0 : somme de température base 0°C d'octobre (année-1) à juillet (année) (°C)
# NORSDA : nombre de jours d'été d'avril à juin (jour(s))
# NORDATEVEG : date de reprise de végétation en jour julien (date)
# NORDATEDG : Date de dernière gelée avec 1er juillet comme référence (date)
# NORDATEPG : Date de première gelée avec 1er juillet comme référence (date)
# ARRA : Ecart de cumul de précipitations d'avril à octobre (mm)
# ASTM6 : Ecart de somme de température base 6°c d'avril à octobre (°C)
# ASTM0 : Ecart de somme de température base 0°c d'octobre (année-1) à juillet (année) (°C)
# ASDA : Ecart de nombre de jours d'été d'avril à juin (jour(s))
# ADATEVEG : Ecart de date de reprise de végétation en jour julien (date)
# ADATEDG : Ecart de date de dernière gelée avec 1er juillet comme référence (date)
# ADATEPG : Ecart de date de première gelée avec 1er juillet comme référence (date)

# Exemple 1
# On commence par la variable ARRA, pour calculer pour chaque culture un écart
# total du volume de précipitations d'avril à octobre
precip_df <- results_df %>%
  group_by(code_cultu) %>%
  summarise(ecart_volume_precip = sum(surface * arra), surface = sum(surface))

# On peut aussi récupérer un écart moyen du cumul en divisant par la surface
precip_df <- precip_df %>%
  mutate(ecart_cumul_moyen = ecart_volume_precip / surface)

# Les libellés sont disponibles sur MinIO
culture_mapping <- s3read_using(
  FUN = read.csv,
  sep = ";",
  object = "2023/sujet2/diffusion/ign/rpg/CULTURE.csv",
  bucket = "projet-funathon",
  opts = list("region" = "")
)

precip_df %>%
  dplyr::left_join(culture_mapping, by = c("code_cultu" = "Code")) %>%
  arrange(desc(ecart_cumul_moyen))

precip_df %>%
  dplyr::left_join(culture_mapping, by = c("code_cultu" = "Code")) %>%
  arrange(ecart_cumul_moyen)

# Illustration, on passe par du raster pour plot ?
aws.s3::get_bucket("projet-funathon", region = "", prefix = "2023/sujet2/diffusion/resultats")

drias_raster <- s3read_using(
  function(f) readAll(brick(f)),
  object = "2023/sujet2/diffusion/resultats/drias.tif",
  bucket = "projet-funathon",
  opts = list("region" = ""))
drias_df <- as.data.frame(drias_raster, xy = TRUE) %>% tidyr::drop_na()
colnames(drias_df) <- c(
  "x",
  "y",
  "NORRRA",
  "NORSTM6",
  "NORSTM0",
  "NORSDA",
  "NORDATEVEG",
  "NORDATEDG",
  "NORDATEPG",
  "ARRA",
  "ASTM6",
  "ASTM0",
  "ASDA",
  "ADATEVEG",
  "ADATEDG",
  "ADATEPG",
  "ALTI"
)
drias_df

nbands(drias_raster)
bandnr(drias_raster)

# Bande ARRA
drias_raster_arra <- s3read_using(
  function(f) readAll(raster(f, band = 8)),
  object = "2023/sujet2/diffusion/resultats/drias.tif",
  bucket = "projet-funathon",
  opts = list("region" = ""))
as.data.frame(drias_raster_arra, xy = TRUE)


raster::plot(x = drias_raster_arra,
             main = "Ecarts des cumuls de précipitations d'avril à octobre (mm) entre 2021-2050 et 1976-2005")

# Avec palette custom
palette <- c("#1457ff", "#3c9aff", "#6dc4ff", "#a8e1ff", "#dff1fb", "#f8e9eb", "#fca8ab", "#f9575d", "#f2060b", "#a20102")
breaks <- c(-200, -160, -120, -80, -40, -0, 40, 80, 120, 160, 200)

raster::plot(x = drias_raster_arra,
             col = rev(palette),
             breaks = breaks,
             main = "Ecarts des cumuls de précipitations d'avril à octobre (mm) entre 2021-2050 et 1976-2005")
# Petites différences avec les visualisations disponibles sur le site du DRIAS
# http://www.drias-climat.fr/decouverte/cartezoom/experience/EUROCORDEX2020_ELAB/ALADIN63_CNRM-CM5/RCP8.5/RCP8.5/H1/ARRA/ARRA/A1
# Interpolation lors de la création du raster ?

# Bande ASDA
drias_raster_asda <- s3read_using(
  function(f) readAll(raster(f, band = 11)),
  object = "2023/sujet2/diffusion/resultats/drias.tif",
  bucket = "projet-funathon",
  opts = list("region" = ""))

raster::plot(x = drias_raster_asda,
             main = "Ecarts de nombre de jours d'été d'avril à juin entre 2021-2050 et 1976-2005")

# On essaye de plot la même chose à partir de la base PostGIS
query <- "
SELECT *
FROM drias.previsions
"
drias_sf <- st_read(cnx, query = query)

ggplot() + 
  geom_sf(data = drias_sf, aes(fill = arra), color = NA) +
  binned_scale(aesthetics = "fill", scale_name = "custom", 
               palette = ggplot2:::binned_pal(scales::manual_pal(values = rev(palette)[-1])),
               guide = "bins",
               breaks = breaks)

# On veut regarder où se trouvent les cultures pour lesquelles on anticipe une forte baisse d'apport
# en eau : PVP, MID, SGE, ARA
query_pvp <- "
SELECT id_parcel, geom
FROM rpg.parcelles
WHERE code_cultu = 'PVP'
"
pvp_df <- st_read(cnx, query = query_pvp)

# On veut plot les parcelles avec les frontières régionales
# Récupération des frontières régionales
region_sf <- st_read(
  cnx, query = "SELECT * FROM adminexpress.region"
)
region_sf <- region_sf %>% st_transform(
  "EPSG:2154"
)
region_sf <- region_sf %>%
  dplyr::filter(!(insee_reg %in% c("03", "04", "06", "01", "02", "01_SBSM")))

ggplot() + 
  geom_sf(data = region_sf) +
  geom_sf(data = pvp_df, fill = "#fca8ab", color = NA)
# Les parcelles sont trop petites, on fait un buffer pour la visualisation

ggplot() + 
  geom_sf(data = region_sf) +
  geom_sf(data = st_buffer(pvp_df, 5000), fill = "#fca8ab", color = NA)
# On aura envie de regarder de manière plus fine quelles parcelles vont avoir des 
# problèmes

# Mais doux
query_mid <- "
SELECT id_parcel, geom
FROM rpg.parcelles
WHERE code_cultu = 'MID'
"
pvp_mid <- st_read(cnx, query = query_mid)
ggplot() + 
  geom_sf(data = region_sf) +
  geom_sf(data = st_buffer(pvp_mid, 5000), fill = "#fca8ab", color = NA)

# A contrario on regarde les cultures qui vont être trop arrosées
# AGR Agrume                                       
# CTG Châtaigne
# LUD Luzerne déshydratée

# Agrume
query_agr <- "
SELECT id_parcel, geom
FROM rpg.parcelles
WHERE code_cultu = 'AGR'
"
pvp_agr <- st_read(cnx, query = query_agr)
ggplot() + 
  geom_sf(data = region_sf) +
  geom_sf(data = st_buffer(pvp_agr, 5000), fill = "#fca8ab", color = NA)

# Luzerne déshydratée
query_lud <- "
SELECT id_parcel, geom
FROM rpg.parcelles
WHERE code_cultu = 'LUD'
"
pvp_lud <- st_read(cnx, query = query_lud)
ggplot() + 
  geom_sf(data = region_sf) +
  geom_sf(data = st_buffer(pvp_lud, 5000), fill = "#fca8ab", color = NA)

# On voudrait regarder la perte en %age
# Cultures qui ont besoin de bcp d'eau ?
# Horizon lointain ?

# Autres manières de faire
# On calcule l'intersection au lieu de faire confiance à la variable surf_parc
query <- "
SELECT ST_Intersection(A.geom, B.geometry) as intersection_geom, SURF_PARC, CODE_CULTU, CODE_GROUP
FROM rpg.parcelles AS A
JOIN drias.previsions AS B
ON ST_Intersects(A.geom , B.geometry)
"
