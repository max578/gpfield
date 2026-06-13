# classes.R -- the S7 object hierarchy.
#
# Three typed objects carry a gpfield analysis end to end, mirroring the
# orchestra's spec / fit convention (proxymix's gmm / gmm_fit, PESTO's manifest):
#   gpfield_spec       : the model configuration -- kernel, smoothness, the
#                        coordinate columns, and whether a time axis is in play.
#   gpfield_fit        : a fitted GP -- the spec, the standardised training data,
#                        the estimated hyperparameters, the Cholesky factor and
#                        the marginal-likelihood diagnostics.
#   gpfield_prediction : a prediction at a requested support -- the queried
#                        locations / blocks, the predictive mean and standard
#                        deviation, and the support map that produced them.
# S7 universally (Imports: S7), no facade. The object-system choice aligns with
# masque, PESTO, kernR and proxymix so a consumer reads gpfield output the same
# way it reads any other member's.

# --- gpfield_spec ------------------------------------------------------------

#' A gpfield model specification
#'
#' The configuration of a spatial (or spatio-temporal) Gaussian process before it
#' is fitted: which covariance kernel to use, the smoothness for the Matern
#' family, the names of the spatial coordinate columns, an optional time-axis
#' column, and the jitter added to the kernel diagonal for numerical
#' conditioning. Construct one with [gpfield_spec()] and fit it with [gp_fit()].
#'
#' @usage NULL
#'
#' @returns An S7 object of class `gpfield_spec`.
#'
#' @seealso [gpfield_spec()], [gp_fit()]
#' @export
gpfield_spec_class <- S7::new_class(
  "gpfield_spec_class",
  package = "gpfield",
  properties = list(
    kernel       = S7::new_property(S7::class_character, default = "matern"),
    nu           = S7::new_property(S7::class_numeric, default = 1.5),
    coords       = S7::class_character,
    time         = S7::new_property(S7::class_character,
                                    default = NA_character_),
    response     = S7::class_character,
    nugget       = S7::new_property(S7::class_numeric, default = 1e-6)
  ),
  validator = function(self) {
    errs <- character(0)
    if (length(self@coords) < 1L) {
      errs <- c(errs, "`coords` must name at least one coordinate column")
    }
    if (length(self@response) != 1L || !nzchar(self@response)) {
      errs <- c(errs, "`response` must be a single non-empty column name")
    }
    if (self@nugget <= 0) {
      errs <- c(errs, "`nugget` must be positive")
    }
    if (length(errs) == 0L) NULL else paste(errs, collapse = "; ")
  }
)

# --- gpfield_fit -------------------------------------------------------------

#' A fitted gpfield Gaussian process
#'
#' The result of [gp_fit()]: the originating `gpfield_spec`, the standardised
#' training coordinates and response, the estimated hyperparameters (marginal
#' variance, length-scale and noise variance), the Cholesky factor and weight
#' vector of the solved system, and the marginal log-likelihood at the optimum.
#' Predict from it -- at the observed support or another -- with [gp_predict()].
#'
#' @usage NULL
#'
#' @returns An S7 object of class `gpfield_fit`.
#'
#' @seealso [gp_fit()], [gp_predict()]
#' @export
gpfield_fit_class <- S7::new_class(
  "gpfield_fit_class",
  package = "gpfield",
  properties = list(
    spec         = gpfield_spec_class,
    coords_raw   = S7::class_any,
    coords_std   = S7::class_any,
    centre       = S7::class_numeric,
    spread       = S7::class_numeric,
    y_raw        = S7::class_numeric,
    y_mu         = S7::class_numeric,
    y_sd         = S7::class_numeric,
    hyper        = S7::class_list,
    chol         = S7::class_any,
    alpha        = S7::class_numeric,
    loglik       = S7::class_numeric,
    seed         = S7::new_property(S7::class_integer, default = NA_integer_),
    emitter_version = S7::new_property(S7::class_character,
                                       default = NA_character_)
  )
)

# --- gpfield_prediction ------------------------------------------------------

#' A gpfield prediction at a requested support
#'
#' The result of a successful [gp_predict()]: the queried locations or block
#' definitions, the predictive mean and standard deviation, the inferential
#' support (`"point"` or `"block"`), and the number of observations that informed
#' each query (carried so a consumer can see how well-supported each value is).
#' Unsuccessful predictions return a [gpfield_abstention()] instead.
#'
#' @usage NULL
#'
#' @returns An S7 object of class `gpfield_prediction`.
#'
#' @seealso [gp_predict()]
#' @export
gpfield_prediction_class <- S7::new_class(
  "gpfield_prediction_class",
  package = "gpfield",
  properties = list(
    support      = S7::class_character,
    locations    = S7::class_any,
    mean         = S7::class_numeric,
    sd           = S7::class_numeric,
    n_support    = S7::class_numeric,
    fit          = gpfield_fit_class
  )
)

