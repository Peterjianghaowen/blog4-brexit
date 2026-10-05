# blog4-brexit

Analysis code and data for the blog post **"Did Brexit Leave the UK Behind? Output, Investment, and Trade Against the G7"** (AEDS 6400, Blog Post 4).

## Question

Did the UK fall behind comparable economies after the 2016 Brexit referendum? The post compares the UK with the average of the other six G7 countries on real GDP per capita, investment, and trade openness.

## Repository structure

```
code/
  01_get_data.R      downloads World Bank data and builds the cleaned panel
  02_figures.R       applies transformations, saves all figures and the gap table
data/
  raw/wdi_raw.csv              raw download from the World Bank API
  processed/g7_panel.csv       country-year panel with indexed GDP per capita
  processed/uk_vs_peers.csv    UK vs. peer average, levels
results/
  fig1_gdp_per_capita.png
  fig2_investment.png
  fig3_trade.png
  fig_interactive.html         interactive chart (open in a browser)
  uk_vs_peers_gap.csv          UK, peer average, and gap by measure and year
```

## How to replicate

1. Install packages: `install.packages(c("WDI", "dplyr", "tidyr", "readr", "ggplot2", "plotly", "htmlwidgets"))`
2. Open `blog4-brexit.Rproj` in RStudio so that relative paths resolve from the repo root.
3. Run the scripts in order: `source("code/01_get_data.R")`, then `source("code/02_figures.R")`.

No API key is needed. The World Bank revises its data, so numbers may change slightly if the scripts are re-run later; `data/raw/wdi_raw.csv` preserves the download used in the post (5 October 2026).

## Methods notes

- Countries: United Kingdom, Canada, France, Germany, Italy, Japan, United States, 2000 onward.
- Real GDP per capita (constant 2015 US$) is indexed to 2016 = 100, the referendum year.
- Investment (gross fixed capital formation, % of GDP) and trade (exports + imports, % of GDP) are expressed as percentage-point changes since 2016, because levels differ widely across countries.
- The comparison group is the unweighted mean of the six non-UK countries.
- Only years in which all seven countries report a measure are kept, so the peer average never changes composition.
- The comparison is descriptive. It does not separate Brexit from the pandemic or the 2022 energy shock.

## Data source

World Bank, World Development Indicators, accessed through the `WDI` R package. Indicators: `NY.GDP.PCAP.KD`, `NE.GDI.FTOT.ZS`, `NE.TRD.GNFS.ZS`.
