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
library(janitor);
library(sf)
library(RPostgreSQL)
library(ggplot2)
library(cowplot)
library(maptiles)
library(leaflet)
library(htmltools)
library(htmlwidgets)
library(tictoc)
library(openxlsx)


# 1 - Créer une table avec un point en récupérant les coordonnées GPS --------

lat<- 43.44763763593564
lon<- 1.2887755354488053
rayon<-5000

point<-data.frame(lon,lat) %>% 
  st_as_sf(coords = c("lon","lat"),crs = "EPSG:4326") %>%
  mutate(coord_pt_gps=st_as_text(geometry)) %>% 
  st_transform("EPSG:2154") %>% clean_names() %>% st_sf() 
st_geometry(point)<-"geom"

st_crs(point)
st_geometry_type(point)
plot(point)
st_as_text(st_sfc(point$geom, crs = 4326), EWKT = TRUE)

# 2 - Export de la table point vers PostGis -------------------------------

# define postgres user password
pw <- "x5D25m2Xpt"

# connection à la base Postgres Grald/rpg
cnx <- dbConnect(PostgreSQL(),
                      host = "stats-prod-postgres-49.zsg.agri", # host name, can be website/server
                      port = "4000", # default port of postgres
                      dbname = "rpg", # name of database in postgres
                      user = "dbograld", # the default user
                      password = pw, # password of user
                      options="-c search_path=rpg,public" # specify what schema to connect to
)


# write_sf(point, cnx, Id(schema = "rpg", table = "point"), append = T)
write_sf(point, cnx, append = T)
# st_write(point,dsn=cnx,layer="point",delete_layer = TRUE)



