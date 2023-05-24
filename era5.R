# Récupération des données de température
# https://cds.climate.copernicus.eu/cdsapp#!/dataset/sis-agrometeorological-indicators


# paramètres --------------------------------------------------------------

rep_era5 <- "donnees/era5"


# config ------------------------------------------------------------------

library(ag5Tools)
library(glue)
library(tidyverse)
library(fs)

# ag5Tools a besoin de python et de l'appli d'accès à copernicus ----------

## windows ----
# installer python (Anaconda)
# installer l'appli CDS API
#
# $> pip install cdsapi

## SSPLab ----
system("curl -sSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py")
system("python3 get-pip.py")
system('export PATH="/home/onyxia/.local/bin" && pip3 install cdsapi')

## config ----
# Création du fichier de credentials nécessaire à l'appli CDS API
# variable d'environnement CDS_UID et CDS_API_KEY à récupérer depuis
# https://cds.climate.copernicus.eu/
write_lines(
  glue("url: https://cds.climate.copernicus.eu/api/v2\n",
       "key: {Sys.getenv('CDS_UID')}:{Sys.getenv('CDS_API_KEY')}"),
  path_expand("~/.cdsapirc"))

dir_create(rep_era5)
rep_era5_full <- glue(path_real(rep_era5), "/")


# téléchargement -----------------------------------------------------------

# Températures moyennes journalières
# 1 fichier NetCDF par jour -> 2 Go/an
# de 2007 (premier millésime du RPG) à 2022
2015:2021 %>%
  walk(~ ag5_download(variable = "2m_temperature",
                      statistic = "24_hour_mean",
                      day = "all",
                      month = "all",
                      year = .x,
                      path = rep_era5_full))


# stockage ----------------------------------------------------------------

# avec la valeur dans
# Mon compte > Connexion au stockage > Pour accéder au stockage > MC client
# $ export MC_HOST_s3=...
#
# $ mc cp -r funathon2023_sujet2/donnees/era5/2022/ s3/projet-funathon/2023/sujet2/era5/2022

# ex. utilisation ---------------------------------------------------------

# un exemple de localisations avec date début-fin
points <- tribble(~ville,       ~lon,   ~lat, ~start_date,  ~end_date,
                  "Talissieu", 5.725, 45.864, "2022-01-01", "2022-12-31",
                  "Toulouse",  1.434, 43.591, "2022-01-01", "2022-12-31") %>%
  mutate(id = row_number())

# Extraction des températures moyennes journalières à ces points
temp_points <- points %>%
  as.data.frame() %>%
  ag5_extract(variable = "Temperature-Air-2m",
              statistic = "Mean-24h",
              celsius = TRUE,
              path = rep_era5_full) %>%
  imap(~ pivot_longer(.x,
                      everything(),
                      names_to = "date",
                      values_to = "temp_moy_c",
                      names_transform = ymd) %>%
         mutate(id = .y)) %>%
  bind_rows() %>%
  inner_join(points, by = "id")

temp_points %>%
  ggplot(aes(date, temp_moy_c, color = ville)) +
  geom_point(alpha = 0.3) +
  geom_smooth(span = 0.2)


