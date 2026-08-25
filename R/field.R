# field.R -- the multi-environment-trial / field-smoothing convenience path.
#
# The standard MET design is a row-column layout: a rectangular grid of plots
# indexed by `row` and `col`, one yield (or other trait) per plot, often within
# several environments. `gp_field_smooth()` is the one-call path from such a data
# frame to a smoothed field surface: it fits a gpfield GP over the row-column
# coordinates and predicts back onto a (possibly finer) plot grid, abstaining
# honestly when the layout cannot support the requested resolution. An optional
# plot helper draws the smoothed surface when ggplot2 is available.

#' Smooth a row-column field or trial layout
#'
#' One call from a multi-environment-trial (or any row-column field) data frame
#' to a smoothed surface. Fits a gpfield Gaussian process over the row and column
#' coordinates and predicts the latent trait surface back onto a plot grid -- the
#' observed grid by default, or a finer grid through `refine`. The honest
#' abstention of [gp_predict()] is inherited: refining only inserts points
#' strictly between the *observed* row-column locations, so if the observed
#' grid's own spacing is already coarser than the estimated correlation range
#' can resolve, [gp_field_smooth()] returns a [gpfield_abstention()] at every
#' `refine` level rather than an over-confident surface -- refining a grid the
#' range cannot support does not manufacture support.
#'
#' @param data A `data.frame` with the row, column and response columns.
#' @param response Character scalar naming the trait column to smooth.
#' @param row,col Character scalars naming the row and column coordinate columns
#'   (default `"row"` and `"col"`).
#' @param kernel Character covariance kernel passed to [gpfield_spec()]:
#'   `"matern"` (default) or `"se"`.
#' @param nu Matern smoothness (default `1.5`); ignored for `"se"`.
#' @param refine Positive integer grid-refinement factor. `1` (default) predicts
#'   on the observed plot grid; `2` predicts on a grid twice as fine on each
#'   axis, and so on. Refining never itself escapes an abstention: the
#'   observed grid's own spacing is checked against the estimated correlation
#'   range before any refinement is applied, so an unsupported observed grid
#'   stays unsupported at every `refine` level.
#' @param seed Optional integer seed recorded with the fit.
#'
#' @returns A `gpfield_smooth` S7 object carrying the `@fit` (a `gpfield_fit`)
#'   and the `@prediction` (a `gpfield_prediction`), or a [gpfield_abstention()]
#'   when the fit or the prediction cannot be supported.
#'
#' @seealso [gp_fit()], [gp_predict()], [gp_field_plot()]
#'
#' @examples
#' set.seed(1L)
#' field <- expand.grid(row = seq_len(10L), col = seq_len(10L))
#' field$yield <- 3 + 0.2 * field$row - 0.1 * field$col +
#'   stats::rnorm(nrow(field), 0, 0.3)
#' sm <- gp_field_smooth(field, response = "yield", seed = 1L)
#' sm@prediction
#'
#' @export
gp_field_smooth <- function(data, response, row = "row", col = "col",
                            kernel = "matern", nu = 1.5, refine = 1L,
                            seed = NULL) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data.frame.", call. = FALSE)
  }
  refine <- as.integer(refine)
  if (length(refine) != 1L || refine < 1L) {
    stop("`refine` must be a single positive integer.", call. = FALSE)
  }
  spec <- gpfield_spec(coords = c(row, col), response = response,
                       kernel = kernel, nu = nu)
  fit <- gp_fit(spec, data, seed = seed)
  if (is_gpfield_abstention(fit)) {
    return(fit)
  }

  # Refining only inserts points strictly between the *observed* row-column
  # locations; it cannot manufacture support the observed grid does not have.
  # Gate on the observed (refine = 1) grid's own spacing against the fit's
  # correlation range before refining, so a base grid the range cannot
  # resolve stays refused at every refine level rather than escaping the
  # guard once the refined grid's own point-to-point spacing shrinks below
  # the range.
  coord_cols <- .coord_columns(spec)
  base_xq <- as.matrix(data[, coord_cols, drop = FALSE])
  base_guard <- .point_support_guard(base_xq, fit, spacing_tol = 1)
  if (!is.null(base_guard)) {
    return(base_guard)
  }

  grid <- .refine_grid(data[[row]], data[[col]], refine, row, col)
  pred <- gp_predict(fit, grid, support = "point")
  if (is_gpfield_abstention(pred)) {
    return(pred)
  }
  gpfield_smooth_class(fit = fit, prediction = pred)
}

