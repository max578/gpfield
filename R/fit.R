# fit.R -- the exact Gaussian-process regression and its hyperparameter fit.
#
# A single, self-contained exact GP over standardised coordinates. The marginal
# variance, length-scale and observation-noise variance are estimated by
# maximising the marginal log-likelihood with stats::optim on the log-parameters
# (so the optimiser is unconstrained and the parameters stay positive). The
# linear algebra is a Cholesky solve -- the same precedent the apsimR emulator
# follows -- with no heavy external GP dependency. A low-rank / Nystrom
# approximation for n in the thousands is a documented future path (see the
# package vignette); the exact solver is the v0.1 backend.

# --- standardisation ---------------------------------------------------------

#' Standardise a coordinate matrix to zero mean and unit spread per axis
#'
#' Each coordinate axis is centred and scaled independently so the isotropic
#' kernel sees comparable spreads on every axis (a degenerate zero-spread axis is
#' given unit spread to avoid a divide-by-zero). The centre and spread are
#' returned so a prediction grid can be put on the same footing.
#'
#' @param x Numeric `n`-by-`p` coordinate matrix.
#'
#' @returns A list with the standardised matrix `xs`, and the `centre` and
#'   `spread` vectors.
#' @noRd
#' @keywords internal
.standardise_coords <- function(x) {
  x <- as.matrix(x)
  centre <- colMeans(x)
  spread <- apply(x, 2L, stats::sd)
  spread[spread == 0 | !is.finite(spread)] <- 1
  xs <- sweep(sweep(x, 2L, centre, `-`), 2L, spread, `/`)
  list(xs = xs, centre = centre, spread = spread)
}

#' Apply a stored standardisation to a new coordinate matrix
#'
#' @param x Numeric `m`-by-`p` coordinate matrix.
#' @param centre,spread The per-axis centre and spread from
#'   `.standardise_coords()`.
#'
#' @returns The standardised matrix.
#' @noRd
#' @keywords internal
.apply_standardisation <- function(x, centre, spread) {
  sweep(sweep(as.matrix(x), 2L, centre, `-`), 2L, spread, `/`)
}

# --- marginal likelihood -----------------------------------------------------

#' Negative marginal log-likelihood of the GP at given log-hyperparameters
#'
#' Evaluates \eqn{-\log p(y \mid X, \theta)} for the zero-mean GP with covariance
#' `k(d; sigma2, ell) + noise * I`. Parameterised on the log scale so the
#' optimiser is unconstrained. Returns a large finite penalty (not `Inf`) when
#' the covariance is not positive-definite, so the optimiser can step away from a
#' bad region rather than stall.
#'
#' @param log_par Numeric length-3 vector `(log sigma2, log ell, log noise)`.
#' @param d Standardised-coordinate distance matrix of the training points.
#' @param y Standardised response vector.
#' @param kfun A covariance closure from `.kernel_fun()`.
#' @param nugget Diagonal jitter for conditioning.
#'
#' @returns A single numeric: the negative marginal log-likelihood.
#' @noRd
#' @keywords internal
.gp_neg_loglik <- function(log_par, d, y, kfun, nugget) {
  sigma2 <- exp(log_par[[1L]])
  ell <- exp(log_par[[2L]])
  noise <- exp(log_par[[3L]])
  n <- length(y)
  k <- kfun(d, sigma2, ell) + diag(noise + nugget, n)
  chol_k <- tryCatch(chol(k), error = function(e) NULL)
  if (is.null(chol_k)) {
    return(1e10)
  }
  alpha <- backsolve(chol_k, backsolve(chol_k, y, transpose = TRUE))
  log_det <- 2 * sum(log(diag(chol_k)))
  quad <- drop(crossprod(y, alpha))
  ll <- -0.5 * quad - 0.5 * log_det - 0.5 * n * log(2 * pi)
  if (!is.finite(ll)) 1e10 else -ll
}

