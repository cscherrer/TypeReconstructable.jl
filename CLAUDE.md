# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
- `julia --project test/runtests.jl` - Run all tests
- `julia --project -e "using Pkg; Pkg.test()"` - Run tests via Pkg manager

### Benchmarking
- `julia --project bench/runbenchmarks.jl` - Run comprehensive benchmark suite
- `julia --project bench/regression_test.jl` - Run regression test against baseline
- `julia --project bench/regression_test.jl baseline` - Create new performance baseline

### Package Management
- `julia --project -e "using Pkg; Pkg.instantiate()"` - Install dependencies
- `julia --project -e "using Pkg; Pkg.build()"` - Build the package

### REPL Development
- `julia --project` - Start Julia REPL with project environment
- `julia --project -e "using Revise; using TypeReconstructable"` - Load package with auto-reloading

### Examples
- `julia --project examples/basic_usage.jl` - Run basic usage examples
- `julia --project examples/advanced_features.jl` - Run advanced feature examples

## Project Structure

TypeReconstructable.jl is a sophisticated metaprogramming library that abstracts type-level programming patterns from Soss.jl:

### Core Components
- `src/typelevel.jl` - TypeLevel encoding system for values as types
- `src/reconstructable.jl` - Reconstructable trait for compile-time value reconstruction
- `src/gg_integration.jl` - GeneralizedGenerated.jl integration (@gg macros)
- `src/patterns.jl` - MLStyle.jl pattern matching utilities
- `src/scoping.jl` - JuliaVariables.jl scoping and closure analysis
- `src/codegen.jl` - Code generation utilities and caching
- `examples/` - Comprehensive usage examples and documentation

### Key Dependencies
- `GeneralizedGenerated.jl` - Advanced generated functions with closures
- `MLStyle.jl` - Pattern matching for metaprogramming
- `JuliaVariables.jl` - Variable scoping analysis
- `NameResolution.jl` - Name resolution in complex scopes

## Architecture

TypeReconstructable.jl implements the "value that can be reconstructed from its type" pattern, abstracting sophisticated metaprogramming techniques from Soss.jl into a general-purpose library.

### Core Design Principles

1. **Type-Level Computation**: Values are elevated to the type level, enabling compile-time computation
2. **Zero Runtime Overhead**: All reconstruction happens during compilation through Julia's type system
3. **Composable Abstractions**: Each component can be used independently or combined for complex scenarios
4. **JuliaStaging Integration**: Leverages the JuliaStaging ecosystem for advanced metaprogramming

### Architecture Layers

#### 1. Type-Level Encoding (`typelevel.jl`)
- **`TypeLevel{T,Buf}`**: Core encoding structure that serializes values into type parameters
- **Serialization-Based**: Uses Julia's built-in serialization for maximum compatibility
- **Type Safety**: Preserves original type information for reconstruction verification
- **Buffer Encoding**: Converts serialized data to tuples of UInt8 for type parameter storage

#### 2. Reconstructable Trait System (`reconstructable.jl`)
- **`Reconstructable{T}`**: Abstract trait for types that can be reconstructed from their type representation
- **`ReconstructableValue{T}`**: Concrete implementation that wraps arbitrary values
- **`@reconstructable`**: Macro for automatically making structs reconstructable
- **Interface Methods**: `reconstruct()` and `type_repr()` define the core protocol

#### 3. Generated Function Integration (`gg_integration.jl`)
- **`@gg_autogen`**: Enhanced version of GeneralizedGenerated.jl's `@gg` macro
- **Automatic Reconstruction**: Handles reconstruction of Reconstructable arguments transparently
- **Closure Support**: Maintains GeneralizedGenerated.jl's closure capabilities
- **Memoization**: Leverages Julia's generated function memoization automatically

#### 4. Pattern Matching (`patterns.jl`)
- **MLStyle Integration**: Extends MLStyle.jl for TypeReconstructable-specific patterns
- **Type-Level Patterns**: Pattern matching on TypeLevel encodings
- **Reconstructable Patterns**: Specialized patterns for Reconstructable types
- **Code Generation**: Pattern-based code generation utilities

#### 5. Scoping Analysis (`scoping.jl`)
- **JuliaVariables Integration**: Proper variable scoping analysis
- **Closure Conversion**: Transforms closures to handle reconstructable variables
- **Name Resolution**: Resolves variable names in complex scoping contexts
- **Free Variable Detection**: Identifies and handles free variables in generated code

