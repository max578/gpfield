.onLoad <- function(libname, pkgname) {
  # Register the S7 methods this package defines for base / stats generics
  # (print, predict) and for the orchestra `as_orchestra_manifest()` generic.
  S7::methods_register()

  # `S3method()` in NAMESPACE registers a print method against the *installed*
  # generic table at build time, but base::print's S3 dispatch also consults
  # base::.__S3MethodsTable__. directly, and package installation does not
  # always populate that table for print methods declared this way -- the
  # plain-list abstention/block-support classes then print via print.default
  # under `library(gpfield)`, exposing `attr(,"class")` to the user, even
  # though the exact same call dispatches correctly from inside the namespace
  # (where the function is lexically visible regardless of registration).
  # Registering explicitly here closes that gap for a real installed load.
  registerS3method("print", "gpfield_abstention", print.gpfield_abstention,
                   envir = asNamespace(pkgname))
  registerS3method("print", "gpfield_block_support",
                   print.gpfield_block_support, envir = asNamespace(pkgname))
  invisible(NULL)
}

# `.data` is the rlang / ggplot2 tidy-evaluation pronoun used in the optional
# `gp_field_plot()` helper (ggplot2 is in Suggests, so it cannot be imported);
# declaring it global silences the "no visible binding" note without a hard
# dependency on rlang.
utils::globalVariables(".data")
