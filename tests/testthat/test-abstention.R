# test-abstention.R -- the typed refusal object itself.

test_that("gpfield_abstention builds a classed refusal", {
  a <- gpfield_abstention("range_too_short", "too coarse")
  expect_s3_class(a, "gpfield_abstention")
  expect_true(a$abstained)
  expect_identical(a$reason, "range_too_short")
  expect_identical(a$detail, "too coarse")
})

test_that("is_gpfield_abstention discriminates", {
  expect_true(is_gpfield_abstention(gpfield_abstention("support_gap")))
  expect_false(is_gpfield_abstention(42))
  expect_false(is_gpfield_abstention(list(abstained = TRUE)))
})

test_that("gpfield_abstention rejects an unknown reason code", {
  expect_error(gpfield_abstention("made_up"), "`reason` must be one of")
})

test_that("gpfield_abstention carries machine-readable diagnostics", {
  a <- gpfield_abstention("range_too_short", diagnostics = list(range = 2.1))
  expect_equal(a$diagnostics$range, 2.1)
  expect_error(gpfield_abstention("support_gap", diagnostics = 1),
               "`diagnostics` must be a list")
})

test_that("the abstention print method is informative and invisible", {
  a <- gpfield_abstention("support_gap", "no data near block",
                          diagnostics = list(reach = 3.0))
  expect_output(print(a), "<gpfield_abstention>")
  expect_output(print(a), "support_gap")
  expect_invisible(print(a))
})
