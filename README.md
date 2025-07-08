# TypeReconstructable.jl

[![Build Status](https://github.com/cscherrer/TypeReconstructable.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/cscherrer/TypeReconstructable.jl/actions/workflows/CI.yml?query=branch%3Amain)

**TypeReconstructable.jl** is a Julia package for type-level programming and advanced metaprogramming. It provides a sophisticated system for encoding arbitrary values as types, enabling powerful compile-time computation patterns with zero runtime overhead.

## Key Features

- **Type-Level Programming**: Encode any serializable value as a type parameter using `TypeLevel{T,Buf}`
- **Reconstructable Types**: Trait system for values that can be reconstructed from their types
- **Generated Functions**: Advanced `@gg_autogen` macro for GeneralizedGenerated.jl integration
- **Pattern Matching**: MLStyle.jl integration for sophisticated AST and type pattern matching
- **Scoping Analysis**: JuliaVariables.jl integration for proper variable scoping and closure conversion
- **Zero Runtime Overhead**: All reconstruction happens at compile time through Julia's type system

## Quick Start

### Installation

```julia
using Pkg
Pkg.add("TypeReconstructable")
```

### Basic Usage

```julia
using TypeReconstructable

# Create a reconstructable value
rv = ReconstructableValue([1, 2, 3, 4, 5])

# The value is encoded in the type
T = typeof(rv)  # ReconstructableValue{TypeLevel{Vector{Int64}, (...)}}

# Reconstruct the value from its type (happens at compile time)
reconstructed = reconstruct(T)
@assert rv.value == reconstructed.value  # true
```

### Generated Functions

```julia
# Create generated functions that reconstruct values at compile time
@gg_autogen function process_data(x::ReconstructableValue{T}) where T
    # This runs at compile time
    val = reconstruct(typeof(x))
    
    # Generate different code based on the reconstructed value
    if val.value isa Vector
        return quote
            sum($(val.value)) + length($(val.value))
        end
    else
        return quote
            $(val.value) * 2
        end
    end
end

# Usage
data = ReconstructableValue([10, 20, 30])
result = process_data(data)  # Compiles to: 60 + 3 = 63
```

### Pattern Matching

```julia
# Pattern match on reconstructable types
@match_reconstructable rv begin
    ReconstructableValue{TypeLevel{Vector{Int}, _}} => "Integer vector"
    ReconstructableValue{TypeLevel{Dict{Symbol, _}, _}} => "Symbol dictionary"
    _ => "Other type"
end
```

## Architecture

TypeReconstructable.jl abstracts sophisticated metaprogramming patterns from [Soss.jl](https://github.com/cscherrer/Soss.jl) into a general-purpose library. The core idea is the **"value that can be reconstructed from its type"** pattern:

1. **Type-Level Encoding**: Values are serialized and encoded as type parameters
2. **Compile-Time Reconstruction**: Types can be "executed" to reconstruct their values
3. **Generated Functions**: Julia's compilation system provides automatic memoization
4. **Pattern Matching**: Sophisticated analysis and transformation of encoded types

### Core Components

- **`src/typelevel.jl`**: Core `TypeLevel{T,Buf}` encoding system
- **`src/reconstructable.jl`**: `Reconstructable` trait and `ReconstructableValue` implementation
- **`src/gg_integration.jl`**: Integration with GeneralizedGenerated.jl for advanced generated functions
- **`src/patterns.jl`**: MLStyle.jl pattern matching utilities for TypeReconstructable types
- **`src/scoping.jl`**: JuliaVariables.jl integration for scope analysis and closure conversion
- **`src/codegen.jl`**: Macros and utilities for generated function creation

## Advanced Features

### Custom Reconstructable Types

```julia
# Create your own reconstructable struct
@reconstructable struct MyModel
    weights::Vector{Float64}
    bias::Float64
end

# Usage
model = MyModel([1.0, 2.0, 3.0], 0.5)
T = typeof(model)
reconstructed_model = reconstruct(T)  # Reconstructed at compile time
```

### Scope Analysis

```julia
# Analyze variable scopes for metaprogramming
analyzer = ScopeAnalyzer()
mark_reconstructable!(analyzer, :my_var)

expr = :(x -> x + my_var)
analyzed, free_vars, reconstructable_vars = analyze_scope(expr, analyzer)
```

### Runtime Function Generation

```julia
# Generate functions dynamically with proper scoping
@gg_autogen function create_function(expr_rv::ReconstructableValue{T}) where T
    expr = reconstruct(typeof(expr_rv))
    return quote
        function generated_function(x)
            $(expr.value)
        end
    end
end
```

## Examples

The `examples/` directory contains comprehensive demonstrations:

- **`basic_usage.jl`**: Core functionality and usage patterns
- **`advanced_features.jl`**: Sophisticated metaprogramming examples

Run examples with:
```bash
julia --project examples/basic_usage.jl
julia --project examples/advanced_features.jl
```

## Performance

TypeReconstructable.jl provides zero runtime overhead through compile-time reconstruction:

```julia
# Runtime approach
function runtime_process(data)
    if data isa Vector
        return sum(data)
    else
        return 0
    end
end

# Compile-time approach
@gg_autogen function compiletime_process(data::ReconstructableValue{T}) where T
    val = reconstruct(typeof(data))
    if val.value isa Vector
        return quote
            sum($(val.value))  # Inlined at compile time
        end
    else
        return quote
            0
        end
    end
end
```

The compile-time approach eliminates type checking and dispatch overhead by specializing code for each specific value.

## Background

TypeReconstructable.jl extracts and generalizes sophisticated metaprogramming patterns that were originally developed within [Soss.jl](https://github.com/cscherrer/Soss.jl) for probabilistic programming. By factoring out these core techniques, they become available to the broader Julia ecosystem without domain-specific dependencies.

## Related Projects

- **[Soss.jl](https://github.com/cscherrer/Soss.jl)**: Probabilistic programming language where these patterns originated
- **[GeneralizedGenerated.jl](https://github.com/JuliaStaging/GeneralizedGenerated.jl)**: Advanced generated functions with closure support
- **[MLStyle.jl](https://github.com/thautwarm/MLStyle.jl)**: Pattern matching for Julia
- **[JuliaVariables.jl](https://github.com/JuliaStaging/JuliaVariables.jl)**: Variable scoping analysis

## Contributing

Contributions are welcome! Please see the development setup in `CLAUDE.md` for detailed instructions on:
- Running tests: `julia --project test/runtests.jl`
- Development commands and project structure
- Architecture and design decisions

## License

This project is licensed under the MIT License - see the LICENSE file for details.
