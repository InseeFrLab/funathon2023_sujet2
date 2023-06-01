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
library(RPostgreSQL)

# library(janitor);
# library(ggplot2)
# library(cowplot)
# library(maptiles)
# library(leaflet)
# library(htmltools)
# library(htmlwidgets)
# library(tictoc)
# library(openxlsx)

# données -----------------------------------------------------------------

aws.s3::get_bucket("projet-funathon", region = "",  prefix = "2023/sujet2/ign/rpg")

# 1 - Créer une table avec un point en récupérant les coordonnées GPS --------

lat<- 43.44763763593564
lon<- 1.2887755354488053
rayon<-10000

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
postgresql_password <- "1tfawt3nj7fgzo3w7cma"
  
# Connection à PostgreSQL
cnx <- dbConnect(PostgreSQL(),
                 user = "projet-funathon",
                 password = postgresql_password,
                 host = "postgresql-438832",
                 dbname = "defaultdb",
                 port = 5432,
                 # check_interrupts = TRUE,
                 options="-c search_path=rpg,public") # specify what schema to connect to
                 # application_name = paste(paste0(version[["language"]], " ",
                 #                                 version[["major"]], ".",
                 #                                 version[["minor"]]),
                 #                          tryCatch(basename(rstudioapi::getActiveDocumentContext()[["path"]]),
                 #                                   error = function(e) ''),
                 #                          sep = " - "))

# suppression de la table «point» si elle existe
dbSendQuery(cnx,"DROP TABLE IF EXISTS rpg.point CASCADE;")

# ecriture de la table dans la base PostGis
write_sf(point, cnx, append = T)

# ajout d'une clé primaire
dbSendQuery(cnx,"ALTER TABLE rpg.point ADD CONSTRAINT point_pkey PRIMARY KEY(coord_pt_gps);")

# ajout d'un index
dbSendQuery(cnx,"CREATE INDEX ON rpg.point USING gist(geom);")
# dbExecute(cnx,"CREATE INDEX ON rpg.point USING gist(geom);")

# 3 - Exécution de la requête de découpage du RPG autour du point sur PostGis  -------

dbSendQuery(cnx,"DROP TABLE IF EXISTS rpg.parc_prox CASCADE;")

