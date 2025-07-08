#!/usr/bin/env julia
"""
Basic Usage Examples for TypeReconstructable.jl

This file demonstrates the core functionality of TypeReconstructable.jl
with simple, working examples.
"""

using TypeReconstructable

println("TypeReconstructable.jl - Basic Usage Examples")
println("=" ^ 50)

# =============================================================================
# 1. Type-Level Encoding
# =============================================================================

println("\n1. Type-Level Encoding")
println("-" ^ 30)

# Encode a value as a type
data = [1, 2, 3, 4, 5]
T = to_type(data)
println("Original data: ", data)
println("Type: ", T)

# Decode the type back to a value
reconstructed = from_type(T)
println("Reconstructed: ", reconstructed)
println("Equal? ", data == reconstructed)

# Using the macro form
T_macro = @to_type [10, 20, 30]
macro_result = from_type(T_macro)
println("Macro result: ", macro_result)

# =============================================================================
# 2. Reconstructable Values
# =============================================================================

println("\n2. Reconstructable Values")
println("-" ^ 30)

# Create a reconstructable value
rv = ReconstructableValue([1, 2, 3, 4, 5])
println("ReconstructableValue: ", rv)
println("Type: ", typeof(rv))

# Reconstruct from the type
reconstructed_rv = reconstruct(typeof(rv))
println("Reconstructed value: ", reconstructed_rv.value)
println("Equal? ", rv.value == reconstructed_rv.value)

# Test with different types
string_rv = ReconstructableValue("Hello, World!")
string_reconstructed = reconstruct(typeof(string_rv))
println("String reconstruction: ", string_reconstructed.value)

# =============================================================================
# 3. Generated Functions
# =============================================================================

println("\n3. Generated Functions")
println("-" ^ 30)

# Simple generated function using TypeReconstructable
@generated function process_data(rv::ReconstructableValue{T}) where T
    # This happens at compile time
    val = from_type(T)
    
    if val isa Vector{Int}
        return quote
            # Generate optimized code for integer vectors
            sum($(val)) + length($(val))
        end
    else
        return quote
            # Generate code for other types
            $(val)
        end
    end
end

# Test the generated function
int_rv = ReconstructableValue([1, 2, 3, 4, 5])
result = process_data(int_rv)
println("Generated function result: ", result)

# The generated function is memoized - same type = same generated code
int_rv2 = ReconstructableValue([1, 2, 3, 4, 5])
result2 = process_data(int_rv2)
println("Second call result: ", result2)

# =============================================================================
# 4. Pattern Matching
# =============================================================================

println("\n4. Pattern Matching")
println("-" ^ 30)

# Decompose a reconstructable value
base_type, encoded, reconstructed_val = decompose_reconstructable(rv)
println("Base type: ", base_type)
println("Reconstructed value: ", reconstructed_val)

# Test with different types
dict_rv = ReconstructableValue(Dict(:a => 1, :b => 2))
dict_base, dict_encoded, dict_val = decompose_reconstructable(dict_rv)
println("Dict base type: ", dict_base)
println("Dict value: ", dict_val)

# =============================================================================
# 5. Type Checking
# =============================================================================

println("\n5. Type Checking")
println("-" ^ 30)

# Check if a type is reconstructable
println("Is Vector{Int} reconstructable? ", can_reconstruct([1, 2, 3]))
println("Is String reconstructable? ", can_reconstruct("hello"))
println("Is ReconstructableValue reconstructable? ", is_reconstructable(typeof(rv)))

# Check type equality
T1 = to_type([1, 2, 3])
T2 = to_type([1, 2, 3])
println("Same type for same value? ", T1 == T2)

T3 = to_type([1, 2, 4])
println("Different type for different value? ", T1 != T3)

# =============================================================================
# 6. Performance Characteristics
# =============================================================================

println("\n6. Performance Characteristics")
println("-" ^ 30)

# Type-level operations are fast
using BenchmarkTools

small_data = [1, 2, 3]
small_T = to_type(small_data)

println("Encoding time:")
@btime to_type($small_data)

println("Decoding time:")
@btime from_type($small_T)

# Reconstruction is also fast
small_rv = ReconstructableValue(small_data)
println("Reconstruction time:")
@btime reconstruct(typeof($small_rv))

# Generated functions have zero runtime overhead after compilation
println("Generated function time:")
@btime process_data($small_rv)

println("\n" ^ 2 * "=" ^ 50)
println("All basic examples completed successfully!")
println("Next: Try examples/advanced_features.jl")