# 02_figures.R
# Builds the three static figures (PNG) and one interactive chart (HTML)
# from data/processed/g7_panel.csv. Run from the repo root.

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(plotly)
library(htmlwidgets)

base_year <- 2016
col_uk    <- "#C8102E"
col_peer  <- "#1F3A5F"

panel <- read_csv("data/processed/g7_panel.csv", show_col_types = FALSE)

# ---- Transformations ---------------------------------------------------
# GDP per capita is already indexed (2016 = 100).
# Investment and trade shares become percentage-point changes since 2016,
# so countries with very different levels (e.g. Germany vs US trade) are comparable.
long <- panel |>
  group_by(country) |>
  mutate(
    invest_chg = invest_gdp - invest_gdp[year == base_year],
    trade_chg  = trade_gdp  - trade_gdp[year == base_year]
  ) |>
  ungroup() |>
  select(country, iso2c, year, gdp_pc_idx, invest_chg, trade_chg) |>
  pivot_longer(c(gdp_pc_idx, invest_chg, trade_chg),
               names_to = "measure", values_to = "value") |>
  # keep only years where all seven countries report, so the peer average
  # never changes composition
  group_by(measure, year) |>
  filter(!any(is.na(value))) |>
  ungroup()

uk <- long |>
  filter(iso2c == "GB") |>
  select(measure, year, uk = value)

peer <- long |>
  filter(iso2c != "GB") |>
  group_by(measure, year) |>
  summarise(peer = mean(value), .groups = "drop")

gap <- left_join(uk, peer, by = c("measure", "year")) |>
  mutate(gap = uk - peer)

write_csv(gap, "results/uk_vs_peers_gap.csv")

# ---- Shared plot elements ----------------------------------------------
events <- tibble(
  year  = c(2016, 2021),
  label = c("Referendum", "Leaves single market")
)

src <- paste(
  "Source: World Bank, World Development Indicators.",
  "Peers = unweighted mean of Canada, France, Germany, Italy, Japan, US."
)

theme_blog <- theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position  = "top",
    plot.title       = element_text(face = "bold"),
    plot.caption     = element_text(colour = "grey40", hjust = 0)
  )

colour_scale <- scale_colour_manual(
  values = c("United Kingdom" = col_uk, "G7 average (ex-UK)" = col_peer),
  name = NULL
)

event_layers <- list(
  geom_vline(data = events, aes(xintercept = year),
             linetype = "dotted", colour = "grey50"),
  geom_text(data = events, aes(x = year, y = Inf, label = label),
            inherit.aes = FALSE, vjust = 1.5, hjust = -0.05,
            size = 3.3, colour = "grey30")
)

# ---- Figure 1: real GDP per capita, with individual peers in grey ------
d1 <- filter(gap, measure == "gdp_pc_idx")

fig1 <- ggplot() +
  event_layers +
  geom_line(data = filter(long, measure == "gdp_pc_idx", iso2c != "GB"),
            aes(year, value, group = country),
            colour = "grey78", linewidth = 0.5) +
  geom_line(data = d1, aes(year, peer, colour = "G7 average (ex-UK)"),
            linewidth = 1.1, linetype = "dashed") +
  geom_line(data = d1, aes(year, uk, colour = "United Kingdom"),
            linewidth = 1.3) +
  colour_scale +
  labs(
    title    = "Real GDP per capita: UK vs. G7 peers",
    subtitle = "Index, 2016 = 100. Grey lines are the six individual peers.",
    x = NULL, y = "Index (2016 = 100)", caption = src
  ) +
  theme_blog

ggsave("results/fig1_gdp_per_capita.png", fig1, width = 9, height = 5.5, dpi = 300)

# ---- Figures 2 and 3: UK vs peer average with shaded gap ---------------
plot_gap <- function(m, title, subtitle, ylab) {
  d <- filter(gap, measure == m)
  ggplot(d, aes(year)) +
    geom_hline(yintercept = 0, colour = "grey60") +
    event_layers +
    geom_ribbon(aes(ymin = pmin(uk, peer), ymax = pmax(uk, peer)),
                fill = col_uk, alpha = 0.12) +
    geom_line(aes(y = peer, colour = "G7 average (ex-UK)"),
              linewidth = 1.1, linetype = "dashed") +
    geom_line(aes(y = uk, colour = "United Kingdom"), linewidth = 1.3) +
    colour_scale +
    labs(title = title, subtitle = subtitle, x = NULL, y = ylab, caption = src) +
    theme_blog
}