# --- constructors and print methods ------------------------------------------

#' Specify a gpfield Gaussian-process model
#'
#' Builds the configuration consumed by [gp_fit()]. A specification fixes the
#' covariance kernel and (for `"matern"`) its smoothness, names the spatial
#' coordinate columns in the data frame the fit will read, optionally names a
#' time column for a spatio-temporal model, and sets the diagonal jitter used to
#' condition the kernel. Nothing is fitted here; the specification is a small,
#' inspectable object so the model is declared before any data are touched.
#'
#' The default kernel is the `"matern"` family at `nu = 1.5`, the usual choice
#' for field data: it is once-differentiable rather than the squared-exponential's
#' infinite smoothness, which avoids the over-smoothing that the squared
#' exponential imposes across real agronomic gradients.
#'
#' @param coords Character vector naming the spatial coordinate columns (one for
#'   a transect, two for a field, three or more if the caller has projected
#'   additional spatial axes). When a `time` column is also given, it is appended
#'   to the coordinate set as an extra, separately-scaled axis.
#' @param response Character scalar naming the response column to smooth.
#' @param kernel Character covariance kernel: `"matern"` (default) or `"se"`
#'   (squared-exponential).
#' @param nu Matern smoothness; one of `0.5`, `1.5` (default) or `2.5`. Ignored
#'   for the squared-exponential kernel.
#' @param time Optional character scalar naming a time column for a
#'   spatio-temporal fit, or `NA` (default) for a purely spatial model.
#' @param nugget Positive numeric jitter added to the kernel diagonal for
#'   numerical conditioning. Distinct from the estimated observation-noise
#'   variance, which is a fitted hyperparameter.
#'
#' @returns A `gpfield_spec` S7 object.
#'
#' @seealso [gp_fit()], [gp_predict()]
#'
#' @examples
#' spec <- gpfield_spec(coords = c("x", "y"), response = "yield")
#' spec
#'
#' # A spatio-temporal specification with the squared-exponential kernel.
#' st <- gpfield_spec(
#'   coords = c("x", "y"), response = "ndvi", kernel = "se", time = "doy"
#' )
#' st
#'
#' @export
gpfield_spec <- function(coords, response, kernel = "matern", nu = 1.5,
                         time = NA_character_, nugget = 1e-6) {
  .check_kernel(kernel)
  if (kernel == "matern") {
    .check_nu(nu)
  }
  gpfield_spec_class(
    kernel = kernel, nu = as.numeric(nu),
    coords = as.character(coords), response = as.character(response),
    time = as.character(time), nugget = as.numeric(nugget))
}

# S7 objects dispatch through S7's own method table, not S3 name-matching, so
# the print methods for the S7 classes are registered with `S7::method()` (wired
# at load by `S7::methods_register()`), exactly as the orchestra precedent does.

S7::method(print, gpfield_spec_class) <- function(x, ...) {
  cat("<gpfield_spec>\n")
  k <- if (x@kernel == "matern") {
    sprintf("matern (nu = %s)", format(x@nu))
  } else {
    "squared-exponential"
  }
  cat(sprintf("  kernel:   %s\n", k))
  cat(sprintf("  coords:   %s\n", paste(x@coords, collapse = ", ")))
  if (!is.na(x@time)) {
    cat(sprintf("  time:     %s\n", x@time))
  }
  cat(sprintf("  response: %s\n", x@response))
  invisible(x)
}

S7::method(print, gpfield_fit_class) <- function(x, ...) {
  cat("<gpfield_fit>\n")
  cat(sprintf("  kernel:      %s\n", x@spec@kernel))
  cat(sprintf("  n training:  %d\n", length(x@y_raw)))
  cat(sprintf("  length-scale (standardised): %.4g\n", x@hyper$ell))
  cat(sprintf("  marginal var / noise var:    %.4g / %.4g\n",
              x@hyper$sigma2, x@hyper$noise))
  cat(sprintf("  range (raw units):           %.4g\n", x@hyper$range_raw))
  cat(sprintf("  log marginal likelihood:     %.4g\n", x@loglik))
  invisible(x)
}

S7::method(print, gpfield_prediction_class) <- function(x, ...) {
  cat("<gpfield_prediction>\n")
  cat(sprintf("  support:   %s\n", x@support))
  cat(sprintf("  locations: %d\n", length(x@mean)))
  cat(sprintf("  mean range: [%.4g, %.4g]\n",
              min(x@mean), max(x@mean)))
  cat(sprintf("  sd range:   [%.4g, %.4g]\n",
              min(x@sd), max(x@sd)))
  invisible(x)
}
