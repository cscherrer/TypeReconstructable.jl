"""
Basic Usage Examples for TypeReconstructable.jl

This file demonstrates the core functionality of TypeReconstructable.jl for type-level
programming and code generation.

Run this file with:
julia --project examples/basic_usage.jl
"""

using TypeReconstructable

"""
    Example 1: Basic Reconstructable Values

Demonstrates the core functionality of type-level value reconstruction.
"""
function example_basic_reconstructable()
    println("=== Basic Reconstructable Example ===")
    
    # Create a reconstructable value
    rv = ReconstructableValue([1, 2, 3, 4, 5])
    println("Original value: ", rv.value)
    
    # Get the type representation
    T = typeof(rv)
    println("Type representation: ", T)
    
    # Reconstruct from type
    reconstructed = reconstruct(T)
    println("Reconstructed value: ", reconstructed.value)
    
    # Verify they're equal
    println("Values equal: ", rv.value == reconstructed.value)
    println()
end

"""
    Example 2: Generated Functions with Reconstruction

Shows how to use @gg_autogen for generated functions that work with Reconstructable types.
"""
@gg_autogen function compute_on_reconstructable(x::ReconstructableValue{T}) where T
    # Reconstruct the value at compile time
    val = reconstruct(typeof(x))
    
    # Generate different code based on the type
    if val.value isa Vector
        return quote
            sum($(val.value)) + length($(val.value))
        end
    elseif val.value isa Dict
        return quote
            length($(val.value))
        end
    else
        return quote
            $(val.value)
        end
    end
end

function example_generated_functions()
    println("=== Generated Functions Example ===")
    
    # Create different types of reconstructable values
    vector_rv = ReconstructableValue([10, 20, 30])
    dict_rv = ReconstructableValue(Dict(:a => 1, :b => 2, :c => 3))
    scalar_rv = ReconstructableValue(42)
    
    # The generated function produces different code for each type
    println("Vector result: ", compute_on_reconstructable(vector_rv))
    println("Dict result: ", compute_on_reconstructable(dict_rv))
    println("Scalar result: ", compute_on_reconstructable(scalar_rv))
    println()
end

"""
    Example 3: Pattern Matching with Reconstructable Types

Demonstrates MLStyle integration for pattern matching on reconstructable types.
"""
function example_pattern_matching()
    println("=== Pattern Matching Example ===")
    
    values = [
        ReconstructableValue([1, 2, 3]),
        ReconstructableValue(Dict(:key => "value")),
        ReconstructableValue("hello world"),
        ReconstructableValue(42)
    ]
    
    for rv in values
        result = @match_reconstructable rv begin
            ReconstructableValue{TypeLevel{Vector{Int}, _}} => "Integer vector with $(length(rv.value)) elements"
            ReconstructableValue{TypeLevel{Dict{Symbol, String}, _}} => "Symbol-String dictionary"
            ReconstructableValue{TypeLevel{String, _}} => "String: \"$(rv.value)\""
            ReconstructableValue{TypeLevel{Int, _}} => "Integer: $(rv.value)"
            _ => "Unknown type"
        end
        println("Pattern matched: ", result)
    end
    println()
end

"""
    Example 4: Performance Comparison

Compares performance between runtime and compile-time approaches.
"""
function example_performance_comparison()
    println("=== Performance Comparison Example ===")
    
    # Create test data
    test_data = ReconstructableValue(randn(1000))
    
    # Runtime approach
    function runtime_process(data)
        if data isa Vector
            return sum(abs, data)
        else
            return 0.0
        end
    end
    
    # Compile-time approach using @gg_autogen
    @gg_autogen function compiletime_process(data::ReconstructableValue{T}) where T
        val = reconstruct(typeof(data))
        if val.value isa Vector
            return quote
                sum(abs, $(val.value))
            end
        else
            return quote
                0.0
            end
        end
    end
    
    # Time both approaches
    println("Runtime approach:")
    @time runtime_result = runtime_process(test_data.value)
    
    println("Compile-time approach:")
    @time compiletime_result = compiletime_process(test_data)
    
    println("Results equal: ", runtime_result ≈ compiletime_result)
    println()
end

"""
    main()

Run all basic examples to demonstrate TypeReconstructable.jl capabilities.
"""
function main()
    println("TypeReconstructable.jl Basic Usage Examples")
    println("============================================")
    println()
    
    example_basic_reconstructable()
    example_generated_functions()
    example_pattern_matching()
    example_performance_comparison()
    
    println("Basic examples completed!")
end

# Run examples if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end