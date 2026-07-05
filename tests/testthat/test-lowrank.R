# test-lowrank.R -- the low-rank (DTC / inducing-point) sparse-GP backend.

# An independent Matern-3/2 kernel for the dense oracle (textbook form, no
# package code path).
.matern32_dense <- function(a, b, s2, ell) {
  d2 <- outer(rowSums(a^2), rowSums(b^2), `+`) - 2 * a %*% t(b)
  s <- sqrt(3) * sqrt(pmax(d2, 0)) / ell
  s2 * (1 + s) * exp(-s)
}

test_that("the low-rank solver produces a fitted GP tagged lowrank", {
  set.seed(11L)
  g <- expand.grid(x = seq(0, 15, by = 0.75), y = seq(0, 15, by = 0.75))
  g$z <- sin(0.5 * g$x) + cos(0.4 * g$y) + stats::rnorm(nrow(g), 0, 0.1)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", solver = "lowrank",
                             n_inducing = 50L), g, seed = 1L)
  expect_true(S7::S7_inherits(fit, gpfield_fit_class))
  expect_identical(fit@hyper$backend, "lowrank")
  expect_equal(fit@hyper$n_inducing, 50L)
  expect_gt(fit@hyper$range_raw, 0)
  expect_true(is.finite(fit@loglik))
  expect_match(paste(capture.output(print(fit)), collapse = "\n"), "low-rank")
})

test_that("the low-rank posterior matches a direct dense DTC computation", {
  # Independent oracle: recompute the DTC mean and variance from the textbook
  # dense formulas with base solve(), using the fitted hyperparameters, and
  # compare to the package's Woodbury/Cholesky implementation.
  set.seed(12L)
  g <- expand.grid(x = seq(0, 12, by = 0.6), y = seq(0, 12, by = 0.6))
  g$z <- sin(0.5 * g$x) + cos(0.4 * g$y) + stats::rnorm(nrow(g), 0, 0.1)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", solver = "lowrank",
                             n_inducing = 40L), g, seed = 1L)
  qd <- data.frame(x = c(2, 5, 8), y = c(3, 6, 9))
  pk <- gp_predict(fit, qd, spacing_tol = 100)

  s2 <- fit@hyper$sigma2
  ell <- fit@hyper$ell
  nz <- fit@hyper$noise
  ng <- fit@spec@nugget
  xs <- gpfield:::.apply_standardisation(fit@coords_raw, fit@centre, fit@spread)
  z <- fit@lowrank$z_std
  ys <- (fit@y_raw - fit@y_mu) / fit@y_sd
  k_mm <- .matern32_dense(z, z, s2, ell) + diag(ng, nrow(z))
  k_nm <- .matern32_dense(xs, z, s2, ell)
  sig <- k_mm + (1 / nz) * crossprod(k_nm)
  qs <- gpfield:::.apply_standardisation(as.matrix(qd), fit@centre, fit@spread)
  k_sm <- .matern32_dense(qs, z, s2, ell)
  mean_o <- as.numeric((1 / nz) * k_sm %*% solve(sig, crossprod(k_nm, ys))) *
    fit@y_sd + fit@y_mu
  var_o <- s2 - rowSums((k_sm %*% solve(k_mm)) * k_sm) +
    rowSums((k_sm %*% solve(sig)) * k_sm) + nz
  sd_o <- sqrt(pmax(var_o, 0)) * fit@y_sd

  expect_equal(pk@mean, mean_o, tolerance = 1e-6)
  expect_equal(pk@sd, sd_o, tolerance = 1e-6)
})

test_that("the low-rank solver falls back to exact when n <= n_inducing", {
  set.seed(13L)
  g <- expand.grid(x = seq_len(8L), y = seq_len(8L))
  g$z <- 2 + 0.3 * g$x + sin(g$y / 2) + stats::rnorm(64, 0, 0.15)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", solver = "lowrank",
                             n_inducing = 200L), g, seed = 1L)
  expect_identical(fit@hyper$backend, "exact")
  expect_null(fit@lowrank)
})

test_that("the low-rank fit approximates the exact GP on a smooth field", {
  set.seed(14L)
  g <- expand.grid(x = seq(0, 14, by = 0.7), y = seq(0, 14, by = 0.7))
  g$z <- sin(0.45 * g$x) + cos(0.4 * g$y) + stats::rnorm(nrow(g), 0, 0.1)
  qd <- data.frame(x = runif(100, 1, 13), y = runif(100, 1, 13))
  qd$truth <- sin(0.45 * qd$x) + cos(0.4 * qd$y)
  ex <- gp_fit(gpfield_spec(c("x", "y"), "z"), g, seed = 1L)
  lr <- gp_fit(gpfield_spec(c("x", "y"), "z", solver = "lowrank",
                            n_inducing = 60L), g, seed = 1L)
  p_ex <- gp_predict(ex, qd, spacing_tol = 100)
  p_lr <- gp_predict(lr, qd, spacing_tol = 100)
  rmse <- function(a, b) sqrt(mean((a - b)^2))
  expect_lt(rmse(p_lr@mean, p_ex@mean), 0.1)   # close to the exact posterior
  expect_lt(rmse(p_lr@mean, qd$truth), 0.1)     # and to the truth
})

test_that("change-of-support and abstention work under a low-rank fit", {
  set.seed(15L)
  # A short-range oscillatory field, so a block far outside the footprint is
  # genuinely unsupported (a linear-trend field earns a huge range and would be
  # supported arbitrarily far out).
  g <- expand.grid(x = seq(0, 12, by = 0.6), y = seq(0, 12, by = 0.6))
  g$z <- sin(0.6 * g$x) + cos(0.6 * g$y) + stats::rnorm(nrow(g), 0, 0.15)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", solver = "lowrank",
                             n_inducing = 40L), g, seed = 1L)
  blk <- gp_predict(fit, support = "block",
                    blocks = block_support(rbind(c(2, 2)), rbind(c(8, 8))))
  expect_true(S7::S7_inherits(blk, gpfield_prediction_class))
  expect_true(is.finite(blk@mean) && is.finite(blk@sd))
  far <- gp_predict(fit, support = "block",
                    blocks = block_support(rbind(c(100, 100)),
                                           rbind(c(110, 110))))
  expect_true(is_gpfield_abstention(far))
  expect_identical(far$reason, "support_gap")
})

test_that("the low-rank fit is deterministic and its inducing set is stable", {
  set.seed(16L)
  g <- expand.grid(x = seq(0, 10, by = 0.5), y = seq(0, 10, by = 0.5))
  g$z <- sin(0.5 * g$x) + 0.2 * g$y + stats::rnorm(nrow(g), 0, 0.1)
  a <- gp_fit(gpfield_spec(c("x", "y"), "z", solver = "lowrank",
                           n_inducing = 30L), g, seed = 1L)
  b <- gp_fit(gpfield_spec(c("x", "y"), "z", solver = "lowrank",
                           n_inducing = 30L), g, seed = 1L)
  expect_equal(a@hyper$range_raw, b@hyper$range_raw)
  expect_identical(a@lowrank$z_std, b@lowrank$z_std)
})