#' Fit the GP hyperparameters by marginal-likelihood maximisation
#'
#' Optimises `(sigma2, ell, noise)` on the log scale with `stats::optim`
#' (Nelder-Mead, restarted once from the optimum to settle), starting from
#' data-driven guesses: marginal variance from the response variance,
#' length-scale from the median pairwise distance (the standard heuristic) and a
#' small noise fraction. Returns the estimates, the Cholesky factor and weight
#' vector at the optimum, and the achieved marginal log-likelihood.
#'
#' @param d Standardised-coordinate distance matrix.
#' @param y Standardised response vector.
#' @param kfun A covariance closure from `.kernel_fun()`.
#' @param nugget Diagonal jitter for conditioning.
#'
#' @returns A list of the fitted GP, or `NULL` when the fit is degenerate.
#' @noRd
#' @keywords internal
.gp_fit_hyper <- function(d, y, kfun, nugget) {
  off_diag <- d[upper.tri(d)]
  ell0 <- stats::median(off_diag)
  if (!is.finite(ell0) || ell0 <= 0) {
    ell0 <- 1
  }
  start <- c(log(1), log(ell0), log(0.1))
  fit_once <- function(par0) {
    stats::optim(par0, .gp_neg_loglik, d = d, y = y, kfun = kfun,
                 nugget = nugget, method = "Nelder-Mead",
                 control = list(maxit = 500L, reltol = 1e-8))
  }
  opt <- tryCatch(fit_once(start), error = function(e) NULL)
  if (is.null(opt) || opt$value >= 1e10) {
    return(NULL)
  }
  # One restart from the found optimum settles Nelder-Mead's simplex.
  opt2 <- tryCatch(fit_once(opt$par), error = function(e) NULL)
  if (!is.null(opt2) && opt2$value < opt$value) {
    opt <- opt2
  }

  sigma2 <- exp(opt$par[[1L]])
  ell <- exp(opt$par[[2L]])
  noise <- exp(opt$par[[3L]])
  n <- length(y)
  k <- kfun(d, sigma2, ell) + diag(noise + nugget, n)
  chol_k <- tryCatch(chol(k), error = function(e) NULL)
  if (is.null(chol_k)) {
    return(NULL)
  }
  alpha <- backsolve(chol_k, backsolve(chol_k, y, transpose = TRUE))
  list(sigma2 = sigma2, ell = ell, noise = noise,
       chol = chol_k, alpha = alpha, loglik = -opt$value)
}

# --- anisotropic (ARD) marginal likelihood -----------------------------------

#' Negative marginal log-likelihood of an anisotropic GP at log-hyperparameters
#'
#' The automatic-relevance-determination counterpart of [.gp_neg_loglik()]: the
#' length-scale is a vector, one per coordinate axis. Rather than change the
#' isotropic kernel, each (already SD-standardised) axis is divided by its own
#' length-scale and the isotropic kernel is evaluated on the resulting distance,
#' which is exactly an anisotropic kernel on the original coordinates. The
#' distance therefore depends on the length-scales and is recomputed inside the
#' objective.
#'
#' @param log_par Numeric `(log sigma2, log ell_1, ..., log ell_p, log noise)`.
#' @param xs Standardised training coordinate matrix (`n`-by-`p`).
#' @param y Standardised response vector.
#' @param kfun A covariance closure from [.kernel_fun()].
#' @param nugget Diagonal jitter for conditioning.
#'
#' @returns A single numeric: the negative marginal log-likelihood.
#' @noRd
#' @keywords internal
.gp_neg_loglik_ard <- function(log_par, xs, y, kfun, nugget) {
  p <- ncol(xs)
  sigma2 <- exp(log_par[[1L]])
  ell <- exp(log_par[2L:(p + 1L)])
  noise <- exp(log_par[[p + 2L]])
  n <- length(y)
  xss <- sweep(xs, 2L, ell, `/`)
  d <- .pairwise_distance(xss, xss)
  k <- kfun(d, sigma2, 1) + diag(noise + nugget, n)
  chol_k <- tryCatch(chol(k), error = function(e) NULL)
  if (is.null(chol_k)) {
    return(1e10)
  }
  alpha <- backsolve(chol_k, backsolve(chol_k, y, transpose = TRUE))
  log_det <- 2 * sum(log(diag(chol_k)))
  quad <- drop(crossprod(y, alpha))
  ll <- -0.5 * quad - 0.5 * log_det - 0.5 * n * log(2 * pi)
  if (!is.finite(ll)) 1e10 else -ll
}

