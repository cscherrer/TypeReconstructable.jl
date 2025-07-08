"""
Advanced Features Examples for TypeReconstructable.jl

This file demonstrates the advanced metaprogramming capabilities of TypeReconstructable.jl,
including scoping analysis, closure conversion, and integration with the
JuliaStaging ecosystem.

Run this file with:
julia --project examples/advanced_features.jl
"""

using TypeReconstructable

"""
    Example 1: Scope Analysis and Closure Conversion

Shows how to use the scoping utilities for analyzing and converting closures.
"""
function example_scope_analysis()
    println("=== Scope Analysis Example ===")
    
    # Create a reconstructable variable
    captured_var = ReconstructableValue([1, 2, 3, 4, 5])
    
    # Analyze scope of an expression with closures
    expr = :(map(x -> x + captured_var, data))
    
    analyzer = ScopeAnalyzer()
    mark_reconstructable!(analyzer, :captured_var)
    
    analyzed, free_vars, reconstructable_vars = analyze_scope(expr, analyzer)
    
    println("Original expression: ", expr)
    println("Free variables: ", free_vars)
    println("Reconstructable variables: ", reconstructable_vars)
    
    # Convert closures to handle reconstructable variables
    converted = convert_closures(analyzed, free_vars, reconstructable_vars)
    println("Converted expression: ", converted)
    println()
end

"""
    Example 2: Custom Reconstructable Type

Demonstrates creating a custom type that integrates with TypeReconstructable.
"""
function example_custom_reconstructable()
    println("=== Custom Reconstructable Type Example ===")
    
    # Create a neural network data structure
    weights = [randn(3, 2), randn(2, 1)]
    biases = [randn(3), randn(2)]
    
    # Create a reconstructable struct (simplified since functions aren't serializable)
    network_data = (
        weights = weights,
        biases = biases,
        layers = [3, 2, 1],
        activation = "tanh"  # String instead of function
    )
    
    # Make it reconstructable
    rv_network = ReconstructableValue(network_data)
    
    T = typeof(rv_network)
    reconstructed = reconstruct(T)
    
    println("Original network layers: ", rv_network.value.layers)
    println("Reconstructed network layers: ", reconstructed.value.layers)
    println("Weights preserved: ", rv_network.value.weights ≈ reconstructed.value.weights)
    println("Data structure preserved: ", rv_network.value == reconstructed.value)
    println()
end

"""
    Example 3: Closure Generation with @gg

Demonstrates using GeneralizedGenerated for closure creation.
"""
@gg function create_closure(captured_value)
    quote
        x -> x + $captured_value
    end
end

function example_closure_generation()
    println("=== Closure Generation Example ===")
    
    # Create a closure that captures a value
    captured = 10
    closure = create_closure(captured)
    
    # Use the closure
    result = closure(5)
    println("Closure result: ", result)  # Should be 15
    
    # Create closure with reconstructable value
    rv = ReconstructableValue([1, 2, 3])
    
    # This demonstrates how closures can work with reconstructable values
    @gg function create_reconstructable_closure(rv::ReconstructableValue{T}) where T
        val = reconstruct(typeof(rv))
        quote
            x -> x + sum($(val.value))
        end
    end
    
    rv_closure = create_reconstructable_closure(rv)
    rv_result = rv_closure(10)
    println("Reconstructable closure result: ", rv_result)  # Should be 16 (10 + 6)
    println()
end

"""
    Example 4: Advanced Pattern Matching

Shows sophisticated pattern matching capabilities.
"""
function example_advanced_pattern_matching()
    println("=== Advanced Pattern Matching Example ===")
    
    # Create nested reconstructable structures
    nested_data = [
        ReconstructableValue(Dict(:type => "vector", :data => [1, 2, 3])),
        ReconstructableValue(Dict(:type => "matrix", :data => [1 2; 3 4])),
        ReconstructableValue(Dict(:type => "scalar", :data => 42))
    ]
    
    for rv in nested_data
        # Decompose the reconstructable value
        base_type, encoded, reconstructed_val = decompose_reconstructable(rv)
        
        # Pattern match on the structure
        result = @match reconstructed_val begin
            Dict{Symbol, Any} && d if d[:type] == "vector" => 
                "Vector with $(length(d[:data])) elements"
            Dict{Symbol, Any} && d if d[:type] == "matrix" => 
                "Matrix with size $(size(d[:data]))"
            Dict{Symbol, Any} && d if d[:type] == "scalar" => 
                "Scalar value: $(d[:data])"
            _ => "Unknown structure"
        end
        
        println("Advanced pattern matched: ", result)
    end
    println()
end

"""
    Example 5: Code Generation with Caching

Demonstrates the code generation caching system.
"""
function example_code_generation_caching()
    println("=== Code Generation Caching Example ===")
    
    # Clear any existing cache
    clear_codegen_cache!()
    
    # Generate some code and cache it
    test_code_1 = :(x + y + z)
    test_code_2 = :(a * b - c)
    
    cache_generated_code("function_1", test_code_1)
    cache_generated_code("function_2", test_code_2)
    
    # Retrieve cached code
    retrieved_1 = get_cached_code("function_1")
    retrieved_2 = get_cached_code("function_2")
    
    println("Cached code 1: ", retrieved_1)
    println("Cached code 2: ", retrieved_2)
    println("Cache working correctly: ", retrieved_1 == test_code_1 && retrieved_2 == test_code_2)
    
    # Show cache miss
    missing_code = get_cached_code("nonexistent")
    println("Cache miss returns: ", missing_code)
    
    clear_codegen_cache!()
    println("Cache cleared successfully")
    println()
end

"""
    Example 6: Runtime Function Generation

Shows how to create functions dynamically using TypeReconstructable patterns.
"""
function example_runtime_function_generation()
    println("=== Runtime Function Generation Example ===")
    
    # Create a simple mathematical expression reconstructable
    expr_data = ReconstructableValue(:(x^2 + 2*x + 1))
    
    # Generate a function that evaluates this expression
    @gg_autogen function create_evaluator(expr_rv::ReconstructableValue{T}) where T
        expr_val = reconstruct(typeof(expr_rv))
        
        return quote
            function evaluate(x)
                $(expr_val.value)
            end
        end
    end
    
    # Create the evaluator function
    evaluator_code = create_evaluator(expr_data)
    println("Generated evaluator code: ", evaluator_code)
    
    # We could eval this in a real scenario, but for demo purposes just show the structure
    println("This demonstrates runtime generation of specialized functions")
    println()
end

"""
    main()

Run all advanced examples to demonstrate TypeReconstructable.jl's sophisticated capabilities.
"""
function main()
    println("TypeReconstructable.jl Advanced Features Examples")
    println("====================================")
    println()
    
    example_scope_analysis()
    example_custom_reconstructable()
    example_closure_generation()
    example_advanced_pattern_matching()
    example_code_generation_caching()
    example_runtime_function_generation()
    
    println("Advanced examples completed!")
end

# Run examples if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end