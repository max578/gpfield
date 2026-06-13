test_that("point prediction returns mean and sd per query row", {
  fit <- .fitted_field()
  q <- expand.grid(x = seq_len(10L), y = seq_len(10L))
  pred <- gp_predict(fit, q)
  expect_true(S7::S7_inherits(pred, gpfield_prediction_class))
  expect_identical(pred@support, "point")
  expect_equal(length(pred@mean), nrow(q))
  expect_equal(length(pred@sd), nrow(q))
  expect_true(all(pred@sd > 0))
})

test_that("point prediction tracks the underlying gradient", {
  # The synthetic field rises in x; the smoothed prediction should too.
  fit <- .fitted_field()
  lo <- gp_predict(fit, data.frame(x = 2, y = 5))
  hi <- gp_predict(fit, data.frame(x = 9, y = 5))
  expect_gt(hi@mean, lo@mean)
})

test_that("predictive sd is smaller near data than far from it", {
  fit <- .fitted_field()
  near <- gp_predict(fit, data.frame(x = 5, y = 5))
  # A point one range beyond the field edge: still within the spacing guard
  # because a single query has zero spacing, so the prediction is returned.
  far <- gp_predict(fit, data.frame(x = 16, y = 16))
  expect_lt(near@sd, far@sd)
})

test_that("point prediction abstains on a coarse grid (range_too_short)", {
  fit <- .fitted_field()
  q <- data.frame(x = c(1, 60, 120), y = c(1, 60, 120))
  out <- gp_predict(fit, q)
  expect_true(is_gpfield_abstention(out))
  expect_identical(out$reason, "range_too_short")
  expect_true(is.numeric(out$diagnostics$spacing))
  expect_true(is.numeric(out$diagnostics$range))
})

test_that("point prediction abstains on an empty query", {
  fit <- .fitted_field()
  out <- gp_predict(fit, data.frame(x = numeric(0), y = numeric(0)))
  expect_true(is_gpfield_abstention(out))
  expect_identical(out$reason, "empty_query")
})

test_that("point prediction errors on a missing query column", {
  fit <- .fitted_field()
  expect_error(gp_predict(fit, data.frame(x = 1)), "missing column")
})

test_that("gp_predict errors when fit is not a gpfield_fit", {
  expect_error(gp_predict(list(), data.frame(x = 1, y = 1)),
               "must be a `gpfield_fit`")
})
