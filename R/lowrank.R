# lowrank.R -- the low-rank (DTC / inducing-point) sparse-GP backend.
#
# The exact solver is cubic in the number of observations, which is prohibitive
# for fields in the tens of thousands of points. gpfield offers an optional
# low-rank backend, selected by `gpfield_spec(solver = "lowrank")`: the
# Deterministic Training Conditional (DTC) sparse GP (Quinonero-Candela &
# Rasmussen 2005, JMLR). A set of `m` inducing points summarises the field, the
# covariance is approximated by K ~ K_nm K_mm^-1 K_mn, and every quantity is
# computed through m-by-m Cholesky factorisations, so the fit is O(n m^2) rather
# than O(n^3). When the inducing set is the whole training set (m = n) the DTC
# posterior is exactly the exact GP -- the test suite checks this identity. The
# default backend stays exact; the low-rank path is an opt-in scaling lever and
# is isotropic (a single length-scale).

# --- inducing-point selection ------------------------------------------------

#' Deterministic farthest-point selection of inducing points
#'
#' Greedy farthest-point sampling over the (standardised) coordinates: seed with
#' the point nearest the centroid, then repeatedly add the point farthest from
#' the current set. Space-filling and deterministic (no RNG), so a low-rank fit
#' is reproducible and its inducing points are well spread over the field.
#'
#' @param xs Standardised coordinate matrix (`n`-by-`p`).
#' @param m Number of inducing points.
#'
#' @returns An integer vector of `m` row indices into `xs`.
#' @noRd
#' @keywords internal
.select_inducing <- function(xs, m) {
  n <- nrow(xs)
  if (m >= n) {
    return(seq_len(n))
  }
  cen <- colMeans(xs)
  seed <- which.min(rowSums(sweep(xs, 2L, cen, `-`)^2))
  idx <- integer(m)
  idx[[1L]] <- seed
  min_d <- rowSums(sweep(xs, 2L, xs[seed, ], `-`)^2)
  for (k in 2L:m) {
    nx <- which.max(min_d)
    idx[[k]] <- nx
    min_d <- pmin(min_d, rowSums(sweep(xs, 2L, xs[nx, ], `-`)^2))
  }
  idx
}

# --- DTC marginal likelihood -------------------------------------------------

#' Negative DTC marginal log-likelihood at given log-hyperparameters
#'
#' The projected-process (DTC / SoR) marginal likelihood of the sparse GP,
#' evaluated through the `m`-by-`m` system by the Woodbury identity so the cost is
#' O(n m^2). With `V = R_mm^{-T} K_mn` (so `V'V = Q_nn`) and
#' `B = noise * I_m + V V'`, the effective covariance `Q_nn + noise * I` has
#' log-determinant `log|B| + (n - m) log(noise)` and the quadratic form follows by
#' Woodbury.
#'
#' @param log_par Numeric `(log sigma2, log ell, log noise)`.
#' @param d_mm,d_nm Inducing-inducing and training-inducing distance matrices.
#' @param y Standardised response vector.
#' @param kfun A covariance closure from [.kernel_fun()].
#' @param nugget Diagonal jitter for conditioning `K_mm`.
#'
#' @returns A single numeric: the negative DTC marginal log-likelihood.
#' @noRd
#' @keywords internal
.gp_neg_loglik_dtc <- function(log_par, d_mm, d_nm, y, kfun, nugget) {
  sigma2 <- exp(log_par[[1L]])
  ell <- exp(log_par[[2L]])
  noise <- exp(log_par[[3L]])
  n <- length(y)
  m <- nrow(d_mm)
  k_mm <- kfun(d_mm, sigma2, ell)
  diag(k_mm) <- diag(k_mm) + nugget
  r_mm <- tryCatch(chol(k_mm), error = function(e) NULL)
  if (is.null(r_mm)) {
    return(1e10)
  }
  k_nm <- kfun(d_nm, sigma2, ell)
  v <- backsolve(r_mm, t(k_nm), transpose = TRUE)   # m-by-n, R_mm^{-T} K_mn
  b <- tcrossprod(v)                                # V V'
  diag(b) <- diag(b) + noise
  r_b <- tryCatch(chol(b), error = function(e) NULL)
  if (is.null(r_b)) {
    return(1e10)
  }
  vy <- v %*% y
  z <- backsolve(r_b, vy, transpose = TRUE)         # R_B^{-T} V y
  # Woodbury: (noise I + V'V)^{-1} = noise^{-1}[I - V'B^{-1}V], so the quadratic
  # form is (||y||^2 - ||R_B^{-T} V y||^2) / noise.
  quad <- (sum(y^2) - sum(z^2)) / noise
  logdet <- 2 * sum(log(diag(r_b))) + (n - m) * log(noise)
  ll <- -0.5 * quad - 0.5 * logdet - 0.5 * n * log(2 * pi)
  if (!is.finite(ll)) 1e10 else -ll
}

# --- DTC fit -----------------------------------------------------------------

