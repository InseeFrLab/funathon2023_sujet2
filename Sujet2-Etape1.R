# Funathon 2023 - Sujet 2 - Explorer la géographie des cultures agricoles françaises
# Etape 1 - première manipulation du RPG
# Sélectionner les parcelles autour d'un point
# Comparer les cultures / département - métropole  

# écrit par         : Bertrand Ballet
# date de création  : 16/05/2023
# bénéficiaire      : Funathon 2023
# description       : Sélectionner les parcelles autour d'un point puis comparer les cultures / département - métropole   
# références         : https://github.com/InseeFrLab/funathon2023_sujet2 

library(tidyverse); 
library(aws.s3)
library(sf)
library(RPostgres)

# library(janitor);
# library(ggplot2)
# library(cowplot)
# library(maptiles)
# library(leaflet)
# library(htmltools)
# library(htmlwidgets)
# library(tictoc)
# library(openxlsx)

# test commit
 
# 1 - Créer une table avec un point en récupérant les coordonnées GPS --------

lat<- 43.44763763593564
lon<- 1.2887755354488053
rayon<-5000

# janitor (clean_names) non disponible (?)
point<-data.frame(lon,lat,rayon) %>% 
  st_as_sf(coords = c("lon","lat"),crs = "EPSG:4326") %>%
  mutate(coord_pt_gps=st_as_text(geometry)) %>% 
  st_transform("EPSG:2154") %>% st_sf()
st_geometry(point)<-"geom"

# %>% clean_names()

st_crs(point)
st_geometry_type(point)
plot(point)
st_as_text(st_sfc(point$geom, crs = 4326), EWKT = TRUE)

# 2 - Export de la table point vers PostGis -------------------------------

# le mot de passe est stocké dans un secret Vault
postgresql_password <- rstudioapi::askForPassword(prompt = "Entrez le password PostgreSQL")

# Connection à PostgreSQL
cnx <- dbConnect(Postgres(),
                 user = "projet-funathon",
                 password = postgresql_password,
                 host = "postgresql-438832",
                 dbname = "defaultdb",
                 port = 5432,
                 check_interrupts = TRUE,
                 options="-c search_path=rpg,public", # specify what schema to connect to
                 application_name = paste(paste0(version[["language"]], " ",
                                                 version[["major"]], ".",
                                                 version[["minor"]]),
                                          tryCatch(basename(rstudioapi::getActiveDocumentContext()[["path"]]),
                                                   error = function(e) ''),
                                          sep = " - "))

# suppression de la table «point» si elle existe
dbSendQuery(cnx,"DROP TABLE IF EXISTS rpg.point CASCADE;")

# ecriture de la table dans la base PostGis
write_sf(point, cnx, append = T)

# ajout d'une clé primaire
dbSendQuery(cnx,"ALTER TABLE rpg.point ADD CONSTRAINT point_pkey PRIMARY KEY(coord_pt_gps);")

# ajout d'un index
dbSendQuery(cnx,"CREATE INDEX ON rpg.point USING gist(geom);")
dbExecute(cnx,"CREATE INDEX ON rpg.point USING gist(geom);")

# 3 - Exécution de la requête de découpage du RPG autour du point sur PostGis  -------

tic()
dbSendQuery(cnx,"DROP TABLE IF EXISTS rpg.parc_prox CASCADE;")
toc()

tic()
dbSendQuery(cnx,"CREATE TABLE rpg.parc_prox AS
	SELECT row_number() OVER () AS row_id, p.coord_pt_gps, p.rayon, r.*  
	FROM rpg.point p, rpg.parcelles r 
	WHERE ST_DWithin(p.geom,r.geom,p.rayon);")
toc()

# ajout d'une clé primaire
tic()
dbSendQuery(cnx,"ALTER TABLE rpg.parc_prox ADD CONSTRAINT parc_prox_pk PRIMARY KEY(gid);")
toc()

# ajout d'un index
tic()
dbSendQuery(cnx,"CREATE INDEX parc_prox_geom_idx ON rpg.parc_prox USING gist(geom);")
toc()


# 4 - Téléchargement des parcelles proches sous R-------------------------------

# parc_prox<-read_sf(cnx,parc_prox)

parc_prox<-st_read(cnx, query="select * from rpg.parc_prox;")

plot(st_geometry(parc_prox))

parc_prox %>% 
  summary(parc_prox$code_cultu)

summary(parc_prox$surface)
describe(parc_prox$code_cultu)




