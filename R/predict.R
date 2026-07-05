# predict.R -- prediction, and the change-of-support that defines the package.
#
# A fitted GP predicts the latent surface at any query. gpfield's distinctive
# verb is `gp_predict(..., support = ...)`: predict at a support different from
# the one observed. The point support is the usual GP posterior at query points.
# The block support is the change-of-support integral -- a paddock-scale block
# average is the (Monte-Carlo) integral of the latent field over the block's
# footprint, and crucially its predictive variance is NOT the average of the
# point variances but the full quadratic form over the block's quadrature points,
# so spatial correlation within the block is propagated rather than dropped. This
# is the load-bearing distinction from naive cell-wise averaging.
#
# Before any block or fine-grid prediction is trusted, the support guard runs:
# if the estimated correlation range is shorter than the requested point spacing,
# or a block has no observation within one range of it, the verb abstains rather
# than draw a confident-but-unsupported value.

# --- support constructors ----------------------------------------------------

#' Describe a block (areal) support for change-of-support prediction
#'
#' Defines one or more blocks over which the latent field is to be integrated to
#' a block average -- the paddock-scale change-of-support target. Blocks are
#' axis-aligned rectangles (a row of lower / upper bounds per coordinate axis);
#' irregular or polygonal footprints are a planned extension, not supported here.
#' The prediction integrates the GP posterior over each block by deterministic
#' quadrature and propagates the full within-block covariance into the block
#' average's predictive variance.
#'
#' @param lower Numeric matrix or data frame, one row per block, columns aligned
#'   to the fit's spatial coordinate axes, holding each block's lower bounds.
#' @param upper As `lower`, holding the upper bounds.
#' @param ids Optional character block identifiers (default `"block1"`, ...).
#' @param n_quad Integer target number of quadrature points per block
#'   (default `200`), realised as the nearest tensor grid of axis midpoints.
#'
#' @returns A `gpfield_block_support` classed list consumed by [gp_predict()].
#'
#' @seealso [gp_predict()]
#'
#' @examples
#' blocks <- block_support(
#'   lower = rbind(c(0, 0), c(4, 4)),
#'   upper = rbind(c(4, 4), c(8, 8))
#' )
#' blocks
#'
#' @export
block_support <- function(lower, upper, ids = NULL, n_quad = 200L) {
  lower <- as.matrix(lower)
  upper <- as.matrix(upper)
  if (!identical(dim(lower), dim(upper))) {
    stop("`lower` and `upper` must have the same dimensions.", call. = FALSE)
  }
  if (any(upper <= lower)) {
    stop("every `upper` bound must exceed its `lower` bound.", call. = FALSE)
  }
  n_quad <- as.integer(n_quad)
  if (length(n_quad) != 1L || n_quad < 10L) {
    stop("`n_quad` must be a single integer of at least 10.", call. = FALSE)
  }
  nb <- nrow(lower)
  if (is.null(ids)) {
    ids <- paste0("block", seq_len(nb))
  }
  structure(
    list(lower = lower, upper = upper, ids = as.character(ids),
         n_quad = n_quad),
    class = "gpfield_block_support")
}

#' @export
print.gpfield_block_support <- function(x, ...) {
  cat("<gpfield_block_support>\n")
  cat(sprintf("  blocks:  %d\n", nrow(x$lower)))
  cat(sprintf("  n_quad:  %d per block\n", x$n_quad))
  invisible(x)
}

# --- core posterior ----------------------------------------------------------

