# test-s3-registration.R -- the abstention/block-support S3 print methods must
# actually enter base::.__S3MethodsTable__. so a user session dispatches to
# them under `library(gpfield)`, not just lexically inside the namespace
# (G-05). testthat evaluates inside the package namespace, where the methods
# are lexically visible regardless of registration, so this asserts
# registration directly (getS3method) plus a clean-session round trip.

test_that("print.gpfield_abstention is registered for user-session dispatch", {
  expect_false(is.null(getS3method("print", "gpfield_abstention",
                                   optional = TRUE)))
})

test_that("print.gpfield_block_support is registered for user-session dispatch", {
  expect_false(is.null(getS3method("print", "gpfield_block_support",
                                   optional = TRUE)))
})

test_that("a clean session dispatches print.gpfield_abstention, not the default", {
  skip_if_not_installed("callr")
  out <- callr::r(function() {
    library(gpfield)
    a <- gpfield_abstention("support_gap", "no training data nearby")
    paste(capture.output(print(a)), collapse = "\n")
  })
  expect_match(out, "<gpfield_abstention>", fixed = TRUE)
  expect_no_match(out, "attr(,\"class\")", fixed = TRUE)
})
