# Tests for the anisotropic (ARD) fit: one length-scale per coordinate axis.

test_that("the spec carries an anisotropic flag, default FALSE", {
  expect_false(gpfield_spec(c("x", "y"), "z")@anisotropic)
  sp <- gpfield_spec(c("x", "y"), "z", anisotropic = TRUE)
  expect_true(sp@anisotropic)
  expect_match(capture.output(print(sp))[2], "anisotropic")
})

test_that("an anisotropic fit estimates one range per axis and stays isotropic in stored space", {
  set.seed(1L)
  g <- expand.grid(x = seq_len(12L), y = seq_len(12L))
  # Different scales per axis: wiggly in x, near-flat in y.
  g$z <- sin(g$x) + 0.05 * g$y + stats::rnorm(nrow(g), 0, 0.1)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", anisotropic = TRUE), g, seed = 1L)

  expect_true(S7::S7_inherits(fit, gpfield_fit_class))
  expect_true(fit@hyper$anisotropic)
  expect_equal(fit@hyper$ell, 1)                       # absorbed into the spread
  expect_length(fit@hyper$range_axis, 2L)
  expect_identical(names(fit@hyper$range_axis), c("x", "y"))
  # The near-flat axis earns the longer correlation range.
  expect_gt(fit@hyper$range_axis[["y"]], fit@hyper$range_axis[["x"]])
  expect_match(capture.output(print(fit))[2], "anisotropic")
})

test_that("anisotropy improves held-out accuracy on an anisotropic field", {
  set.seed(2L)
  f <- function(x, y) sin(0.9 * x) + 0.04 * y
  g <- expand.grid(x = seq(1, 14, by = 0.6), y = seq(1, 14, by = 0.6))
  g$z <- f(g$x, g$y)
  qd <- data.frame(x = runif(120, 2, 13), y = runif(120, 2, 13))
  qd$truth <- f(qd$x, qd$y)
  rmse <- function(a, b) sqrt(mean((a - b)^2))

  iso <- gp_fit(gpfield_spec(c("x", "y"), "z"), g, seed = 1L)
  ani <- gp_fit(gpfield_spec(c("x", "y"), "z", anisotropic = TRUE), g, seed = 1L)
  p_iso <- gp_predict(iso, qd, spacing_tol = 100)
  p_ani <- gp_predict(ani, qd, spacing_tol = 100)
  expect_true(S7::S7_inherits(p_ani, gpfield_prediction_class))
  expect_lt(rmse(p_ani@mean, qd$truth), rmse(p_iso@mean, qd$truth))
})

test_that("anisotropic = TRUE with a single axis falls back to isotropic", {
  set.seed(3L)
  g <- data.frame(x = seq_len(20L))
  g$z <- 2 + 0.3 * g$x + stats::rnorm(20L, 0, 0.1)
  fit <- gp_fit(gpfield_spec("x", "z", anisotropic = TRUE), g, seed = 1L)
  expect_false(fit@hyper$anisotropic)                  # one axis -> isotropic
  expect_true(is.numeric(fit@hyper$range_raw))
})

test_that("change-of-support still works under an anisotropic fit", {
  set.seed(4L)
  g <- expand.grid(x = seq_len(10L), y = seq_len(10L))
  g$z <- 0.4 * g$x + 0.05 * g$y + stats::rnorm(nrow(g), 0, 0.15)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", anisotropic = TRUE), g, seed = 1L)
  bl <- block_support(lower = rbind(c(1, 1)), upper = rbind(c(5, 5)))
  blk <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
  expect_true(S7::S7_inherits(blk, gpfield_prediction_class))
  expect_equal(blk@support, "block")
  expect_true(is.finite(blk@mean) && is.finite(blk@sd))
})

test_that("the isotropic path is unchanged by the anisotropic addition", {
  set.seed(5L)
  g <- expand.grid(x = seq_len(8L), y = seq_len(8L))
  g$z <- 2 + 0.3 * g$x + sin(g$y / 2) + stats::rnorm(nrow(g), 0, 0.2)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z"), g, seed = 1L)
  expect_false(isTRUE(fit@hyper$anisotropic))
  expect_true(is.numeric(fit@hyper$ell) && length(fit@hyper$ell) == 1L)
  expect_true(is.numeric(fit@hyper$range_raw))
})