#' GP posterior mean and full covariance at standardised query points
#'
#' The exact GP predictive distribution at the (already standardised) query
#' matrix: the posterior mean and the full posterior covariance. The full
#' covariance -- not just its diagonal -- is what change-of-support needs to
#' propagate within-block correlation, so it is returned in whole.
#'
#' @param fit A `gpfield_fit`.
#' @param xq_std Standardised query coordinate matrix.
#' @param kfun The fit's covariance closure.
#'
#' @returns A list with the standardised-scale posterior `mean` and `cov`.
#' @noRd
#' @keywords internal
.gp_posterior <- function(fit, xq_std, kfun) {
  if (isTRUE(fit@hyper$backend == "lowrank")) {
    return(.gp_posterior_lowrank(fit, xq_std, kfun, full = TRUE))
  }
  sigma2 <- fit@hyper$sigma2
  ell <- fit@hyper$ell
  d_qx <- .pairwise_distance(xq_std, fit@coords_std)
  k_star <- kfun(d_qx, sigma2, ell)
  mean_s <- as.numeric(k_star %*% fit@alpha)
  v <- backsolve(fit@chol, t(k_star), transpose = TRUE)
  d_qq <- .pairwise_distance(xq_std, xq_std)
  cov_s <- kfun(d_qq, sigma2, ell) - crossprod(v)
  list(mean = mean_s, cov = cov_s)
}

#' GP posterior mean and marginal variance (diagonal only) at query points
#'
#' The point-support path needs only the posterior mean and the per-query
#' variance, not the full cross-covariance. Forming only the diagonal keeps the
#' cost `O(m n)` in memory rather than the `O(m^2)` of a full covariance, so a
#' fine prediction grid scales. The stationary prior variance on the diagonal is
#' `sigma2`, so the marginal posterior variance is `sigma2` minus the squared
#' column norms of the whitened cross-covariance.
#'
#' @param fit A `gpfield_fit`.
#' @param xq_std Standardised query coordinate matrix.
#' @param kfun The fit's covariance closure.
#'
#' @returns A list with the standardised-scale posterior `mean` and per-query
#'   `var` (the diagonal of the latent posterior covariance).
#' @noRd
#' @keywords internal
.gp_posterior_diag <- function(fit, xq_std, kfun) {
  if (isTRUE(fit@hyper$backend == "lowrank")) {
    return(.gp_posterior_lowrank(fit, xq_std, kfun, full = FALSE))
  }
  sigma2 <- fit@hyper$sigma2
  ell <- fit@hyper$ell
  d_qx <- .pairwise_distance(xq_std, fit@coords_std)
  k_star <- kfun(d_qx, sigma2, ell)
  mean_s <- as.numeric(k_star %*% fit@alpha)
  v <- backsolve(fit@chol, t(k_star), transpose = TRUE)
  var_s <- pmax(sigma2 - colSums(v^2), 0)
  list(mean = mean_s, var = var_s)
}

# --- public verb -------------------------------------------------------------