#' Draw a smoothed field surface (requires ggplot2)
#'
#' Renders the point-support prediction from [gp_field_smooth()] as a raster of
#' the smoothed trait over the row-column plane. The colour scale is the
#' colourblind-safe viridis option. Requires the optional `ggplot2` package and
#' the two coordinate columns to be present in the prediction locations.
#'
#' @param prediction A point-support `gpfield_prediction`, or the
#'   `gpfield_smooth` object returned by [gp_field_smooth()].
#' @param row,col Character scalars naming the coordinate columns in the
#'   prediction locations (default `"row"` and `"col"`).
#'
#' @returns A `ggplot` object.
#'
#' @seealso [gp_field_smooth()]
#'
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' set.seed(1L)
#' field <- expand.grid(row = seq_len(10L), col = seq_len(10L))
#' field$yield <- 3 + 0.2 * field$row - 0.1 * field$col +
#'   stats::rnorm(nrow(field), 0, 0.3)
#' sm <- gp_field_smooth(field, response = "yield", seed = 1L)
#' gp_field_plot(sm)
#'
#' @export
gp_field_plot <- function(prediction, row = "row", col = "col") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("`gp_field_plot()` needs the `ggplot2` package; install it first.",
         call. = FALSE)
  }
  if (S7::S7_inherits(prediction, gpfield_smooth_class)) {
    prediction <- prediction@prediction
  }
  if (!S7::S7_inherits(prediction, gpfield_prediction_class) ||
      prediction@support != "point") {
    stop("`prediction` must be a point-support `gpfield_prediction` or a ",
         "`gpfield_smooth`.", call. = FALSE)
  }
  df <- as.data.frame(prediction@locations)
  df$.smoothed <- prediction@mean
  ggplot2::ggplot(
    df,
    ggplot2::aes(x = .data[[row]], y = .data[[col]], fill = .data[[".smoothed"]])
  ) +
    ggplot2::geom_raster(interpolate = TRUE) +
    ggplot2::scale_fill_viridis_c(name = "smoothed") +
    ggplot2::coord_equal() +
    ggplot2::labs(x = row, y = col) +
    ggplot2::theme_minimal()
}

# --- internal ----------------------------------------------------------------

#' Build a (possibly refined) prediction grid over a row-column layout
#'
#' @param rows,cols The observed row and column coordinates.
#' @param refine Integer refinement factor.
#' @param row_name,col_name Names for the grid columns.
#'
#' @returns A data frame of grid coordinates.
#' @noRd
#' @keywords internal
.refine_grid <- function(rows, cols, refine, row_name, col_name) {
  r_seq <- .axis_seq(rows, refine)
  c_seq <- .axis_seq(cols, refine)
  g <- expand.grid(r_seq, c_seq)
  names(g) <- c(row_name, col_name)
  g
}

#' A refined sequence spanning an axis's observed range
#'
#' @param v The observed axis values.
#' @param refine Integer refinement factor.
#'
#' @returns A numeric sequence; the unique observed values when `refine == 1`.
#' @noRd
#' @keywords internal
.axis_seq <- function(v, refine) {
  u <- sort(unique(v))
  if (refine <= 1L || length(u) < 2L) {
    return(u)
  }
  seq(min(u), max(u), length.out = (length(u) - 1L) * refine + 1L)
}
