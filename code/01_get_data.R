# 01_get_data.R
# Pulls World Bank indicators for G7 countries via the WDI package,
# saves the raw download, then builds the cleaned panel used for all figures.
# Run from the repo root (open blog4-brexit.Rproj first).

library(WDI)
library(dplyr)
library(readr)

# ---- Settings ----------------------------------------------------------
g7 <- c("GB", "US", "CA", "FR", "DE", "IT", "JP")

indicators <- c(
  gdp_pc     = "NY.GDP.PCAP.KD",   # real GDP per capita, constant 2015 US$
  invest_gdp = "NE.GDI.FTOT.ZS",   # gross fixed capital formation, % of GDP
  trade_gdp  = "NE.TRD.GNFS.ZS"    # exports + imports, % of GDP
)

base_year <- 2016  # referendum year, index = 100

# ---- Download ----------------------------------------------------------
raw <- WDI(country = g7, indicator = indicators, start = 2000, end = 2025)

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
write_csv(raw, "data/raw/wdi_raw.csv")

# ---- Clean -------------------------------------------------------------
panel <- raw |>
  select(country, iso2c, year, gdp_pc, invest_gdp, trade_gdp) |>
  filter(!is.na(gdp_pc)) |>
  arrange(country, year) |>
  group_by(country) |>
  mutate(gdp_pc_idx = gdp_pc / gdp_pc[year == base_year] * 100) |>
  ungroup()

# ---- Counterfactual: unweighted average of the other six G7 countries --
vars <- c("gdp_pc_idx", "invest_gdp", "trade_gdp")

peers <- panel |>
  filter(iso2c != "GB") |>
  group_by(year) |>
  summarise(across(all_of(vars), \(x) mean(x, na.rm = TRUE))) |>
  mutate(country = "G7 average (ex-UK)")

uk <- panel |>
  filter(iso2c == "GB") |>
  select(year, country, all_of(vars))

comparison <- bind_rows(uk, peers) |>
  arrange(year, country)

# ---- Save --------------------------------------------------------------
write_csv(panel, "data/processed/g7_panel.csv")
write_csv(comparison, "data/processed/uk_vs_peers.csv")

# ---- Quick coverage check ----------------------------------------------
panel |>
  group_by(country) |>
  summarise(first = min(year), last = max(year),
            missing_invest = sum(is.na(invest_gdp)),
            missing_trade  = sum(is.na(trade_gdp))) |>
  print()
