# test-field.R -- the row-column MET / field-smoothing convenience path.

test_that("gp_field_smooth returns a fit and a prediction on a row-col layout", {
  f <- .make_field()
  names(f) <- c("row", "col", "yield")
  sm <- gp_field_smooth(f, response = "yield", seed = 1L)
  expect_false(is_gpfield_abstention(sm))
  expect_true(S7::S7_inherits(sm$fit, gpfield_fit_class))
  expect_true(S7::S7_inherits(sm$prediction, gpfield_prediction_class))
  # On the observed grid (refine = 1) one prediction per plot.
  expect_equal(length(sm$prediction@mean), nrow(f))
})

test_that("gp_field_smooth refines the grid by the requested factor", {
  f <- .make_field()
  names(f) <- c("row", "col", "yield")
  sm <- gp_field_smooth(f, response = "yield", refine = 2L, seed = 1L)
  expect_false(is_gpfield_abstention(sm))
  # A 10x10 grid refined x2 -> 19x19.
  expect_equal(length(sm$prediction@mean), 19L * 19L)
})

test_that("gp_field_smooth propagates an abstention from the fit", {
  f <- data.frame(row = c(1, 2), col = c(1, 2), yield = c(3, 4))
  out <- gp_field_smooth(f, response = "yield")
  expect_true(is_gpfield_abstention(out))
})

test_that("gp_field_smooth validates its arguments", {
  f <- .make_field()
  names(f) <- c("row", "col", "yield")
  expect_error(gp_field_smooth(as.matrix(f), "yield"), "must be a data.frame")
  expect_error(gp_field_smooth(f, "yield", refine = 0L), "positive integer")
})

test_that("gp_field_plot builds a ggplot when ggplot2 is present", {
  skip_if_not_installed("ggplot2")
  f <- .make_field()
  names(f) <- c("row", "col", "yield")
  sm <- gp_field_smooth(f, response = "yield", seed = 1L)
  p <- gp_field_plot(sm)
  expect_s3_class(p, "ggplot")
})

test_that("gp_field_plot rejects a non-point prediction", {
  skip_if_not_installed("ggplot2")
  fit <- .fitted_field()
  bl <- block_support(lower = rbind(c(1, 1)), upper = rbind(c(6, 6)))
  blk <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
  expect_error(gp_field_plot(blk), "point-support")
})
