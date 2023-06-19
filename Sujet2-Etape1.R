# Funathon 2023 - Sujet 2 - Explorer la géographie des cultures agricoles françaises
# Etape 1 - première manipulation du RPG
# Sélectionner les parcelles autour d'un point
# Comparer les cultures / département - métropole  

# écrit par         : Bertrand Ballet
# date de création  : 16/05/2023
# bénéficiaire      : Funathon 2023
# description       : Sélectionner les parcelles autour d'un point puis comparer les cultures / département - métropole   
# références         : https://github.com/InseeFrLab/funathon2023_sujet2 

Sys.setenv("PASS_POSTGRESQL"="1tfawt3nj7fgzo3w7cma")

shiny::runApp("app")

library(tidyverse); 
library(aws.s3)
library(sf)
library(RPostgreSQL)
library(shiny)

renv::restore()

install.packages("aws.s3", repos = "https://cloud.R-project.org")

Sys.setenv("AWS_ACCESS_KEY_ID" = "J22M2WX5LUZVCH4VURED",
           "AWS_SECRET_ACCESS_KEY" = "evIq8KQpeShehOH3uV3Y8sbGo6TPlRCIBJw1LXqQ",
           "AWS_DEFAULT_REGION" = "us-east-1",
           "AWS_SESSION_TOKEN" = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NLZXkiOiJKMjJNMldYNUxVWlZDSDRWVVJFRCIsImFsbG93ZWQtb3JpZ2lucyI6WyIqIl0sImF1ZCI6WyJtaW5pby1kYXRhbm9kZSIsIm9ueXhpYSIsImFjY291bnQiXSwiYXV0aF90aW1lIjoxNjg2NzI2NTUyLCJhenAiOiJvbnl4aWEiLCJlbWFpbCI6ImJlcnRyYW5kLmJhbGxldEBhZ3JpY3VsdHVyZS5nb3V2LmZyIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImV4cCI6MTY4NjgyOTA0MSwiZmFtaWx5X25hbWUiOiJCQUxMRVQiLCJnaXZlbl9uYW1lIjoiQmVydHJhbmQiLCJncm91cHMiOlsiZnVuYXRob24iXSwiaWF0IjoxNjg2NzI2NTUzLCJpc3MiOiJodHRwczovL2F1dGgubGFiLnNzcGNsb3VkLmZyL2F1dGgvcmVhbG1zL3NzcGNsb3VkIiwianRpIjoiYjliMmY0MzMtODU3NS00YTY4LTk2MzktOGYyMTE4MTQ3ZjZjIiwibmFtZSI6IkJlcnRyYW5kIEJBTExFVCIsIm5vbmNlIjoiYjQyMTc0YWUtN2I5MS00YTM2LTgyZDAtNzM4MTYzMmVmNjlmIiwicG9saWN5Ijoic3Rzb25seSIsInByZWZlcnJlZF91c2VybmFtZSI6ImJiYWxsZXQiLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJ1bWFfYXV0aG9yaXphdGlvbiJdfSwicmVzb3VyY2VfYWNjZXNzIjp7ImFjY291bnQiOnsicm9sZXMiOlsibWFuYWdlLWFjY291bnQiLCJtYW5hZ2UtYWNjb3VudC1saW5rcyIsInZpZXctcHJvZmlsZSJdfX0sInNjb3BlIjoib3BlbmlkIHByb2ZpbGUgZ3JvdXBzIGVtYWlsIiwic2Vzc2lvblBvbGljeSI6ImV5SldaWEp6YVc5dUlqb2lNakF4TWkweE1DMHhOeUlzSWxOMFlYUmxiV1Z1ZENJNlczc2lSV1ptWldOMElqb2lRV3hzYjNjaUxDSkJZM1JwYjI0aU9sc2ljek02S2lKZExDSlNaWE52ZFhKalpTSTZXeUpoY200NllYZHpPbk16T2pvNmNISnZhbVYwTFdaMWJtRjBhRzl1SWl3aVlYSnVPbUYzY3pwek16bzZPbkJ5YjJwbGRDMW1kVzVoZEdodmJpOHFJbDE5TEhzaVJXWm1aV04wSWpvaVFXeHNiM2NpTENKQlkzUnBiMjRpT2xzaWN6TTZUR2x6ZEVKMVkydGxkQ0pkTENKU1pYTnZkWEpqWlNJNld5SmhjbTQ2WVhkek9uTXpPam82S2lKZExDSkRiMjVrYVhScGIyNGlPbnNpVTNSeWFXNW5UR2xyWlNJNmV5SnpNenB3Y21WbWFYZ2lPaUprYVdabWRYTnBiMjR2S2lKOWZYMHNleUpGWm1abFkzUWlPaUpCYkd4dmR5SXNJa0ZqZEdsdmJpSTZXeUp6TXpwSFpYUlBZbXBsWTNRaVhTd2lVbVZ6YjNWeVkyVWlPbHNpWVhKdU9tRjNjenB6TXpvNk9pb3ZaR2xtWm5WemFXOXVMeW9pWFgxZGZRPT0iLCJzZXNzaW9uX3N0YXRlIjoiZmFhZjNlMDQtZDAxMS00OWEwLWE1ZmQtMzIyNjFjYzY3ZThkIiwic2lkIjoiZmFhZjNlMDQtZDAxMS00OWEwLWE1ZmQtMzIyNjFjYzY3ZThkIiwic3ViIjoiNGQ1N2NlN2QtOWNhYS00MDk4LWFjNDktNzY0MjAyYzJhN2I5IiwidHlwIjoiQmVhcmVyIn0.-3cSSboFOX2oXpaN73POdZj8uLHIvkYjPBttgnIhnNOFQDJc1aDfRusPBWCO_toMS5eMPM3J8DiKMOuLht8ddg",
           "AWS_S3_ENDPOINT"= "minio.lab.sspcloud.fr")

