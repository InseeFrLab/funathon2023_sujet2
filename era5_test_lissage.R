# Lissage
#
# michael.delorme - 2021-08-26



# utils -------------------------------------------------------------------

#' rounding
#' from plyr
#'
#' @param x
#' @param accuracy
#' @param f
#'
#' @return
round_any <- function(x, accuracy, f = round) {
  
  f(x / accuracy) * accuracy
}

#' Generate a grid of coordinates from a spatial layer
#'
#' Memoised to get a faster result when used multiple times on the same extent
#'
#' @param zone sf object (polygons) : spatial extent
#' @param margin number : buffer of bounding box
#' @param resolution number : distance between nodes
#'
#' @return dataframe of coordinates (x, y)
generate_grid <- memoise::memoise(function(zone, margin, resolution) {
  
  zone_bbox <- sf::st_bbox(zone)
  
  zone %>%
    sf::st_make_grid(cellsize = resolution,
                     offset = c(round_any(zone_bbox[1] - margin, resolution, floor),
                                round_any(zone_bbox[2] - margin, resolution, floor)),
                     what = "centers") %>%
    sf::st_sf() %>%
    sf::st_join(zone, join = st_intersects, left = FALSE) %>%
    sf::st_coordinates() %>%
    tibble::as_tibble() %>%
    dplyr::select(x = X, y = Y)
})


# main function -----------------------------------------------------------

#' Kernel weighted smoothing with arbitrary bounding area
#'
#' @param df sf object (points) : features to smooth
#' @param field expression : weight field in df (unquoted) ; the values must not have NAs
#' @param bandwidth numeric : kernel bandwidth (output map units)
#' @param resolution numeric : output grid resolution (output map units)
#' @param zone sf objet (polygons) : study zone boundary. If null will use df extent
#' @param out_crs integer : EPSG code projection for output raster (should be an equal-area projection)
#' @param ... other arguments passed to btb::kernelSmoothing
#'
#' @return a raster object
#' @export
#' @import btb, raster, fasterize, dplyr, sf, rlang, memoise
lissage <- function(df, field, bandwidth, resolution, zone = NULL, out_crs = 3035, ...) {
  
  field_name <- rlang::as_name(rlang::enquo(field))
  
  if (!"sf" %in% class(df)
      | sf::st_geometry_type(df, FALSE) != "POINT") {
    stop("« df » should be a point sf object.")
  }
  
  if (!is.numeric(bandwidth)) stop("bandwidth sould be numeric.")
  if (!is.numeric(resolution)) stop("resolution sould be numeric.")
  
  nb_na <- sum(is.na(dplyr::pull(df, {{field}})))
  if (nb_na > 0) {
    warning(paste("removing", nb_na, "NA",
                  paste0("value", ifelse(nb_na > 1, "s", "")),
                  "in «", field_name, "»..."))
    df <- tidyr::drop_na(df, {{field}}) %>%
      sf::st_as_sf()
  }
  
  # check projections
  if (is.na(sf::st_crs(df))) {
    stop("missing projection in sf object « df ».")
  }
  
  if (sf::st_crs(df)$epsg != out_crs) {
    message("reprojecting data...")
    df <- sf::st_transform(df, out_crs)
  }
  
  if (!is.null(zone)) {
    if (!"sf" %in% class(zone)
        |!sf::st_geometry_type(zone, FALSE) %in% c("POLYGON", "MULTIPOLYGON")) {
      stop("« zone » should be a polygon/multiploygon sf object.")
    }
    
    # check projections
    if (is.na(sf::st_crs(zone))) {
      stop("missing projection in sf object « zone ».")
    }
    
    if (sf::st_crs(zone)$epsg != out_crs) {
      message("reprojecting study zone...")
      zone <- sf::st_transform(zone, out_crs)
    }
    
    # grid generation
    if (memoise::has_cache(generate_grid)(zone, bandwidth, resolution)) {
      message("retrieving reference grid from cache...")
    } else {
      message("generating reference grid...")
    }
    
    zone_xy <- generate_grid(zone, bandwidth, resolution)
    zone_bbox <- sf::st_bbox(zone)
    
  } else {
    message("using default reference grid...")
    
    zone_xy <- NULL
    zone_bbox <- sf::st_bbox(df)
  }
  
  # kernel
  message(paste0("computing kernel on « ", field_name, " »..."))
  kernel <- df %>%
    bind_cols(., sf::st_coordinates(.) %>% # si pas de données renvoie vecteur non nommé
                as.data.frame() %>%     # donc on le modifie
                set_names(c("x", "y"))) %>%
    sf::st_drop_geometry() %>%
    dplyr::select(x, y, {{ field }}) %>%
    btb::btb_smooth(sEPSG = out_crs,
                    iCellSize = resolution,
                    iBandwidth = bandwidth,
                    dfCentroids = zone_xy, ...)
  
  # rasterization
  message("\nrasterizing...")
  raster::raster(xmn = round_any(zone_bbox[1] - bandwidth, resolution, floor),
                 ymn = round_any(zone_bbox[2] - bandwidth, resolution, floor),
                 xmx = round_any(zone_bbox[3] + bandwidth, resolution, ceiling),
                 ymx = round_any(zone_bbox[4] + bandwidth, resolution, ceiling),
                 resolution = resolution,
                 crs = sf::st_crs(out_crs)$input
  ) %>%
    fasterize::fasterize(kernel, ., field = field_name)
}

fr <- read_sf(cnx, query = "
  SELECT 
    st_union(st_transform(geom, 3035)) as geom
  FROM adminexpress.region
  WHERE insee_reg > '06'")

com <- read_sf(cnx, query = "
  SELECT 
    nom,
    population,
    st_transform(geom, 3035) as geom
  FROM adminexpress.commune
  WHERE insee_reg > '06'")

mais <- read_sf(cnx, query = "
  SELECT 
    st_transform(st_pointonsurface(geom), 3035) as geom,
    surf_parc
  FROM rpg.parcelles
  WHERE code_cultu = 'MIS'")

library(terra)

mais_liss <- mais %>% 
  lissage(surf_parc, 10000, 1000, zone = fr) %>% 
  rast()

plot(mais_liss)
plot(mais_liss > 8)

cluster_liss <- (mais_liss > 8) %>% 
  as.polygons() %>% 
  st_as_sf() %>% 
  filter(layer == 1) %>% 
  st_cast("POLYGON") %>% 
  mutate(surf = st_area(geometry)) %>% 
  slice_max(surf, n = 10) %>% 
  mutate(id = row_number())

mapview(cluster_liss)

noms <- cluster_liss %>% 
  st_join(com, left = TRUE) %>% 
  st_drop_geometry() %>% 
  group_by(id) %>% 
  slice_max(population, n = 1, with_ties = FALSE) %>% 
  select(id, nom)

points <- cluster_liss %>% 
  inner_join(noms) %>% 
  st_point_on_surface() %>% 
  st_transform("EPSG:4326")


era5 <- dir_ls(rep_era5, recurse = TRUE, glob = "*.nc") %>% 
  read_stars() %>% 
  rename(temp_moy_k = 1)

temp_points <- era5 %>% 
  st_extract(points) %>%
  as_tibble() %>% 
  mutate(temp_moy_c = temp_moy_k - 273.15,
         date = as_date(time)) %>% 
  full_join(points, ., by = "geometry")



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
  select(date, annee, nom)

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