#### 6. Code Generation Utilities (`codegen.jl`)
- **`@autogen`**: Simplified macro for creating generated functions
- **Parameter Transformation**: Converts function parameters to handle Reconstructable types
- **Code Caching**: Optional caching system for generated code
- **Error Handling**: Comprehensive validation and error reporting

### Key Patterns and Techniques

#### The "Value-as-Type" Pattern
```julia
# Value at runtime
value = [1, 2, 3]

# Value encoded as type
T = TypeLevel{Vector{Int}, (0x37, 0x4a, ...)}

# Value reconstructed at compile time
reconstructed = from_type(T)  # Happens during compilation
```

#### Compile-Time Specialization
```julia
@gg_autogen function process(x::ReconstructableValue{T}) where T
    val = reconstruct(typeof(x))  # Compile-time reconstruction
    
    # Generate specialized code based on the actual value
    if val.value isa Vector{Int}
        return quote
            sum($(val.value))  # Inlined literal values
        end
    else
        return quote
            $(val.value) * 2
        end
    end
end
```

#### Automatic Memoization
Julia's generated function system automatically memoizes results based on type signatures, providing zero-cost memoization for reconstructed values.

#### Type-Safe Metaprogramming
All operations preserve type information and provide compile-time verification, eliminating many common metaprogramming errors.

### Performance Characteristics

- **Zero Runtime Overhead**: Reconstruction happens entirely at compile time
- **Type-Specialized Code**: Generated functions produce optimized code for each specific value
- **Automatic Memoization**: Julia's compilation system provides free memoization
- **Minimal Memory Overhead**: Values are stored as type parameters, not runtime data

### Integration with JuliaStaging Ecosystem

TypeReconstructable.jl is designed to work seamlessly with the JuliaStaging ecosystem:

- **GeneralizedGenerated.jl**: Advanced generated functions with closure support
- **MLStyle.jl**: Sophisticated pattern matching for AST manipulation
- **JuliaVariables.jl**: Variable scoping analysis and name resolution
- **NameResolution.jl**: Complex name resolution in metaprogramming contexts

### Design Decisions

1. **Serialization-Based Encoding**: Chosen for maximum compatibility with Julia's type system
2. **Trait-Based Design**: Provides flexibility while maintaining type safety
3. **Macro-Heavy Interface**: Enables natural syntax while hiding complexity
4. **Fallback Mechanisms**: Graceful degradation when advanced features aren't available
5. **Error-First Design**: Comprehensive error handling and validation throughout

### Relationship to Soss.jl

TypeReconstructable.jl extracts and generalizes specific metaprogramming functionality that was originally developed within Soss.jl:

**Factored Out Functionality:**
- **Type-level value encoding**: The `TypeLevel{T,Buf}` pattern for compile-time value reconstruction
- **Reconstructable trait system**: The "value that can be reconstructed from its type" interface
- **Generated function utilities**: Enhanced `@gg` macros with automatic argument reconstruction
- **Pattern matching integration**: MLStyle.jl extensions for metaprogramming contexts
- **Scoping analysis**: JuliaVariables.jl integration for proper variable handling

**Benefits of Factoring Out:**
- **Broader Applicability**: These patterns can now be used in any Julia package, not just probabilistic programming
- **Reduced Dependencies**: Other packages can use these sophisticated patterns without pulling in Soss.jl's domain-specific dependencies
- **Improved Maintainability**: Core metaprogramming functionality is separated from domain logic
- **Enhanced Reusability**: Modular components can be mixed and matched as needed

This allows Soss.jl to focus on probabilistic programming while making its sophisticated metaprogramming techniques available to the broader Julia ecosystem.

This architecture enables TypeReconstructable.jl to serve as a foundational library for sophisticated metaprogramming while remaining accessible and composable.

## Examples and Testing

Run examples to see the library in action:
```bash
julia --project examples/basic_usage.jl       # Core functionality
julia --project examples/advanced_features.jl # Advanced metaprogramming
```

The examples cover:
- Basic type-level value reconstruction
- Generated functions with @gg_autogen
- Pattern matching with reconstructable types
- Scope analysis and closure conversion
- Performance comparisons
- Custom reconstructable types
- Code generation caching and runtime function generation

## CI/CD

The project uses GitHub Actions for continuous integration with enhanced dependency management for the JuliaStaging ecosystem packages.