fig2 <- plot_gap(
  "invest_chg",
  "Investment: UK vs. G7 peers",
  "Gross fixed capital formation as % of GDP, change since 2016",
  "Percentage points vs. 2016"
)
ggsave("results/fig2_investment.png", fig2, width = 9, height = 5.5, dpi = 300)

fig3 <- plot_gap(
  "trade_chg",
  "Trade openness: UK vs. G7 peers",
  "Exports + imports as % of GDP, change since 2016",
  "Percentage points vs. 2016"
)
ggsave("results/fig3_trade.png", fig3, width = 9, height = 5.5, dpi = 300)

# ---- Interactive chart: switch between the three measures --------------
measures <- c(
  gdp_pc_idx = "Real GDP per capita (2016 = 100)",
  invest_chg = "Investment share of GDP (pp change since 2016)",
  trade_chg  = "Trade share of GDP (pp change since 2016)"
)
button_labels <- c("GDP per capita", "Investment", "Trade")

p <- plot_ly()
for (i in seq_along(measures)) {
  d <- filter(gap, measure == names(measures)[i])
  p <- p |>
    add_trace(
      x = d$year, y = d$peer, type = "scatter", mode = "lines",
      name = "G7 average (ex-UK)", visible = (i == 1),
      line = list(color = col_peer, dash = "dash", width = 2),
      hovertemplate = "G7 avg: %{y:.1f}<extra></extra>"
    ) |>
    add_trace(
      x = d$year, y = d$uk, type = "scatter", mode = "lines+markers",
      name = "United Kingdom", visible = (i == 1),
      line = list(color = col_uk, width = 3),
      marker = list(color = col_uk, size = 5),
      fill = "tonexty", fillcolor = "rgba(200,16,46,0.12)",
      text = sprintf("%+.1f", d$gap),
      hovertemplate = "UK: %{y:.1f}<br>Gap vs peers: %{text}<extra></extra>"
    )
}

buttons <- lapply(seq_along(measures), function(i) {
  vis <- rep(FALSE, 2 * length(measures))
  vis[c(2 * i - 1, 2 * i)] <- TRUE
  list(
    method = "update",
    label  = button_labels[i],
    args   = list(list(visible = vis),
                  list("yaxis.title.text" = measures[[i]]))
  )
})

vlines <- lapply(events$year, function(x) {
  list(type = "line", x0 = x, x1 = x, yref = "paper", y0 = 0, y1 = 1,
       line = list(color = "grey", dash = "dot", width = 1))
})

annots <- lapply(seq_len(nrow(events)), function(i) {
  list(x = events$year[i], y = c(1, 0.93)[i], yref = "paper", text = events$label[i],
       showarrow = FALSE, xanchor = "right", yanchor = "top",
       font = list(size = 11, color = "grey"))
})

p <- p |>
  layout(
    title     = list(text = "UK vs. G7 peers since the Brexit referendum", x = 0.02, y = 0.97),
    hovermode = "x unified",
    margin    = list(t = 110),
    xaxis     = list(title = "", rangeslider = list(visible = TRUE)),
    yaxis     = list(title = measures[[1]]),
    shapes    = vlines,
    annotations = annots,
    legend    = list(orientation = "h", x = 1, xanchor = "right", y = 1.03, yanchor = "bottom"),
    updatemenus = list(list(
      type = "buttons", direction = "right",
      x = 0, y = 1.03, xanchor = "left",
      yanchor = "bottom", buttons = buttons
    ))
  )

saveWidget(p, file.path(getwd(), "results", "fig_interactive.html"),
           selfcontained = TRUE)

# ---- Numbers to quote in the post --------------------------------------
gap |>
  filter(year %in% c(2016, 2019, max(year))) |>
  mutate(across(c(uk, peer, gap), \(x) round(x, 1))) |>
  print(n = Inf)

print(p)