#' Fit the DTC sparse GP hyperparameters and cache its factors
#'
#' Selects the inducing set, optimises `(sigma2, ell, noise)` on the DTC marginal
#' likelihood (multi-start Nelder-Mead as elsewhere), and caches the factors the
#' predictor needs: the inducing coordinates, `R_mm = chol(K_mm)`, `R_B = chol(B)`
#' and the mean weight `w = R_mm^{-1} B^{-1} V y` (so a posterior mean is
#' `K_*m w`). The predictive variance is `sigma2 - ||R_mm^{-T} K_m*||^2 +
#' noise ||R_B^{-T} R_mm^{-T} K_m*||^2`.
#'
#' @param xs Standardised training coordinate matrix (`n`-by-`p`).
#' @param y Standardised response vector.
#' @param kfun A covariance closure from [.kernel_fun()].
#' @param nugget Diagonal jitter for conditioning.
#' @param ind Integer inducing-point indices from [.select_inducing()].
#'
#' @returns A list of the fitted sparse GP, or `NULL` when degenerate.
#' @noRd
#' @keywords internal
.gp_fit_lowrank <- function(xs, y, kfun, nugget, ind) {
  z_ind <- xs[ind, , drop = FALSE]
  d_mm <- .pairwise_distance(z_ind, z_ind)
  d_nm <- .pairwise_distance(xs, z_ind)
  off <- d_nm[d_nm > 0]
  ell0 <- if (length(off)) stats::median(off) else 1
  if (!is.finite(ell0) || ell0 <= 0) {
    ell0 <- 1
  }
  fit_once <- function(par0, maxit) {
    stats::optim(par0, .gp_neg_loglik_dtc, d_mm = d_mm, d_nm = d_nm, y = y,
                 kfun = kfun, nugget = nugget, method = "Nelder-Mead",
                 control = list(maxit = maxit, reltol = 1e-8))
  }
  starts <- lapply(c(0.3, 1, 3),
                   function(s) c(log(1), log(ell0 * s), log(0.1)))
  best <- NULL
  for (par0 in starts) {
    cand <- tryCatch(fit_once(par0, 120L), error = function(e) NULL)
    if (!is.null(cand) && cand$value < 1e10 &&
        (is.null(best) || cand$value < best$value)) {
      best <- cand
    }
  }
  if (is.null(best)) {
    return(NULL)
  }
  opt <- tryCatch(fit_once(best$par, 500L), error = function(e) NULL)
  if (is.null(opt) || opt$value >= 1e10) {
    return(NULL)
  }
  opt2 <- tryCatch(fit_once(opt$par, 500L), error = function(e) NULL)
  if (!is.null(opt2) && opt2$value < opt$value) {
    opt <- opt2
  }

  sigma2 <- exp(opt$par[[1L]])
  ell <- exp(opt$par[[2L]])
  noise <- exp(opt$par[[3L]])
  k_mm <- kfun(d_mm, sigma2, ell)
  diag(k_mm) <- diag(k_mm) + nugget
  r_mm <- tryCatch(chol(k_mm), error = function(e) NULL)
  if (is.null(r_mm)) {
    return(NULL)
  }
  k_nm <- kfun(d_nm, sigma2, ell)
  v <- backsolve(r_mm, t(k_nm), transpose = TRUE)
  b <- tcrossprod(v)
  diag(b) <- diag(b) + noise
  r_b <- tryCatch(chol(b), error = function(e) NULL)
  if (is.null(r_b)) {
    return(NULL)
  }
  vy <- v %*% y
  binv_vy <- backsolve(r_b, backsolve(r_b, vy, transpose = TRUE))
  w_dtc <- backsolve(r_mm, binv_vy)
  list(sigma2 = sigma2, ell = ell, noise = noise,
       chol = r_b, alpha = as.numeric(w_dtc), loglik = -opt$value,
       lowrank = list(z_std = z_ind, l_mm = r_mm, m = nrow(z_ind)))
}

# --- DTC posterior -----------------------------------------------------------

#' DTC sparse-GP posterior at standardised query points
#'
#' The predictive mean and (optionally full) covariance under the fitted DTC
#' approximation, computed from the cached inducing factors. Mirrors the exact
#' [.gp_posterior()] / [.gp_posterior_diag()] so the point and block verbs branch
#' on the backend and are otherwise unchanged.
#'
#' @param fit A low-rank `gpfield_fit`.
#' @param xq_std Standardised query coordinate matrix.
#' @param kfun The fit's covariance closure.
#' @param full Logical: return the full posterior covariance (`TRUE`, for block
#'   support) or only its diagonal variance (`FALSE`, for point support).
#'
#' @returns A list with the standardised-scale posterior `mean` and either `cov`
#'   (when `full`) or `var`.
#' @noRd
#' @keywords internal
.gp_posterior_lowrank <- function(fit, xq_std, kfun, full = FALSE) {
  sigma2 <- fit@hyper$sigma2
  ell <- fit@hyper$ell
  noise <- fit@hyper$noise
  lr <- fit@lowrank
  k_qm <- kfun(.pairwise_distance(xq_std, lr$z_std), sigma2, ell)
  mean_s <- as.numeric(k_qm %*% fit@alpha)
  v1 <- backsolve(lr$l_mm, t(k_qm), transpose = TRUE)   # m-by-q
  v2 <- backsolve(fit@chol, v1, transpose = TRUE)       # R_B^{-T} v1
  if (full) {
    d_qq <- .pairwise_distance(xq_std, xq_std)
    cov_s <- kfun(d_qq, sigma2, ell) - crossprod(v1) + noise * crossprod(v2)
    return(list(mean = mean_s, cov = cov_s))
  }
  var_s <- pmax(sigma2 - colSums(v1^2) + noise * colSums(v2^2), 0)
  list(mean = mean_s, var = var_s)
}