#' Predict a gpfield surface, optionally at a different support
#'
#' The package's central verb. Given a fitted GP, predicts the latent field at
#' the requested locations and, critically, at the requested support. With
#' `support = "point"` (default) the result is the GP posterior mean and standard
#' deviation at each query point. With `support = "block"` the result is the
#' change-of-support prediction: each block's value is the integral of the latent
#' field over the block, and its predictive standard deviation is computed from
#' the full within-block posterior covariance so spatial correlation is
#' propagated, not averaged away.
#'
#' Honest abstention runs before any value is returned. If the estimated
#' correlation range is shorter than the requested point spacing -- so the query
#' grid asks the GP to interpolate between effectively independent observations --
#' the verb returns a [gpfield_abstention()] with reason `"range_too_short"`. If
#' a requested block has no training observation within one correlation range of
#' its footprint, the verb abstains with reason `"support_gap"`. An empty query
#' abstains with `"empty_query"`. The rule errs toward refusing a confident wrong
#' surface over emitting one.
#'
#' @param fit A `gpfield_fit` from [gp_fit()].
#' @param newdata For point support, a `data.frame` of query coordinates with the
#'   fit's coordinate (and time) columns. Ignored when `support = "block"`.
#' @param support Character: `"point"` (default) or `"block"`. Block support
#'   requires `blocks`.
#' @param blocks A `gpfield_block_support` from [block_support()], required when
#'   `support = "block"`.
#' @param min_support_ranges Numeric, block support only: a block must have at
#'   least one training observation within this many correlation ranges of its
#'   footprint, else the verb abstains. Default `1`. Ignored (with a warning) at
#'   point support.
#' @param spacing_tol Numeric, point support only: the point grid's spacing may
#'   be at most this multiple of the estimated range before the verb abstains
#'   with `"range_too_short"`. Default `1` (spacing may not exceed the range).
#'   Ignored (with a warning) at block support.
#' @param seed Retained for backward compatibility. Block quadrature is now
#'   deterministic (a tensor grid, not Monte-Carlo draws), so a block prediction
#'   is reproducible without a seed and never perturbs the caller's random
#'   stream; this argument no longer affects the result.
#'
#' @returns A `gpfield_prediction` S7 object on success, or a
#'   [gpfield_abstention()] when the support cannot bear the request.
#'
#' @seealso [gp_fit()], [block_support()], [gp_field_smooth()]
#'
#' @examples
#' set.seed(1L)
#' grid <- expand.grid(x = seq_len(10L), y = seq_len(10L))
#' grid$yield <- 2 + 0.25 * grid$x + 0.1 * grid$y +
#'   stats::rnorm(nrow(grid), 0, 0.2)
#' fit <- gp_fit(gpfield_spec(c("x", "y"), "yield"), grid, seed = 1L)
#'
#' # Point prediction on a fine grid.
#' q <- expand.grid(x = seq(1, 10, by = 1), y = seq(1, 10, by = 1))
#' pt <- gp_predict(fit, q)
#'
#' # Change of support: two paddock-scale block averages.
#' bl <- block_support(lower = rbind(c(1, 1), c(6, 6)),
#'                     upper = rbind(c(5, 5), c(10, 10)))
#' blk <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
#' blk
#'
#' @export
gp_predict <- function(fit, newdata = NULL, support = c("point", "block"),
                       blocks = NULL, min_support_ranges = 1,
                       spacing_tol = 1, seed = NULL) {
  support <- match.arg(support)
  .check_fit(fit)
  # Some arguments apply to only one support; warn rather than silently ignore a
  # value the caller took the trouble to set.
  if (support == "point" && !missing(min_support_ranges)) {
    warning("`min_support_ranges` applies to block support and is ignored ",
            "for point prediction.", call. = FALSE)
  }
  if (support == "block" && !missing(spacing_tol)) {
    warning("`spacing_tol` applies to point support and is ignored for block ",
            "prediction.", call. = FALSE)
  }
  kfun <- .kernel_fun(fit@spec@kernel, nu = fit@spec@nu)

  if (support == "point") {
    return(.gp_predict_point(fit, newdata, kfun, spacing_tol))
  }
  .gp_predict_block(fit, blocks, kfun, min_support_ranges)
}

# --- point support -----------------------------------------------------------

#' Point-support prediction (the GP posterior at query points)
#'
#' @inheritParams gp_predict
#' @param kfun The fit's covariance closure.
#'
#' @returns A `gpfield_prediction` or a `gpfield_abstention`.
#' @noRd
#' @keywords internal
.gp_predict_point <- function(fit, newdata, kfun, spacing_tol) {
  coord_cols <- .coord_columns(fit@spec)
  if (is.null(newdata) || !is.data.frame(newdata) || nrow(newdata) == 0L) {
    return(gpfield_abstention("empty_query",
                              "no query rows supplied for point prediction",
                              scope = "gp_predict"))
  }
  miss <- setdiff(coord_cols, names(newdata))
  if (length(miss)) {
    stop("`newdata` is missing column(s): ", paste(miss, collapse = ", "), ".",
         call. = FALSE)
  }
  xq <- as.matrix(newdata[, coord_cols, drop = FALSE])

  # Support guard: a grid spaced more coarsely than the correlation range asks
  # the GP to interpolate between effectively independent observations. Under an
  # anisotropic fit the guard is applied per axis (see .point_support_guard).
  guard <- .point_support_guard(xq, fit, spacing_tol)
  if (!is.null(guard)) {
    return(guard)
  }

  xq_std <- .apply_standardisation(xq, fit@centre, fit@spread)
  post <- .gp_posterior_diag(fit, xq_std, kfun)
  mean_raw <- post$mean * fit@y_sd + fit@y_mu
  var_s <- post$var + fit@hyper$noise
  sd_raw <- sqrt(pmax(var_s, 0)) * fit@y_sd

  gpfield_prediction_class(
    support = "point", locations = as.data.frame(newdata),
    mean = mean_raw, sd = sd_raw,
    n_support = rep(length(fit@y_raw), nrow(xq)), fit = fit)
}

