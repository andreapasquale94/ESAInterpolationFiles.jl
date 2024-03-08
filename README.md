# Ipf.jl

_ESA Interpolation Files made easy._

Ipf.jl is a Julia library that provides fast and allocation-free access to binary ESA/ESOC interpolation files or IPF. Completely written in Julia, it enables Automatic-Differentiation (AD) via [ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl) and [TaylorSeries.jl](https://github.com/JuliaDiff/TaylorSeries.jl) across all of its function calls. 

## Usage

The `compute` and `compute_derivative` functions can be used to perform interpolation and compute derivatives from an IPF file.

### Example Usage:

```julia
using Ipf

# Load an IPF file
file = IPF("example.ipf")

# Compute interpolated value for a given key
value = compute(file, 10.5)

# Compute derivative for a given key
derivative = compute_derivative(file, 10.5)
```

## Support
If you found this package useful, please consider starring the repository. 

## Disclaimer 
This package is not affiliated with ESA/ESOC.