dbSendQuery(cnx,"CREATE TABLE rpg.parc_prox AS
	SELECT row_number() OVER () AS row_id, p.coord_pt_gps, p.rayon, r.*  
	FROM rpg.point p, rpg.parcelles r 
	WHERE ST_DWithin(p.geom,r.geom,p.rayon);")

# ajout d'une clé primaire
dbSendQuery(cnx,"ALTER TABLE rpg.parc_prox ADD CONSTRAINT parc_prox_pk PRIMARY KEY(id_parcel);")

# ajout d'un index
dbSendQuery(cnx,"CREATE INDEX parc_prox_geom_idx ON rpg.parc_prox USING gist(geom);")


# 4 - Téléchargement des parcelles proches sous R-------------------------------

# parc_prox<-read_sf(cnx,parc_prox)

parc_prox<-st_read(cnx, query="select * from rpg.parc_prox;")

plot(st_geometry(parc_prox))

# 5 - Lecture et appariement des cultures agrégées ---------------------------------------

cult_agreg<-s3read_using(FUN = read_csv, 
                         object = "2023/sujet2/ign/rpg/n-cultures-2021.csv", 
                         col_types = cols(.default = col_character()),
                         bucket = "projet-funathon",
                         opts = list("region" = "")) %>% select(-nom_sous_chapitre,-categorie_surf_agricole)
  

parc_prox <- parc_prox %>% left_join(cult_agreg,by=c("code_cultu"="code_culture"))


# 5 - lecture des libelles des groupes de culture --------------------------------------

lib_group_cult<-s3read_using(FUN = read_csv2, 
                         object = "2023/sujet2/ign/rpg/REF_CULTURES_GROUPES_CULTURES_2020.csv",
                         col_types = cols(.default = col_character()),
                         bucket = "projet-funathon",
                         opts = list("region" = "")) %>% 
  select(CODE_GROUPE_CULTURE,LIBELLE_GROUPE_CULTURE) %>% 
  distinct(CODE_GROUPE_CULTURE,.keep_all=T) %>% 
  rename (code_group_culture=CODE_GROUPE_CULTURE,libelle_groupe_culture=LIBELLE_GROUPE_CULTURE)


# 6 - Calcul des surfaces par culture France métro (sur PostGIS)------------------------

stat_sql_group_cult_fm<-dbGetQuery(cnx,"select code_group, count(*), round(sum(surf_parc)) as surf_ha 
from rpg.parcelles group by code_group order by code_group::numeric;")  

stat_group_cult_fm<-stat_sql_group_cult_fm %>% 
  left_join(lib_group_cult,by=c("code_group"="code_group_culture")) %>% 
  select(code_group,libelle_groupe_culture,everything()) %>% 
  add_tally(count) %>% add_tally(surf_ha) %>% 
  mutate(pct_count=round(100*count/n,1),pct_surf=round(100*surf_ha/nn,1), surf_moy=round(surf_ha/count,1)) %>% 
  select(code_group,libelle_groupe_culture,count,pct_count, surf_ha, pct_surf, surf_moy)

s3saveRDS(stat_group_cult_fm, 
          bucket = "projet-funathon", 
          object = "/2023/sujet2/resultats/stat_group_cult_fm.rds", 
          opts = list("region" = ""))

s3write_using(stat_group_cult_fm,
              FUN = write_csv, 
             object = "/2023/sujet2/resultats/stat_group_cult_fm.csv",
             bucket = "projet-funathon",
             opts = list("region" = "")) 
  
# 7 - Ajout des codes commune, departement, region dans la table parcelles -----

dbSendQuery(cnx,"ALTER TABLE rpg.parcelles ADD COLUMN insee_com text;")
dbSendQuery(cnx,"ALTER TABLE rpg.parcelles ADD COLUMN insee_dep text;")
dbSendQuery(cnx,"ALTER TABLE rpg.parcelles ADD COLUMN insee_reg text;")
dbSendQuery(cnx,"ALTER TABLE rpg.parcelles ADD COLUMN nom_com text;")

# Création d'une table commune avec SRID=2154
# suppression de la table «point» si elle existe
dbSendQuery(cnx,"DROP TABLE IF EXISTS rpg.com CASCADE;")

dbSendQuery(cnx,"CREATE TABLE rpg.com AS
SELECT id, nom, insee_com, insee_dep, insee_reg, st_transform(geom,2154) as geom 
FROM adminexpress.commune")

dbGetQuery(cnx,"SELECT st_srid(geom) FROM rpg.com LIMIT 1;")  

dbSendQuery(cnx,"ALTER TABLE rpg.com ADD CONSTRAINT com_pk PRIMARY KEY(id);")       
dbSendQuery(cnx,"CREATE INDEX ON rpg.com USING gist(geom);")

dbSendQuery(cnx,
            "WITH  sel AS (
  SELECT r.id_parcel, c.insee_com, c.insee_dep, c.insee_reg, c.nom FROM 
  rpg.parcelles r, adminexpress.commune c
  WHERE st_intersects(st_pointonsurface(r.geom), c.geom)
)
UPDATE rpg.parcelles r
SET insee_com = sel.insee_com, insee_dep=sel.insee_dep, insee_reg=sel.insee_reg, nom_com=sel.nom 
FROM sel
WHERE r.id_parcel = sel.id_parcel;"
)

# 8 - Calcul des surfaces par culture dans le département du point (sur PostGIS)------------------------

# jointure spatiale point x com pour récupérer le département du point
com<-st_read(cnx,query="select insee_com, insee_dep, geom from rpg.com;")
df<-point %>% st_join(com) %>% st_drop_geometry() %>% select(insee_dep) 
dep_pt<-df[1,1]

stat_sql_group_cult_dep<-dbGetQuery(cnx,str_glue("select insee_dep,code_group, count(*), round(sum(surf_parc)) as surf_ha 
from rpg.parcelles where insee_dep='{dep_pt}' group by insee_dep, code_group order by code_group::numeric;"))  

stat_group_cult_dep<-stat_sql_group_cult_dep %>% 
  left_join(lib_group_cult,by=c("code_group"="code_group_culture")) %>% 
  select(code_group,libelle_groupe_culture,everything()) %>% 
  add_tally(count) %>% add_tally(surf_ha) %>% 
  mutate(pct_count=round(100*count/n,1),pct_surf=round(100*surf_ha/nn,1), surf_moy=round(surf_ha/count,1)) %>% 
  select(insee_dep,code_group,libelle_groupe_culture,count,pct_count, surf_ha, pct_surf, surf_moy)

s3write_using(stat_group_cult_dep,
              FUN = write_csv, 
              object = "/2023/sujet2/resultats/stat_group_cult_dep.csv",
              bucket = "projet-funathon",
              opts = list("region" = "")) 


