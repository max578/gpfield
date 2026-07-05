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

test_that("the point-support guard abstains per-axis under an anisotropic fit", {
  set.seed(6L)
  # A slow oscillation in x (long correlation range) and a fast one in y (short
  # range), both finite, so the per-axis guard must judge each axis on its own.
  g <- expand.grid(x = seq(0, 30, by = 2), y = seq(0, 30, by = 2))
  g$z <- sin(0.25 * g$x) + sin(1.2 * g$y) + stats::rnorm(nrow(g), 0, 0.1)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", anisotropic = TRUE), g, seed = 6L)
  ra <- fit@hyper$range_axis
  skip_if_not(ra[["y"]] < ra[["x"]] && ra[["x"]] > 2,
              "fit not anisotropic enough for this assertion")

  # Fine on x (step 2, within the long x-range), coarse on y (past the short
  # y-range): the guard should abstain and name the y axis. A fixed point count
  # keeps the y grid from collapsing when the y-range is large.
  step_y <- 1.5 * ra[["y"]]
  q <- expand.grid(x = seq(0, 30, by = 2),
                   y = seq(0, by = step_y, length.out = 8L))
  out <- gp_predict(fit, q, spacing_tol = 1)
  expect_true(is_gpfield_abstention(out))
  expect_identical(out$reason, "range_too_short")
  expect_identical(out$diagnostics$axis, "y")
})

test_that("a spatio-temporal fit is auto-anisotropic and predicts at point support", {
  set.seed(8L)
  g <- expand.grid(x = seq_len(6L), y = seq_len(6L), t = seq_len(4L))
  g$z <- 0.2 * g$x + 0.1 * g$y + 0.5 * g$t + stats::rnorm(nrow(g), 0, 0.1)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", time = "t"), g, seed = 8L)
  expect_true(fit@hyper$anisotropic)              # time forces ARD
  expect_length(fit@hyper$range_axis, 3L)         # x, y and t each get a range

  pred <- gp_predict(fit, g[, c("x", "y", "t")], spacing_tol = 100)
  expect_true(S7::S7_inherits(pred, gpfield_prediction_class))
  expect_equal(length(pred@mean), nrow(g))
  # The trait rises steeply in time; the prediction should track it.
  lo <- gp_predict(fit, data.frame(x = 3, y = 3, t = 1))
  hi <- gp_predict(fit, data.frame(x = 3, y = 3, t = 4))
  expect_gt(hi@mean, lo@mean)
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