# --- block support (change of support) ---------------------------------------

#' Block-support prediction (the change-of-support integral)
#'
#' For each block, draws `n_quad` Monte-Carlo quadrature points uniformly over
#' the block footprint, takes the GP posterior mean and FULL covariance at those
#' points, and forms the block average as the mean of the posterior means and its
#' variance as the double-sum quadratic form over the full covariance (plus the
#' averaged observation noise). Using the full covariance is what makes this a
#' change of support rather than a cell-wise average: positive within-block
#' correlation keeps the block-average variance well above `1/n_quad` of a point
#' variance.
#'
#' @inheritParams gp_predict
#' @param kfun The fit's covariance closure.
#'
#' @returns A `gpfield_prediction` or a `gpfield_abstention`.
#' @noRd
#' @keywords internal
.gp_predict_block <- function(fit, blocks, kfun, min_support_ranges) {
  if (!inherits(blocks, "gpfield_block_support")) {
    stop("`blocks` must be a `gpfield_block_support` (see `block_support()`) ",
         "when `support = \"block\"`.", call. = FALSE)
  }
  if (!is.na(fit@spec@time)) {
    stop("block support is defined over the spatial axes; a spatio-temporal ",
         "fit must be queried at point support.", call. = FALSE)
  }
  if (ncol(blocks$lower) != length(fit@spec@coords)) {
    stop("`blocks` must have one column per spatial coordinate axis (",
         length(fit@spec@coords), ").", call. = FALSE)
  }

  range_raw <- fit@hyper$range_raw
  # The supporting reach is per-axis under an anisotropic fit (each spatial axis
  # carries its own correlation range), a single scalar otherwise.
  reach <- if (isTRUE(fit@hyper$anisotropic)) {
    min_support_ranges * as.numeric(fit@hyper$range_axis)
  } else {
    min_support_ranges * range_raw
  }
  nb <- nrow(blocks$lower)
  means <- numeric(nb)
  sds <- numeric(nb)
  n_near <- numeric(nb)

  for (b in seq_len(nb)) {
    lo <- blocks$lower[b, ]
    hi <- blocks$upper[b, ]

    # Support guard: at least one training point within `min_support_ranges`
    # correlation ranges of this block's footprint, else there is nothing to
    # anchor the block average on.
    n_near[b] <- .count_near_block(fit@coords_raw, lo, hi, reach)
    if (n_near[b] < 1L) {
      return(gpfield_abstention(
        "support_gap",
        sprintf(paste0("block %s has no training observation within %.4g ",
                       "(%.2g range) of its footprint"),
                blocks$ids[[b]], min_support_ranges * range_raw,
                min_support_ranges),
        scope = "gp_predict",
        diagnostics = list(block = blocks$ids[[b]],
                           range = range_raw,
                           reach = min_support_ranges * range_raw)))
    }

    quad <- .block_quadrature(lo, hi, blocks$n_quad)
    quad_std <- .apply_standardisation(quad, fit@centre, fit@spread)
    post <- .gp_posterior(fit, quad_std, kfun)

    nq <- nrow(quad)
    w <- rep(1 / nq, nq)
    block_mean_s <- sum(w * post$mean)
    # Full quadratic form propagates within-block correlation; noise contributes
    # only its averaged share (independent across quadrature points).
    block_var_s <- drop(crossprod(w, post$cov %*% w)) +
      fit@hyper$noise / nq
    means[b] <- block_mean_s * fit@y_sd + fit@y_mu
    sds[b] <- sqrt(pmax(block_var_s, 0)) * fit@y_sd
  }

  loc <- data.frame(block = blocks$ids,
                    blocks$lower, blocks$upper,
                    check.names = FALSE)
  names(loc) <- c("block",
                  paste0(fit@spec@coords, "_lower"),
                  paste0(fit@spec@coords, "_upper"))

  gpfield_prediction_class(
    support = "block", locations = loc, mean = means, sd = sds,
    n_support = n_near, fit = fit)
}

