# Récupération des données de température passées ERA5
# Monde entier - raster (netCDF), environ 10 km / pixel
# https://cds.climate.copernicus.eu/cdsapp#!/dataset/sis-agrometeorological-indicators


# paramètres --------------------------------------------------------------

# où sauver les données dans le stockage "local"
rep_era5 <- "donnees/era5"

# Années(s) à télécharger
# de 2015 (premier millésime du RPG  utilisé dans nos exemples) à 2022
# periode <- 2022
periode <- 2015:2022


# config ------------------------------------------------------------------

install.packages("ag5Tools")

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
# et stockées dans ~/.Renviron
write_lines(
  glue("url: https://cds.climate.copernicus.eu/api/v2\n",
       "key: {Sys.getenv('CDS_UID')}:{Sys.getenv('CDS_API_KEY')}"),
  path_expand("~/.cdsapirc"))

dir_create(rep_era5)
rep_era5_full <- glue(path_real(rep_era5), "/")

Sys.setlocale("LC_ALL", "fr_FR.UTF-8")


# téléchargement -----------------------------------------------------------

# Températures moyennes journalières
# 1 fichier NetCDF par jour -> 2 Go/an
# 40 min/an
periode %>%
  walk(~ ag5_download(variable = "2m_temperature",
                      statistic = "24_hour_mean",
                      day = "all",
                      month = "all",
                      year = .x,
                      path = rep_era5_full))


# sauvegarde vers stockage persitant S3 -----------------------------------

# s'il y a eu "déconnexion", avec la valeur dans
# Mon compte > Connexion au stockage > Pour accéder au stockage > MC client
# $ export MC_HOST_s3=...
# puis par ex. :
# $ mc cp -r funathon2023_sujet2/donnees/era5/2022/ s3/projet-funathon/2023/sujet2/era5/2022

# ne marche pas (?) :
# periode %>%
#   walk(~ system(glue("export MC_HOST_s3=\"{Sys.getenv('MC_HOST_s3')}\" && mc cp -r {rep_era5_full}{.x}/ s3/projet-funathon/2023/sujet2/era5/{.x}")))


# ex. utilisation ---------------------------------------------------------

# copier les données
system(glue("mc cp -r  s3/projet-funathon/2023/sujet2/era5 {rep_era5_full}"))

# un exemple de localisations avec date début-fin
points <- tribble(~ville,       ~lon,   ~lat, ~start_date,  ~end_date,
                  "Talissieu", 5.725, 45.864, "2015-01-01", "2022-12-31",
                  "Toulouse",  1.434, 43.591, "2015-01-01", "2022-12-31") %>%
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

# exemple graphique pour toutes les villes en 2022
temp_points %>%
  filter(year(date) == 2022) %>% 
  ggplot(aes(date, temp_moy_c, color = ville)) +
  geom_point(alpha = 0.3) +
  geom_smooth(span = 0.2)

# exemple graphique une ville, toutes les années
ville_sel <- "Toulouse"
temp_points %>%
  filter(ville == ville_sel) %>% 
  mutate(annee = year(date),
         jour_virtuel = as.Date(glue("2020-{format(date, '%j')}"), "%Y-%j")) %>% 
  ggplot(aes(jour_virtuel, temp_moy_c, group = annee, color = factor(annee))) +
  geom_point(alpha = 0.3) +
  geom_smooth(span = 0.2, se = FALSE) +
  scale_color_viridis_d(guide = guide_legend(reverse = TRUE)) +
  scale_x_date(date_breaks = "months", date_labels = "%b") +
  labs(title = "Température",
       subtitle = ville_sel,
       x = "jour",
       y = "température moyenne journalière (°C)",
       color = "année")