#' Fit anisotropic (per-axis) GP hyperparameters by marginal likelihood
#'
#' The ARD analogue of [.gp_fit_hyper()]: optimises `(sigma2, ell_1..ell_p,
#' noise)` on the log scale, starting each axis length-scale from that axis's
#' median pairwise distance. Returns the estimates, the per-axis-rescaled
#' coordinates the Cholesky was computed on (so the caller can store the scaling
#' in the standardisation and keep the stored kernel isotropic), and the achieved
#' marginal log-likelihood.
#'
#' @param xs Standardised training coordinate matrix (`n`-by-`p`, `p >= 2`).
#' @param y Standardised response vector.
#' @param kfun A covariance closure from [.kernel_fun()].
#' @param nugget Diagonal jitter for conditioning.
#'
#' @returns A list of the fitted anisotropic GP, or `NULL` when degenerate.
#' @noRd
#' @keywords internal
.gp_fit_hyper_ard <- function(xs, y, kfun, nugget) {
  p <- ncol(xs)
  ell0 <- vapply(seq_len(p), function(j) {
    dj <- as.numeric(stats::dist(xs[, j, drop = FALSE]))
    dj <- dj[dj > 0]
    m <- if (length(dj)) stats::median(dj) else 1
    if (!is.finite(m) || m <= 0) 1 else m
  }, numeric(1L))
  start <- c(log(1), log(ell0), log(0.1))
  fit_once <- function(par0) {
    stats::optim(par0, .gp_neg_loglik_ard, xs = xs, y = y, kfun = kfun,
                 nugget = nugget, method = "Nelder-Mead",
                 control = list(maxit = 800L, reltol = 1e-8))
  }
  opt <- tryCatch(fit_once(start), error = function(e) NULL)
  if (is.null(opt) || opt$value >= 1e10) {
    return(NULL)
  }
  # Restart from the optimum settles the simplex in the higher-dimensional space.
  opt2 <- tryCatch(fit_once(opt$par), error = function(e) NULL)
  if (!is.null(opt2) && opt2$value < opt$value) {
    opt <- opt2
  }

  sigma2 <- exp(opt$par[[1L]])
  ell <- exp(opt$par[2L:(p + 1L)])
  noise <- exp(opt$par[[p + 2L]])
  n <- length(y)
  xss <- sweep(xs, 2L, ell, `/`)
  d <- .pairwise_distance(xss, xss)
  k <- kfun(d, sigma2, 1) + diag(noise + nugget, n)
  chol_k <- tryCatch(chol(k), error = function(e) NULL)
  if (is.null(chol_k)) {
    return(NULL)
  }
  alpha <- backsolve(chol_k, backsolve(chol_k, y, transpose = TRUE))
  list(sigma2 = sigma2, ell = ell, noise = noise,
       chol = chol_k, alpha = alpha, loglik = -opt$value, coords_std = xss)
}

# --- public verb -------------------------------------------------------------