# --- internal helpers --------------------------------------------------------

#' Deterministic tensor-grid quadrature points over a rectangular block
#'
#' A tensor product of equal-cell midpoints on each axis -- the midpoint rule.
#' Deterministic (no RNG, so a block prediction is reproducible without a seed
#' and never perturbs the caller's random stream) and, for the smooth latent
#' fields a GP represents, converges far faster than uniform Monte-Carlo
#' sampling. The per-axis resolution is chosen so the point count approximates
#' the requested `n_quad`.
#'
#' @param lo,hi Numeric lower / upper bounds per axis.
#' @param n_quad Integer target number of points.
#'
#' @returns A roughly-`n_quad`-by-`p` matrix of quadrature points.
#' @noRd
#' @keywords internal
.block_quadrature <- function(lo, hi, n_quad) {
  p <- length(lo)
  per_axis <- max(2L, round(n_quad^(1 / p)))
  mids <- lapply(seq_len(p), function(j) {
    lo[[j]] + (seq_len(per_axis) - 0.5) / per_axis * (hi[[j]] - lo[[j]])
  })
  as.matrix(expand.grid(mids))
}

#' Count training points within a reach of a block's footprint
#'
#' A training point counts as supporting the block when its per-axis distance to
#' the block (zero inside the block, the gap to the nearest edge outside) is
#' within `reach` on every axis -- a cheap, axis-wise nearness test.
#'
#' @param coords Raw training coordinates (spatial axes; a time column, if any,
#'   sits in the trailing column and is ignored here).
#' @param lo,hi The block bounds.
#' @param reach The supported reach in raw units: a single scalar (isotropic) or
#'   one value per axis (anisotropic); recycled per axis by the comparison.
#'
#' @returns The integer count of supporting points.
#' @noRd
#' @keywords internal
.count_near_block <- function(coords, lo, hi, reach) {
  coords <- as.matrix(coords)
  p <- length(lo)
  sp <- coords[, seq_len(p), drop = FALSE]
  below <- sweep(sp, 2L, lo, `<`)
  above <- sweep(sp, 2L, hi, `>`)
  # Per-axis gap to the block: `lo[j] - sp[,j]` below the block, `sp[,j] - hi[j]`
  # above it (both positive there), zero inside. `sweep(..., 2L, ...)` applies
  # the bound per column; a bare `lo - sp` would recycle the bound down the rows.
  gap_lo <- sweep(sp, 2L, lo, function(a, b) b - a)
  gap_hi <- sweep(sp, 2L, hi, `-`)
  gap <- matrix(0, nrow = nrow(sp), ncol = p)
  gap[below] <- gap_lo[below]
  gap[above] <- gap_hi[above]
  within <- apply(gap, 1L, function(g) all(g <= reach))
  sum(within)
}

