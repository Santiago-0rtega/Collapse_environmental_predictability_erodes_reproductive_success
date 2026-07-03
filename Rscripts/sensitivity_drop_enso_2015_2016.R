#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
})

args <- commandArgs(trailingOnly = TRUE)
data_path <- if (length(args) >= 1) args[[1]] else file.path("data", "Lay_date_mismatches_250702.csv")
output_dir <- if (length(args) >= 2) args[[2]] else file.path("Rdata", "drop_enso_2015_2016")
threads_per_chain <- if (length(args) >= 3) as.integer(args[[3]]) else 12L

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(STAN_NUM_THREADS = threads_per_chain)
options(mc.cores = 4)

sampling_args <- list(
  iter = 6000,
  warmup = 2000,
  chains = 4,
  seed = 123,
  init = 0,
  backend = "cmdstanr",
  threads = threading(threads_per_chain),
  control = list(adapt_delta = 0.99, max_treedepth = 15)
)

prepare_data <- function(sex_value, response = c("mismatch", "fledging")) {
  response <- match.arg(response)

  raw_dat <- read.csv(data_path)
  if ("X...YEAR" %in% names(raw_dat) && !"YEAR" %in% names(raw_dat)) {
    raw_dat <- rename(raw_dat, YEAR = X...YEAR)
  }

  raw_dat %>%
    filter(SEX == sex_value, !YEAR %in% c(2015, 2016)) %>%
    mutate(
      across(c(X5MISMATCH, AGE, AFR, LONGEVITY), as.numeric),
      TIME = scale(YEAR, center = TRUE, scale = FALSE)[, 1],
      ZX5MISMATCH = scale(X5MISMATCH, center = TRUE, scale = FALSE)[, 1],
      AGE = scale(AGE, center = TRUE, scale = FALSE)[, 1],
      AFR = scale(AFR, center = TRUE, scale = FALSE)[, 1],
      LONGEVITY = scale(LONGEVITY, center = TRUE, scale = FALSE)[, 1],
      YEAR = as.factor(YEAR),
      RING = as.factor(RING)
    ) %>%
    mutate(
      FLEDS = if (response == "fledging") {
        factor(FLEDS, levels = 0:3, ordered = TRUE)
      } else {
        FLEDS
      }
    )
}

fit_and_save <- function(fit_name, formula, data, family) {
  model_path <- file.path(output_dir, paste0(fit_name, ".rds"))
  summary_path <- file.path(output_dir, paste0(fit_name, "_summary.txt"))

  if (file.exists(model_path)) {
    message("Skipping existing model: ", model_path)
    return(invisible(readRDS(model_path)))
  }

  message("Fitting ", fit_name)
  fit <- brm(
    formula = formula,
    data = data,
    prior = get_prior(formula, data = data, family = family),
    family = family,
    iter = sampling_args$iter,
    warmup = sampling_args$warmup,
    chains = sampling_args$chains,
    seed = sampling_args$seed,
    init = sampling_args$init,
    backend = sampling_args$backend,
    threads = sampling_args$threads,
    control = sampling_args$control
  )

  saveRDS(fit, model_path)
  capture.output(summary(fit), file = summary_path)
  invisible(fit)
}

mismatch_formula <- bf(
  X5MISMATCH ~ AGE + I(AGE^2) + TIME + AFR + LONGEVITY +
    (1 + AGE | q | RING) + (1 | YEAR),
  sigma ~ 1 + AGE + I(AGE^2) + TIME + (1 | q | RING),
  nl = FALSE
)

fledging_formula <- bf(
  FLEDS ~ ZX5MISMATCH + I(ZX5MISMATCH^2) + TIME + AGE + I(AGE^2) + AFR + LONGEVITY +
    (1 | q | RING) + (1 | YEAR),
  disc ~ 1 + ZX5MISMATCH + AGE + TIME + (1 | q | RING),
  nl = FALSE
)

female_mismatch <- prepare_data(sex_value = 1, response = "mismatch")
male_mismatch <- prepare_data(sex_value = 0, response = "mismatch")
female_fledging <- prepare_data(sex_value = 1, response = "fledging")
male_fledging <- prepare_data(sex_value = 0, response = "fledging")

sample_sizes <- bind_rows(
  female_mismatch %>% count(YEAR, name = "n") %>% mutate(sex = "female"),
  male_mismatch %>% count(YEAR, name = "n") %>% mutate(sex = "male")
) %>%
  select(sex, YEAR, n)

write_csv(sample_sizes, file.path(output_dir, "sample_sizes_after_dropping_2015_2016.csv"))

fit_and_save(
  "female_mismatch_m11_drop_2015_2016",
  mismatch_formula,
  female_mismatch,
  gaussian()
)

fit_and_save(
  "male_mismatch_m11_drop_2015_2016",
  mismatch_formula,
  male_mismatch,
  gaussian()
)

fit_and_save(
  "female_fledging_Q17_drop_2015_2016",
  fledging_formula,
  female_fledging,
  cumulative(link = "probit")
)

fit_and_save(
  "male_fledging_Q17_drop_2015_2016",
  fledging_formula,
  male_fledging,
  cumulative(link = "probit")
)

message("Done. Results written to: ", normalizePath(output_dir))
