# test-oracle-posterior.R -- an INDEPENDENT oracle for the core GP posterior.
#
# Every other test checks the package against itself (metamorphic, round-trip,
# ordering). This one recomputes the posterior from scratch with explicit matrix
# algebra that shares no code path with predict.R, so it grounds the mathematics
# against a reference the package did not author -- the Independent Oracle
# Principle applied to the package's central claim.

test_that("point posterior mean and sd match a hand-rolled GP to machine precision", {
  set.seed(7L)
  X <- cbind(x = c(1, 2, 4, 7, 9), y = c(1, 3, 2, 6, 8))
  yv <- c(0.5, 1.2, 0.8, 2.1, 3.0)
  dat <- as.data.frame(cbind(X, z = yv))
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", kernel = "se"), dat, seed = 7L)

  xq <- data.frame(x = c(3, 6), y = c(3, 5))
  pk <- gp_predict(fit, xq, spacing_tol = 100)

  # Independent recomputation using only the fitted hyperparameters. Standardise,
  # solve the exact GP with base solve(), destandardise -- no gpfield internals.
  Xs <- scale(X, center = fit@centre, scale = fit@spread)
  ys <- (yv - fit@y_mu) / fit@y_sd
  s2 <- fit@hyper$sigma2
  ell <- fit@hyper$ell
  nz <- fit@hyper$noise
  ng <- fit@spec@nugget
  kse <- function(a, b) {
    d2 <- outer(rowSums(a^2), rowSums(b^2), `+`) - 2 * a %*% t(b)
    s2 * exp(-0.5 * pmax(d2, 0) / ell^2)
  }
  kmat <- kse(Xs, Xs) + diag(nz + ng, nrow(Xs))
  qs <- scale(as.matrix(xq), center = fit@centre, scale = fit@spread)
  ks <- kse(qs, Xs)
  mean_oracle <- as.numeric(ks %*% solve(kmat, ys)) * fit@y_sd + fit@y_mu
  var_oracle <- diag(kse(qs, qs) - ks %*% solve(kmat, t(ks))) + nz
  sd_oracle <- sqrt(var_oracle) * fit@y_sd

  expect_equal(pk@mean, mean_oracle, tolerance = 1e-8)
  expect_equal(pk@sd, sd_oracle, tolerance = 1e-8)
})

test_that("the diagonal-only point path agrees with the full posterior covariance", {
  # E1 replaced the full m-by-m covariance with a diagonal-only computation for
  # point support; the two must give the same marginal variances.
  fit <- .fitted_field()
  q <- expand.grid(x = seq_len(6L), y = seq_len(6L))
  kfun <- gpfield:::.kernel_fun(fit@spec@kernel, nu = fit@spec@nu)
  xq_std <- gpfield:::.apply_standardisation(as.matrix(q), fit@centre, fit@spread)
  full <- gpfield:::.gp_posterior(fit, xq_std, kfun)
  diag_only <- gpfield:::.gp_posterior_diag(fit, xq_std, kfun)
  expect_equal(diag_only$mean, full$mean)
  expect_equal(diag_only$var, pmax(diag(full$cov), 0))
})