#' Median nearest-neighbour spacing of a query grid (raw units)
#'
#' A robust scalar summary of how finely a query grid is laid out, used by the
#' isotropic point-support guard. Returns the median nearest-neighbour distance
#' over the (spatial) query coordinates. Computed in row blocks so peak memory is
#' `O(block x m)` rather than the `O(m^2)` of a full distance matrix, keeping a
#' fine query grid affordable.
#'
#' @param xq Raw query coordinate matrix.
#'
#' @returns A single numeric spacing, or `0` when there is one query point.
#' @noRd
#' @keywords internal
.query_spacing <- function(xq) {
  xq <- as.matrix(xq)
  m <- nrow(xq)
  if (m < 2L) {
    return(0)
  }
  block <- 1024L
  mins <- numeric(m)
  for (start in seq.int(1L, m, by = block)) {
    idx <- start:min(start + block - 1L, m)
    d <- .pairwise_distance(xq[idx, , drop = FALSE], xq)
    for (k in seq_along(idx)) {
      d[k, idx[[k]]] <- Inf                 # a point's distance to itself
    }
    mins[idx] <- apply(d, 1L, min)
  }
  stats::median(mins)
}

#' Per-axis minimum positive spacing of a query set (raw units)
#'
#' @param xq Raw query coordinate matrix.
#'
#' @returns A numeric vector, one per axis, of the smallest positive gap between
#'   sorted unique values on that axis (`Inf` when an axis is constant).
#' @noRd
#' @keywords internal
.axis_spacing <- function(xq) {
  xq <- as.matrix(xq)
  vapply(seq_len(ncol(xq)), function(j) {
    u <- sort(unique(xq[, j]))
    if (length(u) < 2L) Inf else min(diff(u))
  }, numeric(1L))
}

#' Point-support abstention guard
#'
#' Decides whether a point query is too coarse for the fit's correlation range.
#' Under an isotropic fit the median nearest-neighbour spacing is compared to the
#' single estimated range; under an anisotropic fit each axis's own spacing is
#' compared to that axis's range, so a grid resolved finely along a long-range
#' axis is not condemned by a short-range one.
#'
#' @param xq Raw query coordinate matrix (coordinate axes in the fit's order).
#' @param fit A `gpfield_fit`.
#' @param spacing_tol The multiple of the range the spacing may reach.
#'
#' @returns A [gpfield_abstention()] with reason `"range_too_short"`, or `NULL`
#'   when the query is supported.
#' @noRd
#' @keywords internal
.point_support_guard <- function(xq, fit, spacing_tol) {
  if (isTRUE(fit@hyper$anisotropic)) {
    sp_axis <- .axis_spacing(xq)
    rng_axis <- as.numeric(fit@hyper$range_axis)
    viol <- is.finite(sp_axis) & sp_axis > spacing_tol * rng_axis
    if (any(viol)) {
      j <- which(viol)[[1L]]
      return(gpfield_abstention(
        "range_too_short",
        sprintf(paste0("axis %s spacing %.4g exceeds %.2g x its estimated ",
                       "range %.4g; the field cannot be resolved this finely ",
                       "on that axis"),
                names(fit@hyper$range_axis)[[j]], sp_axis[[j]], spacing_tol,
                rng_axis[[j]]),
        scope = "gp_predict",
        diagnostics = list(axis = names(fit@hyper$range_axis)[[j]],
                           spacing = sp_axis[[j]], range = rng_axis[[j]],
                           spacing_tol = spacing_tol)))
    }
    return(NULL)
  }
  spacing <- .query_spacing(xq)
  range_raw <- fit@hyper$range_raw
  if (is.finite(spacing) && spacing > spacing_tol * range_raw) {
    return(gpfield_abstention(
      "range_too_short",
      sprintf(paste0("query spacing %.4g exceeds %.2g x the estimated range ",
                     "%.4g; the field cannot be resolved this finely"),
              spacing, spacing_tol, range_raw),
      scope = "gp_predict",
      diagnostics = list(spacing = spacing, range = range_raw,
                         spacing_tol = spacing_tol)))
  }
  NULL
}

#' Check that an object is a gpfield_fit
#'
#' @param fit The candidate object.
#'
#' @returns Invisibly `TRUE`; errors otherwise.
#' @noRd
#' @keywords internal
.check_fit <- function(fit) {
  if (!S7::S7_inherits(fit, gpfield_fit_class)) {
    stop("`fit` must be a `gpfield_fit` (see `gp_fit()`).", call. = FALSE)
  }
  invisible(TRUE)
}
