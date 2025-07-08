# TypeReconstructable.jl Examples

This directory contains comprehensive examples demonstrating the capabilities of TypeReconstructable.jl for type-level programming and advanced metaprogramming.

## Examples Overview

### `basic_usage.jl` - Core Functionality
Demonstrates the fundamental features of TypeReconstructable.jl:
- Type-level value encoding and reconstruction
- Basic `@gg_autogen` generated functions  
- Pattern matching with reconstructable types
- Performance comparisons between runtime and compile-time approaches

**Run with:**
```bash
julia --project examples/basic_usage.jl
```

### `advanced_features.jl` - Sophisticated Metaprogramming
Shows the advanced capabilities powered by the JuliaStaging ecosystem:
- Scope analysis and closure conversion
- Custom reconstructable types
- Advanced closure generation with `@gg`
- Sophisticated pattern matching on nested structures
- Code generation caching and management
- Runtime function generation

**Run with:**
```bash
julia --project examples/advanced_features.jl
```

## Running All Examples

You can also run all examples from the Julia REPL:

```julia
using TypeReconstructable
run_all_examples()  # Runs examples from src/example.jl
```

Or run individual example files:

```julia
include("examples/basic_usage.jl")
include("examples/advanced_features.jl")
```

## Key Concepts Demonstrated

### Type-Level Programming
- Values encoded as type parameters using `TypeLevel{T,Buf}`
- Compile-time reconstruction with zero runtime overhead
- Type-safe metaprogramming with full Julia type system integration

### Generated Functions
- `@gg_autogen` for advanced generated functions with closure support
- Automatic memoization through Julia's compilation system
- Integration with GeneralizedGenerated.jl patterns

### Pattern Matching
- MLStyle.jl integration for sophisticated AST and type pattern matching
- Custom patterns for TypeReconstructable-specific types
- Decomposition and analysis of reconstructable values

### Scoping and Closures
- JuliaVariables.jl integration for scope analysis
- Automatic closure conversion for reconstructable variables
- Name resolution in complex metaprogramming contexts

## Example Output

When you run the examples, you'll see output demonstrating:
- Values being reconstructed from their type representations
- Different code being generated based on input types
- Pattern matching results for various data structures
- Performance comparisons showing compile-time advantages
- Sophisticated closure and scoping behavior

## Integration with Soss.jl Patterns

These examples show how TypeReconstructable.jl abstracts the sophisticated patterns from Soss.jl:
- The same "value reconstructed from type" approach
- Similar use of GeneralizedGenerated.jl for advanced metaprogramming
- Pattern matching for code analysis and transformation
- Scoping analysis for proper variable handling

This makes TypeReconstructable.jl a general-purpose library that other packages can use to implement similar sophisticated metaprogramming patterns.