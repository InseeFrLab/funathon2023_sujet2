###
# Import données SIG dans PostgreSQL
###
library(RPostgres)
library(aws.s3)
library(sf)


# Database connection
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


# MinIO
aws.s3::get_bucket("projet-funathon", region = "",  prefix = "2023/sujet2/diffusion")

# Couches dispo dans le .gpkg de test
s3read_using(
  FUN = sf::st_layers,
  object = "2023/sujet2/diffusion/ign/adminexpress_cog_simpl_000_2023.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = "")
)

# Ouvrir la couche des régions
reg <- s3read_using(
    FUN = sf::read_sf,
    layer = "region",
    object = "2023/sujet2/diffusion/ign/adminexpress_cog_simpl_000_2023.gpkg",
    bucket = "projet-funathon",
    opts = list("region" = ""))

# Export des données sur PostgreSQL
dbExecute(cnx, "CREATE SCHEMA IF NOT EXISTS adminexpress")
write_sf(reg, cnx, Id(schema = "adminexpress", table = "region"))
dbExecute(
  cnx,
  "COMMENT ON TABLE adminexpress.region IS $$polygones des régions françaises 
  Adminexpress COG 2023 géométrie simplifiée pour carto nationale EPSG:WGS84$$"
)

# Couche des communes
com <- s3read_using(
  FUN = sf::read_sf,
  layer = "commune",
  object = "2023/sujet2/diffusion/ign/adminexpress_cog_simpl_000_2023.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = ""))

# Export des données sur PostgreSQL
write_sf(com, cnx, Id(schema = "adminexpress", table = "commune"))
dbExecute(
  cnx,
  "COMMENT ON TABLE adminexpress.commune IS $$polygones des communes françaises 
  Adminexpress COG 2023 géométrie simplifiée pour carto nationale EPSG:WGS84$$"
)

# Indexation, important sur geom
dbExecute(cnx,
          "ALTER TABLE adminexpress.commune ADD CONSTRAINT commune_pk PRIMARY KEY (id)")
dbExecute(cnx, 
          "CREATE INDEX ON adminexpress.commune USING gist (geom)")
