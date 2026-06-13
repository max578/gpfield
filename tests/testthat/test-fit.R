test_that("gp_fit returns a fitted GP with a positive range and finite loglik", {
  fit <- .fitted_field()
  expect_true(S7::S7_inherits(fit, gpfield_fit_class))
  expect_gt(fit@hyper$range_raw, 0)
  expect_true(is.finite(fit@loglik))
  expect_equal(length(fit@y_raw), 100L)
  expect_identical(fit@emitter_version,
                   as.character(utils::packageVersion("gpfield")))
})

test_that("gp_fit works for both kernels and all Matern smoothness values", {
  expect_true(S7::S7_inherits(.fitted_field(kernel = "se"), gpfield_fit_class))
  for (nu in c(0.5, 1.5, 2.5)) {
    fit <- .fitted_field(kernel = "matern", nu = nu)
    expect_true(S7::S7_inherits(fit, gpfield_fit_class))
    expect_true(is.finite(fit@loglik))
  }
})

test_that("gp_fit records the seed as provenance metadata", {
  fit <- .fitted_field(seed = 7L)
  expect_identical(fit@seed, 7L)
})

test_that("gp_fit drops incomplete rows before fitting", {
  g <- .make_field()
  g$yield[1:5] <- NA_real_
  fit <- gp_fit(gpfield_spec(c("x", "y"), "yield"), g, seed = 1L)
  expect_true(S7::S7_inherits(fit, gpfield_fit_class))
  expect_equal(length(fit@y_raw), 95L)
})

test_that("gp_fit abstains when too few observations remain", {
  g <- data.frame(x = c(1, 2), y = c(1, 2), yield = c(3, 4))
  out <- gp_fit(gpfield_spec(c("x", "y"), "yield"), g)
  expect_true(is_gpfield_abstention(out))
  expect_identical(out$reason, "degenerate_fit")
})

test_that("gp_fit errors on a missing column or non-numeric coordinate", {
  g <- .make_field()
  expect_error(gp_fit(gpfield_spec(c("x", "z"), "yield"), g),
               "missing column")
  g$x <- as.character(g$x)
  expect_error(gp_fit(gpfield_spec(c("x", "y"), "yield"), g),
               "must be numeric")
})

test_that("gp_fit is deterministic for a fixed input", {
  a <- .fitted_field(seed = 3L)
  b <- .fitted_field(seed = 3L)
  expect_equal(a@hyper$range_raw, b@hyper$range_raw)
  expect_equal(a@loglik, b@loglik)
})
