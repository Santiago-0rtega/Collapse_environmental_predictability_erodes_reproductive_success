#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(tidybayes)
})

args <- commandArgs(trailingOnly = TRUE)
data_dir <- if (length(args) >= 1) args[[1]] else "data"
model_dir <- if (length(args) >= 2) args[[2]] else "Rdata"
output_dir <- if (length(args) >= 3) args[[3]] else file.path("Rdata", "precomputed_draws")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

draw_path <- function(file) file.path(output_dir, file)

load_or_compute <- function(file, expr) {
  path <- draw_path(file)
  if (file.exists(path)) {
    message("Loading existing ", path)
    return(readRDS(path))
  }

  message("Computing ", file)
  value <- eval.parent(substitute(expr))
  saveRDS(value, path)
  value
}

normalise_year_column <- function(dat) {
  if ("X...YEAR" %in% names(dat) && !"YEAR" %in% names(dat)) {
    dat <- rename(dat, YEAR = X...YEAR)
  }
  dat
}

message("Loading data and fitted models")
bloom_dat_raw <- read.csv(file.path(data_dir, "bloom_dates.csv"))
female_dat_raw <- read.csv(file.path(data_dir, "Lay_date_mismatches_250702.csv")) %>%
  normalise_year_column()
male_dat_raw <- read.csv(file.path(data_dir, "Lay_date_mismatches_250702.csv")) %>%
  normalise_year_column()

bloom_model <- readRDS(file.path(model_dir, "model_delta5.rds"))
mismatch_modelf <- readRDS(file.path(model_dir, "female_fit_m11.rds"))
mismatch_modelm <- readRDS(file.path(model_dir, "male_fit_m11.rds"))
fledging_modelf <- readRDS(file.path(model_dir, "female_fit_Q17.rds"))
fledging_modelm <- readRDS(file.path(model_dir, "male_fit_Q17.rds"))

message("Preparing data exactly as in book/code_figures.qmd")
bloom_dat <- bloom_dat_raw %>%
  mutate(
    bloom_start_thr5_as_date = as.Date(bloom_start_thr5, format = "%d/%m/%Y"),
    winter_start_date = as.Date(paste0(season_year - 1, "-12-21")),
    delta5 = as.numeric(difftime(bloom_start_thr5_as_date, winter_start_date, units = "days")),
    season_year = as.numeric(season_year),
    TIME = as.numeric(scale(season_year, center = TRUE, scale = FALSE))
  )

dat_female_mismatch <- female_dat_raw %>%
  filter(SEX == 1) %>%
  mutate(
    ori_age = as.numeric(AGE),
    ori_time = as.numeric(YEAR),
    TIME = scale(YEAR, center = TRUE, scale = FALSE),
    AGE = scale(as.numeric(AGE), center = TRUE, scale = FALSE),
    AFR = scale(as.numeric(AFR), center = TRUE, scale = FALSE),
    LONGEVITY = scale(as.numeric(LONGEVITY), center = TRUE, scale = FALSE),
    YEAR = as.factor(YEAR),
    RING = as.factor(RING)
  )

dat_female_fledging <- female_dat_raw %>%
  filter(SEX == 1) %>%
  mutate(
    ori_age = as.numeric(AGE),
    ori_time = as.numeric(YEAR),
    TIME = scale(YEAR, center = TRUE, scale = FALSE),
    ZX5MISMATCH = scale(as.numeric(X5MISMATCH), center = TRUE, scale = FALSE),
    AGE = scale(as.numeric(AGE), center = TRUE, scale = FALSE),
    AFR = scale(as.numeric(AFR), center = TRUE, scale = FALSE),
    LONGEVITY = scale(as.numeric(LONGEVITY), center = TRUE, scale = FALSE),
    FLEDS = factor(FLEDS, levels = c(0, 1, 2, 3), ordered = TRUE)
  )

dat_male_mismatch <- male_dat_raw %>%
  filter(SEX == 0) %>%
  mutate(
    ori_age = as.numeric(AGE),
    ori_time = as.numeric(YEAR),
    TIME = scale(YEAR, center = TRUE, scale = FALSE),
    AGE = scale(as.numeric(AGE), center = TRUE, scale = FALSE),
    AFR = scale(as.numeric(AFR), center = TRUE, scale = FALSE),
    LONGEVITY = scale(as.numeric(LONGEVITY), center = TRUE, scale = FALSE),
    YEAR = as.factor(YEAR),
    RING = as.factor(RING)
  )