#' Fit a gpfield Gaussian process to field or trial data
#'
#' Solves an exact Gaussian-process regression of the response on the spatial
#' (and optionally temporal) coordinates named by the `gpfield_spec`. The
#' coordinates and response are standardised, the chosen kernel's hyperparameters
#' are estimated by maximising the marginal likelihood, and the solved Cholesky
#' system is stored so that [gp_predict()] can predict cheaply -- at the observed
#' support or another.
#'
#' The estimated length-scale, returned in raw coordinate units as the
#' correlation `range`, is the quantity the change-of-support and abstention
#' machinery reasons about: a prediction finer than the range is unsupported, and
#' the fit makes that range explicit rather than implicit.
#'
#' @param spec A `gpfield_spec` from [gpfield_spec()].
#' @param data A `data.frame` carrying the coordinate columns, the optional time
#'   column, and the response column named by `spec`.
#' @param seed Optional integer RNG seed recorded with the fit for provenance.
#'   The exact fit is deterministic, so the seed is metadata rather than a source
#'   of randomness.
#'
#' @returns A `gpfield_fit` S7 object, or a [gpfield_abstention()] with reason
#'   `"degenerate_fit"` when the marginal-likelihood optimisation does not yield
#'   a usable covariance.
#'
#' @seealso [gpfield_spec()], [gp_predict()], [gp_field_smooth()]
#'
#' @examples
#' set.seed(1L)
#' grid <- expand.grid(x = seq_len(8L), y = seq_len(8L))
#' grid$yield <- 2 + 0.3 * grid$x + sin(grid$y / 2) + stats::rnorm(nrow(grid), 0, 0.2)
#' spec <- gpfield_spec(coords = c("x", "y"), response = "yield")
#' fit <- gp_fit(spec, grid, seed = 1L)
#' fit
#'
#' @export
gp_fit <- function(spec, data, seed = NULL) {
  .check_spec(spec)
  .check_fit_data(spec, data)
  coord_cols <- .coord_columns(spec)
  x_raw <- as.matrix(data[, coord_cols, drop = FALSE])
  y_raw <- as.numeric(data[[spec@response]])
  ok <- stats::complete.cases(x_raw) & is.finite(y_raw)
  x_raw <- x_raw[ok, , drop = FALSE]
  y_raw <- y_raw[ok]
  if (length(y_raw) < 3L) {
    return(gpfield_abstention(
      "degenerate_fit",
      sprintf("only %d complete observations; need at least 3 to fit",
              length(y_raw)),
      scope = "gp_fit"))
  }

  std <- .standardise_coords(x_raw)
  y_mu <- mean(y_raw)
  y_sd <- stats::sd(y_raw)
  if (!is.finite(y_sd) || y_sd == 0) {
    y_sd <- 1
  }
  ys <- (y_raw - y_mu) / y_sd
  kfun <- .kernel_fun(spec@kernel, nu = spec@nu)
  npar <- ncol(std$xs)
  use_ard <- isTRUE(spec@anisotropic) && npar >= 2L

  if (use_ard) {
    fit <- .gp_fit_hyper_ard(std$xs, ys, kfun, spec@nugget)
  } else {
    d <- .pairwise_distance(std$xs, std$xs)
    fit <- .gp_fit_hyper(d, ys, kfun, spec@nugget)
  }
  if (is.null(fit)) {
    return(gpfield_abstention(
      "degenerate_fit",
      "marginal-likelihood optimisation did not yield a usable covariance",
      scope = "gp_fit"))
  }

  if (use_ard) {
    # Absorb the per-axis standardised length-scales into the per-axis spread, so
    # the stored coordinates carry the anisotropy and the kernel stays isotropic
    # (length-scale 1) over them. Every downstream verb -- point and block
    # prediction, the support guard -- then reads `centre` / `spread` / `ell`
    # exactly as in the isotropic case; nothing in predict.R changes. The
    # raw-units correlation range along an axis is `spread_j * ell_j`.
    effective_spread <- std$spread * fit$ell
    coords_std <- fit$coords_std
    spread_store <- effective_spread
    range_axis <- stats::setNames(effective_spread, .coord_columns(spec))
    hyper <- list(sigma2 = fit$sigma2, ell = 1, noise = fit$noise,
                  range_raw = mean(effective_spread), anisotropic = TRUE,
                  range_axis = range_axis, ell_standardised = fit$ell)
  } else {
    # Translate the single standardised length-scale to a raw-units correlation
    # range (reported on the mean spread); it is the figure the support logic
    # uses.
    coords_std <- std$xs
    spread_store <- std$spread
    hyper <- list(sigma2 = fit$sigma2, ell = fit$ell, noise = fit$noise,
                  range_raw = fit$ell * mean(std$spread), anisotropic = FALSE)
  }

  gpfield_fit_class(
    spec = spec, coords_raw = x_raw, coords_std = coords_std,
    centre = std$centre, spread = spread_store,
    y_raw = y_raw, y_mu = y_mu, y_sd = y_sd,
    hyper = hyper, chol = fit$chol, alpha = fit$alpha, loglik = fit$loglik,
    seed = if (is.null(seed)) NA_integer_ else as.integer(seed),
    emitter_version = as.character(utils::packageVersion("gpfield")))
}

# --- internal validation -----------------------------------------------------

#' The full coordinate column set (spatial plus optional time)
#'
#' @param spec A `gpfield_spec`.
#'
#' @returns Character vector of column names the GP works over.
#' @noRd
#' @keywords internal
.coord_columns <- function(spec) {
  if (is.na(spec@time)) spec@coords else c(spec@coords, spec@time)
}

#' Check that an object is a gpfield_spec
#'
#' @param spec The candidate object.
#'
#' @returns Invisibly `TRUE`; errors otherwise.
#' @noRd
#' @keywords internal
.check_spec <- function(spec) {
  if (!S7::S7_inherits(spec, gpfield_spec_class)) {
    stop("`spec` must be a `gpfield_spec` (see `gpfield_spec()`).",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Check that the data frame carries the columns the spec names
#'
#' @param spec A `gpfield_spec`.
#' @param data The candidate data frame.
#'
#' @returns Invisibly `TRUE`; errors on a missing column or non-numeric coord.
#' @noRd
#' @keywords internal
.check_fit_data <- function(spec, data) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data.frame.", call. = FALSE)
  }
  need <- c(.coord_columns(spec), spec@response)
  miss <- setdiff(need, names(data))
  if (length(miss)) {
    stop("`data` is missing column(s): ", paste(miss, collapse = ", "), ".",
         call. = FALSE)
  }
  for (cc in .coord_columns(spec)) {
    if (!is.numeric(data[[cc]])) {
      stop("coordinate column `", cc, "` must be numeric.", call. = FALSE)
    }
  }
  invisible(TRUE)
}
