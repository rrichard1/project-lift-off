# Visual system: neutral base, one slate accent, sans-serif type.
# Fit-read colours encode role, not good/bad; no traffic lights.

liftoff_palette <- list(
  bg = "#F7F6F3",
  surface = "#FFFFFF",
  ink = "#1E2226",
  muted = "#5F656D",
  rule = "#E3E1DC",
  accent = "#2D5A74",
  accent_soft = "#E4EDF2",
  sand = "#C9A66B",
  sand_soft = "#F4ECDD"
)

#' bslib theme for the app
#' @noRd
liftoff_theme <- function() {
  p <- liftoff_palette
  bslib::bs_theme(
    version = 5,
    bg = p$bg,
    fg = p$ink,
    primary = p$accent,
    secondary = p$muted,
    base_font = bslib::font_collection("Inter", "system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif"),
    heading_font = bslib::font_collection("Inter", "system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif"),
    font_scale = 1,
    `border-radius` = "10px",
    `border-color` = p$rule,
    `navbar-bg` = p$surface
  )
}
