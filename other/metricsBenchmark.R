library(raster)
library(landscapemetrics)

metricsBenchmark <- function(landscape_filepath) {
  landscape <- raster(landscape_filepath)

  suffixes <- c("mn", "sd", "cv")

  patch_metrics <- c("lsm_p_area", "lsm_p_perim", "lsm_p_para", "lsm_p_shape", "lsm_p_frac", "lsm_p_enn")

  class_aggregation_metrics <- c()
  c_metrics = gsub("_p_", "_c_", patch_metrics)
  for(suffix in suffixes){class_aggregation_metrics <- c(class_aggregation_metrics, paste(c_metrics, suffix, sep="_"))}
  class_metrics <- c("lsm_c_ca", "lsm_c_pland", "lsm_c_np", "lsm_c_pd", "lsm_c_lpi", "lsm_c_te", "lsm_c_ed", "lsm_c_lsi")
  for(class_aggregation_metric in class_aggregation_metrics){class_metrics <- c(class_metrics, class_aggregation_metric)}

  landscape_aggregation_metrics <- c()
  l_metrics <- gsub("_p_", "_l_", patch_metrics)
  for(suffix in suffixes){landscape_aggregation_metrics <- c(landscape_aggregation_metrics, paste(l_metrics, suffix, sep="_"))}
  landscape_metrics <- c("lsm_l_ta", "lsm_l_np", "lsm_l_pd", "lsm_l_lpi", "lsm_l_te", "lsm_l_ed", "lsm_l_lsi", "lsm_l_contag", "lsm_l_shdi")
  for(landscape_aggregation_metric in landscape_aggregation_metrics){landscape_metrics <- c(landscape_metrics, landscape_aggregation_metric)}

  time <- system.time(result <- calculate_lsm(landscape, append(patch_metrics, append(class_metrics, landscape_metrics))))
  print(time)

  return(result)
}
