test_that("gpfield_spec builds a valid specification with defaults", {
  spec <- gpfield_spec(c("x", "y"), "yield")
  expect_true(S7::S7_inherits(spec, gpfield_spec_class))
  expect_identical(spec@kernel, "matern")
  expect_equal(spec@nu, 1.5)
  expect_identical(spec@coords, c("x", "y"))
  expect_identical(spec@response, "yield")
  expect_true(is.na(spec@time))
})

test_that("gpfield_spec accepts the squared-exponential kernel and a time axis", {
  spec <- gpfield_spec(c("x", "y"), "ndvi", kernel = "se", time = "doy")
  expect_identical(spec@kernel, "se")
  expect_identical(spec@time, "doy")
})

test_that("gpfield_spec rejects an unknown kernel and an unsupported nu", {
  expect_error(gpfield_spec(c("x", "y"), "z", kernel = "rbf"),
               "`kernel` must be one of")
  expect_error(gpfield_spec(c("x", "y"), "z", kernel = "matern", nu = 2.0),
               "`nu` must be one of")
})

test_that("gpfield_spec validator rejects an empty coords or response", {
  expect_error(gpfield_spec(character(0), "z"))
  expect_error(gpfield_spec(c("x", "y"), ""))
})

test_that("gpfield_spec rejects a non-positive nugget", {
  expect_error(gpfield_spec(c("x", "y"), "z", nugget = 0))
})

test_that("the spec print method is silent on return value", {
  spec <- gpfield_spec(c("x", "y"), "yield")
  expect_output(print(spec), "<gpfield_spec>")
  expect_invisible(print(spec))
})
