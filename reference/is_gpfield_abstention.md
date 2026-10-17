# Is an object a gpfield abstention?

Is an object a gpfield abstention?

## Usage

``` r
is_gpfield_abstention(x)
```

## Arguments

- x:

  Any object.

## Value

A single logical: `TRUE` when `x` is a `gpfield_abstention`.

## Examples

``` r
is_gpfield_abstention(gpfield_abstention("support_gap"))
#> [1] TRUE
is_gpfield_abstention(42)
#> [1] FALSE
```
