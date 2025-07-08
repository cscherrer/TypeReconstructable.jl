"""
TypeReconstructable.jl - Type-Level Programming and Code Generation

A Julia package for abstracting values that can be reconstructed from their types,
enabling powerful metaprogramming patterns with zero runtime overhead.

# Key Features
- Type-level encoding of arbitrary values
- Reconstructable trait system for compile-time value reconstruction
- Integration with GeneralizedGenerated.jl (@gg) for advanced generated functions
- MLStyle.jl pattern matching for metaprogramming
- Scoping analysis and closure conversion with JuliaVariables.jl

# Main Modules
- `TypeLevel`: Core type-level encoding system
- `Reconstructable`: Trait system for reconstructable types
- `GGIntegration`: GeneralizedGenerated.jl integration
- `Patterns`: MLStyle.jl pattern matching utilities
- `Scoping`: Variable scoping and closure analysis
- `Examples`: Comprehensive usage examples

Based on patterns from Soss.jl but abstracted for general-purpose use.
"""
module TypeReconstructable

# Core type-level programming
include("typelevel.jl")
include("reconstructable.jl")

# Advanced metaprogramming integration
include("gg_integration.jl")
include("patterns.jl")
include("scoping.jl")

# Code generation utilities (updated version)
include("codegen.jl")

# Export main interfaces from each module
# Note: These are imported from the included files, not from submodules

# Main exports organized by functionality

# Type-level programming
export TypeLevel, to_type, from_type, @to_type, is_typelevel, base_type, type_equal

# Reconstructable types
export Reconstructable, ReconstructableValue, reconstruct, type_repr, 
       @reconstructable, make_reconstructable, is_reconstructable, can_reconstruct

# GeneralizedGenerated integration  
export @gg_autogen, @under_global_autogen, @gg_inline, make_gg_function, 
       reconstruct_gg_args, gg_closure

# Pattern matching
export @match_reconstructable, @data_reconstructable, @pattern_codegen,
       @match_type_level, @when_reconstructable, @pattern_lambda,
       TypeLevelPattern, ReconstructablePattern, decompose_reconstructable,
       pattern_transform, match_expr

# Scoping and closure analysis
export ScopeAnalyzer, analyze_scope, mark_reconstructable!, convert_closures,
       @scope_analysis, @closure_convert, @with_scope, create_scoped_function,
       resolve_variable_names

# Code generation utilities
export @autogen, @codegen, @generated_with_reconstruction, @inline_generated,
       reconstruct_args, cache_generated_code, get_cached_code, clear_codegen_cache!

end