library("aws.s3")
bucketlist(region="")
library("aws.s3")
bucketlist(region="")
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

aws.s3::get_bucket("projet-funathon", region = "",prefix = "2023/sujet2/diffusion/ign/rpg")

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
                         object = "2023/sujet2/diffusion/ign/rpg/n-cultures-2021.csv", 
                         col_types = cols(.default = col_character()),
                         bucket = "projet-funathon",
                         opts = list("region" = "")) %>% select(-nom_sous_chapitre,-categorie_surf_agricole)
  

parc_prox <- parc_prox %>% left_join(cult_agreg,by=c("code_cultu"="code_culture"))

s3saveRDS(parc_prox, 
          bucket = "projet-funathon", 
          object = "/2023/sujet2/diffusion/resultats/parc_prox.rds", 
          opts = list("region" = ""))


# 5 - lecture des libelles des groupes de culture --------------------------------------

lib_group_cult<-s3read_using(FUN = read_csv2, 
                         object = "2023/sujet2/diffusion/ign/rpg/REF_CULTURES_GROUPES_CULTURES_2020.csv",
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
          object = "/2023/sujet2/diffusion/resultats/stat_group_cult_fm.rds", 
          opts = list("region" = ""))

s3write_using(stat_group_cult_fm,
              FUN = write_csv, 
             object = "/2023/sujet2/diffusion/resultats/stat_group_cult_fm.csv",
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
              object = "/2023/sujet2/diffusion/resultats/stat_group_cult_dep.csv",
              bucket = "projet-funathon",
              opts = list("region" = "")) 

# 9 - Boucle pour calculer les stats sur tous les départements

#téléchargement des comptages par strates par département

liste_dep_metro<-c('01','02','03','04','05','06','07','08','09','10',
                   '11','12','13','14','15','16','17','18','19','2A','2B',
                   '21','22','23','24','25','26','27','28','29','30',
                   '31','32','33','34','35','36','37','38','39','40',
                   '41','42','43','44','45','46','47','48','49','50',
                   '51','52','53','54','55','56','57','58','59','60',
                   '61','62','63','64','65','66','67','68','69','70',
                   '71','72','73','74','75','76','77','78','79','80',
                   '81','82','83','84','85','86','87','88','89','90',
                   '91','92','93','94','95')

# liste_dep_metro<-c('01','02')

t1<-Sys.time()
options(scipen = 15); 
for (num_dep in liste_dep_metro)
{
  cat("comptage stats département",num_dep,"\n")
  stat_dep<-dbGetQuery(cnx,str_glue("select insee_dep,code_group, count(*), round(sum(surf_parc)) as surf_ha 
from rpg.parcelles where insee_dep='{num_dep}' group by insee_dep, code_group order by code_group::numeric;"))  
  if (num_dep == liste_dep_metro[1]) 
  {
    stats_group_cult_by_dep<-stat_dep
    rm(stat_dep)
  } else
  {
    #concatenation des département    
    stats_group_cult_by_dep<-stats_group_cult_by_dep %>% rbind(stat_dep)
    rm(stat_dep)
  }
  cat(Sys.time()-t1,"\n")
}
Sys.time()-t1

#vérification

stats_group_cult_by_dep %>% group_by(insee_dep) %>% count() 
stats_group_cult_by_dep %>% group_by(code_group) %>% count() 

# calcul des totaux par département
tot_by_dep<-stats_group_cult_by_dep %>% group_by(insee_dep) %>% 
  summarise_at(vars(count,surf_ha),~sum(.)) %>% 
  rename(nparc_tot_dep=count,surf_tot_dep=surf_ha)

stat_group_cult_by_dep<-stats_group_cult_by_dep %>% 
  left_join(tot_by_dep, by="insee_dep") %>% 
  left_join(lib_group_cult,by=c("code_group"="code_group_culture")) %>% 
  select(insee_dep,code_group,libelle_groupe_culture,everything()) %>% 
  # add_tally(count) %>% add_tally(surf_ha) %>% 
  mutate(pct_count=round(100*count/nparc_tot_dep,1),
         pct_surf=round(100*surf_ha/surf_tot_dep,1), 
         surf_moy=round(surf_ha/count,1)) %>% 
  select(insee_dep,code_group,libelle_groupe_culture,count,pct_count, surf_ha, pct_surf, surf_moy)

s3write_using(stat_group_cult_by_dep,
              FUN = write_csv, 
              object = "/2023/sujet2/diffusion/resultats/stat_group_cult_by_dep.csv",
              bucket = "projet-funathon",
              opts = list("region" = "")) 
s3write_using(
  stat_group_cult_by_dep,
  readr::write_rds,
  object = "2023/sujet2/diffusion/resultats/stat_group_cult_by_dep.rds",
  bucket = "projet-funathon",
  opts = list("region" = ""))




