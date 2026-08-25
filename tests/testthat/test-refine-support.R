# test-refine-support.R -- refine() must not escape a base grid the fit's
# correlation range cannot resolve (G-03).
#
# The guard gp_field_smooth() inherits from gp_predict() is meant to abstain
# whenever the field cannot support the requested resolution. Refining only
# inserts points strictly between the *observed* row-column locations, so a
# base grid the range already cannot resolve must not become resolvable
# merely by asking for a denser grid between the same unsupported points.

test_that("refine() never escapes a base grid the range cannot resolve", {
  set.seed(1L)
  field <- expand.grid(row = seq_len(10L), col = seq_len(10L))
  # A fast-oscillating surface fits a short correlation range, well shorter
  # than the observed 1-unit plot spacing.
  field$yield <- sin(field$row * 2) * cos(field$col * 2) +
    stats::rnorm(nrow(field), 0, 0.05)

  base <- gp_field_smooth(field, response = "yield", refine = 1L, seed = 1L)
  expect_true(is_gpfield_abstention(base))
  expect_identical(base$reason, "range_too_short")

  # Before the fix, a large enough refine escaped the guard: the refined
  # grid's own internal spacing shrank below the range even though the
  # observed grid it was built from never became any better supported.
  fine <- gp_field_smooth(field, response = "yield", refine = 20L, seed = 1L)
  expect_true(is_gpfield_abstention(fine))
  expect_identical(fine$reason, "range_too_short")
})

test_that("refine() still succeeds when the observed grid is well supported", {
  set.seed(2L)
  field <- expand.grid(row = seq_len(10L), col = seq_len(10L))
  field$yield <- 3 + 0.2 * field$row - 0.1 * field$col +
    stats::rnorm(nrow(field), 0, 0.2)

  sm <- gp_field_smooth(field, response = "yield", refine = 2L, seed = 2L)
  expect_false(is_gpfield_abstention(sm))
  expect_true(S7::S7_inherits(sm, gpfield_smooth_class))
})
