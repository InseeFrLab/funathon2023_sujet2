###
# Fonctions et données utilitaires pour l'application RShiny.
###
library(sf)
library(aws.s3)
library(janitor)
library(readr)
library(RPostgres)
library(RColorBrewer)
library(dplyr)
library(leaflet)


# Récupération des libellés des différentes cultures
lib_cult <- s3read_using(FUN = read_csv2,
                         object = "2023/sujet2/diffusion/ign/rpg/REF_CULTURES_GROUPES_CULTURES_2020.csv",
                         col_types = cols(.default = col_character()),
                         bucket = "projet-funathon",
                         opts = list("region" = "")) %>% clean_names()


lib_group_cult <- lib_cult %>% 
  select(code_groupe_culture, libelle_groupe_culture) %>% 
  distinct(code_groupe_culture, .keep_all=T)


# Création d'une palette de couleurs associée au groupe de culture
pal <- brewer.pal(12, "Paired")
pal <- colorRampPalette(pal)(24)
factpal <- colorFactor(pal, lib_group_cult$code_groupe_culture)


#' Connection au serveur PostgreSQL. Le mot de passe doit être stocké dans la
#' variable d'environnement PASS_POSTGRESQL.
#' 
#' @returns Connexion au serveur.
connect_to_db <- function() {
  # Connection à PostgreSQL
  cnx <- dbConnect(Postgres(),
                   user = "projet-funathon",
                   password = Sys.getenv("PASS_POSTGRESQL"),
                   host = "postgresql-438832",
                   dbname = "defaultdb",
                   port = 5432,
                   check_interrupts = TRUE)
  
  return(cnx)
}


#' Requête la table `parcelles` pour récupérer les parcelles qui se situent
#' dans un certain rayon autour d'un point repéré par une latitude et 
#' une longitude.
#' 
#' @param cnx Connexion à PostgreSQL.
#' @param lat Latitude.
#' @param lng Longitude.
#' @param radius Rayon.
#' @returns Objet `sf` avec les données des parcelles concernées.
query_db <- function(cnx, lat, lng, radius) {
  # Les données spatiales sur PostgreSQL sont stockées en Lambert 93.
  # Pour faire le join on veut donc projeter les coordonnées `lat`` et `lng`
  postgis_crs <- "EPSG:2154"
  coordinates <- data.frame(lng = c(lng), lat = c(lat)) %>%
    st_as_sf(coords = c("lng", "lat"), remove = TRUE) %>%
    st_set_crs("EPSG:4326") %>%
    st_transform(postgis_crs)
  
  # Requête PostgreSQL
  query <- sprintf(
    "SELECT * FROM rpg.parcelles WHERE ST_Intersects(geom, ST_Buffer(ST_SetSRID(ST_MakePoint(%f, %f), 2154), %.0f));",
    st_coordinates(coordinates)[1],
    st_coordinates(coordinates)[2],
    radius*1000)
  
  # Récupération des résultats
  sf <- st_read(
    cnx,
    query = query
  )
  
  return(sf)
}


#' Rajoute les données d'un objet `sf` sous forme de polygones à une
#' carte `leaflet`.
#' 
#' @param leaflet_proxy Carte.
#' @param sf Données spatiales.
#' @returns Carte enrichie.
plot_surroundings <- function(leaflet_proxy, sf) {
  # Transformation de la projection (WGS 84)
  sf <- sf %>% st_transform(4326)
  
  # Ajout des libellés des cultures
  sf <- sf %>% 
    left_join(lib_cult %>% select(-code_groupe_culture), by = c("code_cultu" = "code_culture")) 
  
  # Création des labels à afficher au passage de la souris sur la carte.
  labels <- sprintf("<strong>Identifiant de la parcelle : </strong>%s<br/>
                    <strong>Groupe culture : </strong>%s<br/>
                    <strong>Culture : </strong>%s<br/>
                    <strong>Surface (ha) : </strong>%s<br/>
                    <strong>Département : </strong>%s<br/>
                    <strong>Commune : </strong>%s<br/>",
                    sf$id_parcel,
                    sf$libelle_groupe_culture,
                    sf$libelle_culture,
                    sf$surf_parc,
                    sf$insee_dep,
                    sf$nom_com) %>%
    lapply(htmltools::HTML)
  
  return(
    leaflet_proxy %>%
    addPolygons(
      data = sf,
      fillColor = ~factpal(code_group),
      weight = 2,
      opacity = 1,
      color = "#ffd966",
      dashArray = "3",
      fillOpacity = 0.5,
      highlight = highlightOptions(
        weight = 5,
        color = "#A40000",
        dashArray = "",
        fillOpacity = 0.0,
        bringToFront = TRUE),
      label = labels,
      labelOptions = labelOptions(
        style = list("font-weight" = "normal", padding = "3px 8px"),
        textsize = "15px",
        direction = "auto",
        encoding="UTF-8"))
  )
}


#' Crée la table à afficher sur l'application grâce à des calculs sur les
#' données requêtées depuis PostgreSQL.
#' 
#' @param sf Données spatiales.
#' @returns data.frame à afficher.
compute_stats <- function(sf) {
  df <- sf %>% 
    st_drop_geometry() %>%
    count(code_group, name = "parcelles_grp") %>%
    add_tally(parcelles_grp, name = "parcelles_tot") %>%
    mutate(pct_parcelles = round(100*parcelles_grp/parcelles_tot, 1)) %>%
    select(-parcelles_tot) %>%
    cbind(
      # Comptage des surfaces
      sf %>% 
        st_drop_geometry() %>%
        count(code_group, wt = surf_parc, name = "surface_grp") %>% 
        add_tally(surface_grp, name = "surface_tot") %>% 
        mutate(surface_pct = round(100*surface_grp/surface_tot, 1)) %>%
        select(-surface_tot) %>%
        select(surface_grp, surface_pct)
      ) %>% 
    left_join(lib_group_cult, by = c("code_group" = "code_groupe_culture")) %>% 
    select(code_group, libelle_groupe_culture, everything()) %>% 
    arrange(desc(surface_grp)) %>% 
    adorn_totals() %>% 
    mutate(mean_surface = round(surface_grp/parcelles_grp, 1))

  return(
    df %>%
      select(-code_group) %>%
      setNames(
        c(
          "Groupe de cultures",
          "Nombre de parcelles",
          "Pourcentage de parcelles",
          "Surface (ha)",
          "Surface (%)",
          "Surface moyenne d'une parcelle (ha)"))
  )
}
