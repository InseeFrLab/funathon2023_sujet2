# Import données SIG dans PostgreSQL

library(RPostgres)
library(aws.s3)
library(sf)

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

aws.s3::get_bucket("projet-funathon", region = "",  prefix = "2023/sujet2")

# couches dispo dans le gpkg
s3read_using(
  FUN = sf::st_layers,
  object = "2023/sujet2/ign/adminexpress_cog_simpl_000_2023.gpkg",
  bucket = "projet-funathon",
  opts = list("region" = "")
)

# ouvrir la couche des régions
reg <- s3read_using(
    FUN = sf::read_sf,
    layer = "region",
    object = "2023/sujet2/ign/adminexpress_cog_simpl_000_2023.gpkg",
    bucket = "projet-funathon",
    opts = list("region" = ""))


# importer 
dbSendQuery(cnx, "CREATE SCHEMA IF NOT EXISTS adminexpress")

write_sf(reg, cnx, Id(schema = "adminexpress", table = "region"))
dbExecute(cnx, "COMMENT ON TABLE adminexpress.region IS
$$polygones des régions françaises Adminexpress COG 2023
géométrie simplifiée pour carto nationale
EPSG:WGS84$$")