dat_male_fledging <- male_dat_raw %>%
  filter(SEX == 0) %>%
  mutate(
    ori_age = as.numeric(AGE),
    ori_time = as.numeric(YEAR),
    TIME = scale(YEAR, center = TRUE, scale = FALSE),
    ZX5MISMATCH = scale(as.numeric(X5MISMATCH), center = TRUE, scale = FALSE),
    AGE = scale(as.numeric(AGE), center = TRUE, scale = FALSE),
    AFR = scale(as.numeric(AFR), center = TRUE, scale = FALSE),
    LONGEVITY = scale(as.numeric(LONGEVITY), center = TRUE, scale = FALSE),
    FLEDS = factor(FLEDS, levels = c(0, 1, 2, 3), ordered = TRUE)
  )

message("Precomputing figure draws")

bloom_time_draws <- load_or_compute("bloom_time_draws.rds", {
  mean_bloom_year <- mean(bloom_dat$season_year)
  bloom_model %>%
    epred_draws(
      newdata = expand.grid(TIME = seq(min(bloom_dat$TIME), max(bloom_dat$TIME), length.out = 100)),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_year = TIME + mean_bloom_year)
})

mismatch_time_drawsf <- load_or_compute("mismatch_time_drawsf.rds", {
  mean_mismatch_yearf <- mean(dat_female_mismatch$ori_time)
  mismatch_modelf %>%
    epred_draws(
      newdata = expand.grid(
        TIME = seq(min(dat_female_mismatch$TIME), max(dat_female_mismatch$TIME), length.out = 100),
        AGE = mean(dat_female_mismatch$AGE),
        AFR = mean(dat_female_mismatch$AFR),
        LONGEVITY = mean(dat_female_mismatch$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_time = TIME + mean_mismatch_yearf)
})

mismatch_time_drawsm <- load_or_compute("mismatch_time_drawsm.rds", {
  mean_mismatch_yearm <- mean(dat_male_mismatch$ori_time)
  mismatch_modelm %>%
    epred_draws(
      newdata = expand.grid(
        TIME = seq(min(dat_male_mismatch$TIME), max(dat_male_mismatch$TIME), length.out = 100),
        AGE = mean(dat_male_mismatch$AGE),
        AFR = mean(dat_male_mismatch$AFR),
        LONGEVITY = mean(dat_male_mismatch$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_time = TIME + mean_mismatch_yearm)
})

fledging_time_drawsf <- load_or_compute("fledging_time_drawsf.rds", {
  mean_fledging_yearf <- mean(dat_female_fledging$ori_time)
  fledging_modelf %>%
    epred_draws(
      newdata = expand.grid(
        TIME = seq(min(dat_female_fledging$TIME), max(dat_female_fledging$TIME), length.out = 100),
        AGE = mean(dat_female_fledging$AGE),
        ZX5MISMATCH = mean(dat_female_fledging$ZX5MISMATCH),
        AFR = mean(dat_female_fledging$AFR),
        LONGEVITY = mean(dat_female_fledging$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_time = TIME + mean_fledging_yearf)
})

fledging_success_drawsf <- load_or_compute("fledging_success_drawsf.rds", {
  fledging_time_drawsf %>%
    filter(.category != "0") %>%
    group_by(across(-c(.epred, .category))) %>%
    summarize(prob_success = sum(.epred), .groups = "drop")
})

fledging_time_drawsm <- load_or_compute("fledging_time_drawsm.rds", {
  mean_fledging_yearm <- mean(dat_male_fledging$ori_time)
  fledging_modelm %>%
    epred_draws(
      newdata = expand.grid(
        TIME = seq(min(dat_male_fledging$TIME), max(dat_male_fledging$TIME), length.out = 100),
        AGE = mean(dat_male_fledging$AGE),
        ZX5MISMATCH = mean(dat_male_fledging$ZX5MISMATCH),
        AFR = mean(dat_male_fledging$AFR),
        LONGEVITY = mean(dat_male_fledging$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_time = TIME + mean_fledging_yearm)
})

fledging_success_drawsm <- load_or_compute("fledging_success_drawsm.rds", {
  fledging_time_drawsm %>%
    filter(.category != "0") %>%
    group_by(across(-c(.epred, .category))) %>%
    summarize(prob_success = sum(.epred), .groups = "drop")
})

age_draws_female <- load_or_compute("age_draws_female.rds", {
  mean_of_original_age_female <- mean(dat_female_mismatch$ori_age)
  mismatch_modelf %>%
    epred_draws(
      newdata = expand.grid(
        AGE = seq(min(dat_female_mismatch$AGE), max(dat_female_mismatch$AGE), length.out = 100),
        TIME = mean(dat_female_mismatch$TIME),
        AFR = mean(dat_female_mismatch$AFR),
        LONGEVITY = mean(dat_female_mismatch$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_age = AGE + mean_of_original_age_female)
})

age_draws_male <- load_or_compute("age_draws_male.rds", {
  mean_of_original_age_male <- mean(dat_male_mismatch$ori_age)
  mismatch_modelm %>%
    epred_draws(
      newdata = expand.grid(
        AGE = seq(min(dat_male_mismatch$AGE), max(dat_male_mismatch$AGE), length.out = 100),
        TIME = mean(dat_male_mismatch$TIME),
        AFR = mean(dat_male_mismatch$AFR),
        LONGEVITY = mean(dat_male_mismatch$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_age = AGE + mean_of_original_age_male)
})

individual_predictions_female <- load_or_compute("individual_predictions_female.rds", {
  set.seed(42)
  rings_to_plot_female <- sample(unique(dat_female_mismatch$RING), 50)
  newdata_grid_female <- expand.grid(
    AGE = seq(min(dat_female_mismatch$AGE), max(dat_female_mismatch$AGE), length.out = 100),
    RING = rings_to_plot_female,
    TIME = mean(dat_female_mismatch$TIME),
    AFR = mean(dat_female_mismatch$AFR),
    LONGEVITY = mean(dat_female_mismatch$LONGEVITY)
  )
  mean_of_original_age_female <- mean(dat_female_mismatch$ori_age)
  mismatch_modelf %>%
    add_linpred_draws(newdata = newdata_grid_female, re_formula = ~(1 + AGE | RING)) %>%
    group_by(RING, AGE) %>%
    summarise(.value = median(.linpred), .groups = "drop") %>%
    mutate(actual_age = AGE + mean_of_original_age_female)
})

individual_predictions_male <- load_or_compute("individual_predictions_male.rds", {
  set.seed(42)
  rings_to_plot_male <- sample(unique(dat_male_mismatch$RING), 50)
  newdata_grid_male <- expand.grid(
    AGE = seq(min(dat_male_mismatch$AGE), max(dat_male_mismatch$AGE), length.out = 100),
    RING = rings_to_plot_male,
    TIME = mean(dat_male_mismatch$TIME),
    AFR = mean(dat_male_mismatch$AFR),
    LONGEVITY = mean(dat_male_mismatch$LONGEVITY)
  )
  mean_of_original_age_male <- mean(dat_male_mismatch$ori_age)
  mismatch_modelm %>%
    add_linpred_draws(newdata = newdata_grid_male, re_formula = ~(1 + AGE | RING)) %>%
    group_by(RING, AGE) %>%
    summarise(.value = median(.linpred), .groups = "drop") %>%
    mutate(actual_age = AGE + mean_of_original_age_male)
})

individual_predictions_female_si <- load_or_compute("individual_predictions_female_si.rds", {
  set.seed(42)
  rings_to_plot_female <- sample(unique(dat_female_mismatch$RING), 10)
  newdata_grid_female <- expand.grid(
    AGE = seq(min(dat_female_mismatch$AGE), max(dat_female_mismatch$AGE), length.out = 100),
    RING = rings_to_plot_female,
    TIME = mean(dat_female_mismatch$TIME),
    AFR = mean(dat_female_mismatch$AFR),
    LONGEVITY = mean(dat_female_mismatch$LONGEVITY)
  )
  mean_of_original_age_female <- mean(dat_female_mismatch$ori_age)
  mismatch_modelf %>%
    add_linpred_draws(newdata = newdata_grid_female, re_formula = ~(1 + AGE | RING)) %>%
    group_by(RING, AGE) %>%
    summarise(.value = median(.linpred), .groups = "drop") %>%
    mutate(actual_age = AGE + mean_of_original_age_female)
})

individual_predictions_male_si <- load_or_compute("individual_predictions_male_si.rds", {
  set.seed(42)
  rings_to_plot_male <- sample(unique(dat_male_mismatch$RING), 10)
  newdata_grid_male <- expand.grid(
    AGE = seq(min(dat_male_mismatch$AGE), max(dat_male_mismatch$AGE), length.out = 100),
    RING = rings_to_plot_male,
    TIME = mean(dat_male_mismatch$TIME),
    AFR = mean(dat_male_mismatch$AFR),
    LONGEVITY = mean(dat_male_mismatch$LONGEVITY)
  )
  mean_of_original_age_male <- mean(dat_male_mismatch$ori_age)
  mismatch_modelm %>%
    add_linpred_draws(newdata = newdata_grid_male, re_formula = ~(1 + AGE | RING)) %>%
    group_by(RING, AGE) %>%
    summarise(.value = median(.linpred), .groups = "drop") %>%
    mutate(actual_age = AGE + mean_of_original_age_male)
})

fledging_age_drawsf <- load_or_compute("fledging_age_drawsf.rds", {
  mean_of_original_fledging_agef <- mean(dat_female_fledging$ori_age)
  fledging_modelf %>%
    epred_draws(
      newdata = expand.grid(
        AGE = seq(min(dat_female_fledging$AGE), max(dat_female_fledging$AGE), length.out = 100),
        TIME = mean(dat_female_fledging$TIME),
        ZX5MISMATCH = mean(dat_female_fledging$ZX5MISMATCH),
        AFR = mean(dat_female_fledging$AFR),
        LONGEVITY = mean(dat_female_fledging$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_age = AGE + mean_of_original_fledging_agef)
})

fledging_success_draws_agef <- load_or_compute("fledging_success_draws_agef.rds", {
  fledging_age_drawsf %>%
    filter(.category != "0") %>%
    group_by(across(-c(.epred, .category))) %>%
    summarize(prob_success = sum(.epred), .groups = "drop")
})

fledging_age_drawsm <- load_or_compute("fledging_age_drawsm.rds", {
  mean_of_original_fledging_agem <- mean(dat_male_fledging$ori_age)
  fledging_modelm %>%
    epred_draws(
      newdata = expand.grid(
        AGE = seq(min(dat_male_fledging$AGE), max(dat_male_fledging$AGE), length.out = 100),
        TIME = mean(dat_male_fledging$TIME),
        ZX5MISMATCH = mean(dat_male_fledging$ZX5MISMATCH),
        AFR = mean(dat_male_fledging$AFR),
        LONGEVITY = mean(dat_male_fledging$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_age = AGE + mean_of_original_fledging_agem)
})

fledging_success_draws_agem <- load_or_compute("fledging_success_draws_agem.rds", {
  fledging_age_drawsm %>%
    filter(.category != "0") %>%
    group_by(across(-c(.epred, .category))) %>%
    summarize(prob_success = sum(.epred), .groups = "drop")
})

mismatch_drawsf <- load_or_compute("mismatch_drawsf.rds", {
  mean_of_original_mismatchf <- mean(dat_female_fledging$X5MISMATCH, na.rm = TRUE)
  fledging_modelf %>%
    epred_draws(
      newdata = expand.grid(
        ZX5MISMATCH = seq(min(dat_female_fledging$ZX5MISMATCH), max(dat_female_fledging$ZX5MISMATCH), length.out = 100),
        TIME = mean(dat_female_fledging$TIME),
        AGE = mean(dat_female_fledging$AGE),
        AFR = mean(dat_female_fledging$AFR),
        LONGEVITY = mean(dat_female_fledging$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_mismatch = ZX5MISMATCH + mean_of_original_mismatchf)
})

fledging_grouped_drawsf <- load_or_compute("fledging_grouped_drawsf.rds", {
  mismatch_drawsf %>%
    mutate(fled_group = case_when(
      .category == "0" ~ "0",
      .category %in% c("1", "2") ~ "1-2",
      .category == "3" ~ "3",
      TRUE ~ NA_character_
    )) %>%
    filter(!is.na(fled_group)) %>%
    group_by(actual_mismatch, .draw, fled_group) %>%
    summarize(prob_val = sum(.epred), .groups = "drop")
})

mismatch_drawsm <- load_or_compute("mismatch_drawsm.rds", {
  mean_of_original_mismatchm <- mean(dat_male_fledging$X5MISMATCH, na.rm = TRUE)
  fledging_modelm %>%
    epred_draws(
      newdata = expand.grid(
        ZX5MISMATCH = seq(min(dat_male_fledging$ZX5MISMATCH), max(dat_male_fledging$ZX5MISMATCH), length.out = 100),
        TIME = mean(dat_male_fledging$TIME),
        AGE = mean(dat_male_fledging$AGE),
        AFR = mean(dat_male_fledging$AFR),
        LONGEVITY = mean(dat_male_fledging$LONGEVITY)
      ),
      re_formula = NA,
      dpar = TRUE
    ) %>%
    mutate(actual_mismatch = ZX5MISMATCH + mean_of_original_mismatchm)
})

fledging_grouped_drawsm <- load_or_compute("fledging_grouped_drawsm.rds", {
  mismatch_drawsm %>%
    mutate(fled_group = case_when(
      .category == "0" ~ "0",
      .category %in% c("1", "2") ~ "1-2",
      .category == "3" ~ "3",
      TRUE ~ NA_character_
    )) %>%
    filter(!is.na(fled_group)) %>%
    group_by(actual_mismatch, .draw, fled_group) %>%
    summarize(prob_val = sum(.epred), .groups = "drop")
})

manifest <- tibble(
  file = list.files(output_dir, pattern = "\\.rds$", full.names = FALSE),
  bytes = file.info(file.path(output_dir, file))$size
)
write_csv(manifest, file.path(output_dir, "draw_manifest.csv"))
capture.output(sessionInfo(), file = file.path(output_dir, "sessionInfo.txt"))

message("Done. Precomputed draw files written to: ", normalizePath(output_dir))
