# Récupération des données de température
# https://cds.climate.copernicus.eu/cdsapp#!/dataset/sis-agrometeorological-indicators


# config ------------------------------------------------------------------

library(ag5Tools)
library(glue)
library(tidyverse)
library(fs)

# installer python (Anaconda)
# installer l'appli CDS API
#
# $> pip install cdsapi

# Création du fichier de credentials nécessaire à l'appli CDS API
# variable d'environnement CDS_UID et CDS_API_KEY à récupérer depuis
# https://cds.climate.copernicus.eu/
write_lines(
  glue("url: https://cds.climate.copernicus.eu/api/v2\n",
       "key: {Sys.getenv('CDS_UID')}:{Sys.getenv('CDS_API_KEY')}"),
  path_expand("~/.cdsapirc"))


# paramètres --------------------------------------------------------------

rep_era5 <- glue(path_real("donnees/era5"), "/")


# téléchargement -----------------------------------------------------------

# Températures moyennes journalières
# 1 fichier NetCDF par jour -> 2 Go/an
# de 2007 (premier millésime du RPG) à 2022
2007:2022 %>%
  walk(~ ag5_download(variable = "2m_temperature",
                      statistic = "24_hour_mean",
                      day = "all",
                      month = "all",
                      year = .x,
                      path = rep_era5))


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
              path = rep_era5) %>%
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
