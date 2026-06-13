# kernels.R -- the covariance functions the Gaussian process is built on.
#
# A stationary, isotropic covariance over a Euclidean distance `d`, parameterised
# by a marginal variance `sigma2` and a length-scale `ell`. Two kernels are
# shipped: the infinitely-smooth squared-exponential, and the Matern family
# (nu in {1/2, 3/2, 5/2}) whose finite differentiability is the usual default for
# field data. Each kernel is a plain function of a distance matrix so the GP
# solver stays kernel-agnostic; the catalogue maps a name to the right closure.

# --- distance ----------------------------------------------------------------

#' Pairwise Euclidean distance between two coordinate sets
#'
#' Computes the `n`-by-`m` matrix of Euclidean distances between the rows of `a`
#' and the rows of `b`, in the (already-scaled) coordinate space the GP works in.
#' Uses the expanded-square identity so a large grid stays vectorised.
#'
#' @param a Numeric `n`-by-`p` matrix of coordinates.
#' @param b Numeric `m`-by-`p` matrix of coordinates.
#'
#' @returns A numeric `n`-by-`m` distance matrix.
#' @noRd
#' @keywords internal
.pairwise_distance <- function(a, b) {
  a <- as.matrix(a)
  b <- as.matrix(b)
  sq_a <- rowSums(a^2)
  sq_b <- rowSums(b^2)
  d2 <- outer(sq_a, sq_b, `+`) - 2 * a %*% t(b)
  sqrt(pmax(d2, 0))
}

# --- kernels -----------------------------------------------------------------

#' Squared-exponential covariance from a distance matrix
#'
#' The infinitely-differentiable radial-basis kernel
#' \eqn{\sigma^2 \exp(-d^2 / (2 \ell^2))}. Produces very smooth surfaces; a
#' common default away from sharp field boundaries.
#'
#' @param d Numeric distance matrix.
#' @param sigma2 Marginal variance (positive scalar).
#' @param ell Length-scale (positive scalar).
#'
#' @returns A covariance matrix of the shape of `d`.
#' @noRd
#' @keywords internal
.kernel_se <- function(d, sigma2, ell) {
  sigma2 * exp(-0.5 * (d / ell)^2)
}

#' Matern covariance from a distance matrix
#'
#' The Matern family for the half-integer smoothness parameters `nu` in
#' \eqn{\{1/2, 3/2, 5/2\}}, each having a closed elementary form. Lower `nu`
#' gives a rougher surface; `nu = 3/2` is a widely-used default for spatial field
#' data, trading the squared-exponential's over-smoothing for finite
#' differentiability.
#'
#' @param d Numeric distance matrix.
#' @param sigma2 Marginal variance (positive scalar).
#' @param ell Length-scale (positive scalar).
#' @param nu Smoothness; one of `0.5`, `1.5`, `2.5`.
#'
#' @returns A covariance matrix of the shape of `d`.
#' @noRd
#' @keywords internal
.kernel_matern <- function(d, sigma2, ell, nu = 1.5) {
  r <- d / ell
  cor <- if (isTRUE(all.equal(nu, 0.5))) {
    exp(-r)
  } else if (isTRUE(all.equal(nu, 1.5))) {
    s <- sqrt(3) * r
    (1 + s) * exp(-s)
  } else if (isTRUE(all.equal(nu, 2.5))) {
    s <- sqrt(5) * r
    (1 + s + s^2 / 3) * exp(-s)
  } else {
    stop("Matern `nu` must be one of 0.5, 1.5, 2.5.", call. = FALSE)
  }
  sigma2 * cor
}

# --- catalogue ---------------------------------------------------------------

#' Resolve a kernel name to a covariance closure
#'
#' Maps the user-facing kernel name (and, for `"matern"`, its smoothness) to a
#' `function(d, sigma2, ell)` the GP solver calls. Keeping the dispatch in one
#' place lets the rest of the package stay kernel-agnostic.
#'
#' @param kernel Character kernel name: `"se"` (squared-exponential) or
#'   `"matern"`.
#' @param nu Matern smoothness, ignored for `"se"`.
#'
#' @returns A `function(d, sigma2, ell)` returning a covariance matrix.
#' @noRd
#' @keywords internal
.kernel_fun <- function(kernel, nu = 1.5) {
  switch(
    kernel,
    se = function(d, sigma2, ell) .kernel_se(d, sigma2, ell),
    matern = function(d, sigma2, ell) .kernel_matern(d, sigma2, ell, nu = nu),
    stop("unknown kernel: ", kernel,
         " (expected \"se\" or \"matern\")", call. = FALSE))
}

#' Validate a kernel name
#'
#' @param kernel The candidate kernel name.
#'
#' @returns Invisibly `TRUE`; errors on an unknown name.
#' @noRd
#' @keywords internal
.check_kernel <- function(kernel) {
  valid <- c("se", "matern")
  if (length(kernel) != 1L || !is.character(kernel) ||
      !kernel %in% valid) {
    stop("`kernel` must be one of ", paste(valid, collapse = ", "), ".",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate a Matern smoothness value
#'
#' @param nu The candidate smoothness.
#'
#' @returns Invisibly `TRUE`; errors on an unsupported value.
#' @noRd
#' @keywords internal
.check_nu <- function(nu) {
  if (length(nu) != 1L || !is.numeric(nu) ||
      !any(vapply(c(0.5, 1.5, 2.5),
                  function(v) isTRUE(all.equal(nu, v)), logical(1L)))) {
    stop("`nu` must be one of 0.5, 1.5, 2.5.", call. = FALSE)
  }
  invisible(TRUE)
}
