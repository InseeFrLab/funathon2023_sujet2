

library(RPostgres)
library(sf)
library(mapview)

cnx <- dbConnect(Postgres(),
                 user = "projet-funathon",
                 password = rstudioapi::askForPassword(prompt = "Entrez le password PostgreSQL"),
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

tbl(cnx, Id(schema = "rpg", table = "parcelles")) %>% 
  filter(code_cultu %in% c("MIS", "MID", "MIE")) %>% 
  group_by(code_cultu) %>% 
  summarise(nb_parc = n(),
            sur = sum(surf_parc))

dbExecute(cnx,
"DROP TABLE IF EXISTS travail.cluster")

dbExecute(cnx,
"CREATE TABLE travail.cluster AS (
  WITH loc AS (
    SELECT
    id_parcel,
    ST_MakePointM(st_x(st_pointonsurface(geom)),
                  st_y(st_pointonsurface(geom)),
                  surf_parc) AS geom
    FROM rpg.parcelles
    WHERE code_cultu = 'MIS'
    AND surf_parc > 0)
    
  SELECT  
    ST_ClusterKMeans(geom, 5) OVER() AS cid, id_parcel, geom
  FROM loc
)")

dbExecute(cnx,
"ALTER TABLE travail.cluster
  ALTER COLUMN geom type geometry(PointM, 2154)")

dbExecute(cnx,
  "DROP TABLE IF EXISTS travail.com")

dbExecute(cnx,
"CREATE TABLE travail.com AS (
   SELECT 
     insee_com, 
     population,
     nom,
     st_transform(geom, 2154) AS geom
   FROM adminexpress.commune
   WHERE insee_reg > '06'
)")

dbExecute(cnx,
"CREATE INDEX com_geom_idx
    ON travail.com USING gist (geom)")

dbExecute(cnx,
"DROP TABLE IF EXISTS travail.concave")

dbExecute(cnx, "
CREATE TABLE travail.concave AS (
  WITH cluster_union AS (
    SELECT
      c.cid,
      st_multi(st_union(c.geom)) AS geom
    FROM travail.cluster c
    GROUP BY c.cid
  )
  
  SELECT 
    cluster_union.cid,
    st_convexhull(cluster_union.geom) AS geom
    --st_concavehull(cluster_union.geom, 0.4) AS geom
  FROM cluster_union
)")

dbExecute(cnx,
"CREATE INDEX concave_geom_idx
    ON travail.concave USING gist (geom)")

cluster <- st_read(cnx, query = "           
SELECT DISTINCT ON (concave.cid)
  concave.cid,
  last_value(com.nom) OVER wnd nom,
  last_value(com.insee_com) OVER wnd insee_com,
  last_value(concave.geom) OVER wnd geom
FROM travail.com com
  INNER JOIN travail.concave concave ON st_intersects(com.geom, concave.geom)
WINDOW wnd AS (
   PARTITION BY concave.cid 
   ORDER BY population
   ROWS BETWEEN UNBOUNDED PRECEDING 
     AND UNBOUNDED FOLLOWING)")

cluster %>% 
  mapview()

points <- cluster %>% 
  st_centroid() %>% 
  st_transform("EPSG:4326")

era5 <- dir_ls(rep_era5, recurse = TRUE, glob = "*.nc") %>% 
  read_stars() %>% 
  rename(temp_moy_k = 1)

temp_points <- era5 %>% 
  st_extract(points) %>%
  as_tibble() %>% 
  mutate(temp_moy_c = temp_moy_k - 273.15,
         date = as_date(time)) %>% 
  full_join(points, ., by = "geom")



# base de calcul pour maïs : 6 °C
base <- 6 # °C

# besoin total à récolte pour un maïs grain de précocité moyenne : 1700 DJ
besoin <- 1700 # DJ

recolte <- temp_points %>% 
  select(date, nom, temp_moy_c) %>% 
  group_by(nom, annee = year(date)) %>% 
  mutate(dj = case_when(yday(date) < 91 ~ 0,
                        temp_moy_c > 30 ~ 0,
                        temp_moy_c < base ~ 0,
                        TRUE ~ temp_moy_c - base),
         sdj = cumsum(dj)) %>%
  filter(sdj > besoin) %>% 
  slice_min(date) %>% 
  ungroup() %>% 
  select(date, annee, nom) %>% 
  filter(nom != "Marseille")

recolte  %>% 
  mutate(doy = yday(date),
         date_virtuelle = as_date(parse_date_time(glue("2020-{str_pad(doy, 3, 'left', '0')}"), 
                                                  orders = "yj"))) %>% 
  ggplot(aes(annee, date_virtuelle, color = nom)) +
  geom_point() +
  geom_smooth(method = lm) +
  scale_y_date(date_breaks = "months", date_labels = "%b") +
  labs(title = "Date de récolte potentielle",
       subtitle = "Maïs grain",
       x = "année",
       y = "jour",
       color = "lieu",
       caption = glue("d'après données agroclimatiques ERA5
                       pour une précocité moyenne ({besoin} DJ, base {base} °C)"))


mod <- recolte %>% 
  mutate(doy = yday(date)) %>% 
  glm(doy ~ annee + nom, data = .)

tbl_regression(mod)
