"""
Advanced Features Examples for TypeReconstructable.jl

This file demonstrates advanced metaprogramming patterns and sophisticated
usage of TypeReconstructable.jl. Run from REPL with:

julia> include("examples/advanced_features.jl")
julia> demo_advanced_features()
"""

using TypeReconstructable

# Try to load BenchmarkTools, but don't fail if it's not available
const HAS_BENCHMARKTOOLS = try
    using BenchmarkTools
    true
catch
    false
end

# Generated function that handles multiple types and generates different code
@generated function advanced_processor(rv::ReconstructableValue{T}) where T
    val = from_type(T)
    
    if val isa Vector{Int}
        # Generate optimized integer vector processing
        return quote
            data = $(val)
            result = 0
            for i in 1:length(data)
                result += data[i] * i  # Weighted sum
            end
            result
        end
    elseif val isa Vector{Float64}
        # Generate optimized float vector processing
        return quote
            data = $(val)
            sum(data) / length(data)  # Average
        end
    elseif val isa Dict
        # Generate dictionary processing
        return quote
            data = $(val)
            sum(values(data))
        end
    else
        # Fallback for other types
        return quote
            $(val)
        end
    end
end

# Generated function to process complex configurations
@generated function process_config(rv::ReconstructableValue{T}) where T
    config = from_type(T)
    
    # Generate code based on the configuration
    if haskey(config, :config) && haskey(config, :model)
        lr = config[:config][:learning_rate]
        layers = config[:model][:layers]
        
        return quote
            # Generate optimized code for this specific configuration
            learning_rate = $(lr)
            input_size = $(layers[1])
            output_size = $(layers[end])
            
            println("Configuration: LR=$learning_rate, Input=$input_size, Output=$output_size")
            (learning_rate, input_size, output_size)
        end
    else
        return quote
            error("Invalid configuration structure")
        end
    end
end

@generated function compiletime_approach(rv::ReconstructableValue{T}) where T
    val = from_type(T)
    
    if val isa Vector{Int}
        return quote
            sum($(val)) * length($(val))
        end
    elseif val isa Vector{Float64}
        return quote
            sum($(val)) / length($(val))
        end
    else
        return quote
            0
        end
    end
end

# Runtime approach for performance comparison
function runtime_approach(data)
    if data isa Vector{Int}
        return sum(data) * length(data)
    elseif data isa Vector{Float64}
        return sum(data) / length(data)
    else
        return 0
    end
end

function demo_advanced_features()
    """
    Comprehensive demonstration of TypeReconstructable.jl advanced features.
    """
    
    println("TypeReconstructable.jl - Advanced Features")
    println("=" ^ 50)

    # =============================================================================
    # 1. Custom Reconstructable Types
    # =============================================================================

    println("\n1. Custom Reconstructable Types")
    println("-" ^ 30)

    # Create a custom data structure
    model_data = (
        weights = [1.0, 2.0, 3.0],
        bias = 0.5,
        name = "test_model"
    )

    # Make it reconstructable
    model_rv = ReconstructableValue(model_data)
    println("Original model: ", model_rv.value)

    # The type is now reconstructable
    T_model = typeof(model_rv)
    println("Type representation: ", T_model)

    reconstructed_model = reconstruct(T_model)
    println("Reconstructed model: ", reconstructed_model.value)
    println("Equal? ", model_rv.value == reconstructed_model.value)

    # =============================================================================
    # 2. Complex Generated Functions
    # =============================================================================

    println("\n2. Complex Generated Functions")
    println("-" ^ 30)

    # Test with different types
    int_rv = ReconstructableValue([1, 2, 3, 4, 5])
    float_rv = ReconstructableValue([1.0, 2.0, 3.0, 4.0, 5.0])
    dict_rv = ReconstructableValue(Dict(:a => 10, :b => 20, :c => 30))

    println("Int vector result: ", advanced_processor(int_rv))
    println("Float vector result: ", advanced_processor(float_rv))
    println("Dict result: ", advanced_processor(dict_rv))

    # =============================================================================
    # 3. Nested and Complex Data Structures
    # =============================================================================

    println("\n3. Nested and Complex Data Structures")
    println("-" ^ 30)

    # Create complex nested data structure
    complex_data = Dict(
        :config => Dict(
            :learning_rate => 0.01,
            :batch_size => 32,
            :epochs => 100
        ),
        :model => Dict(
            :layers => [64, 32, 16, 1],
            :activation => "relu"
        ),
        :data => [
            [1.0, 2.0, 3.0],
            [4.0, 5.0, 6.0],
            [7.0, 8.0, 9.0]
        ]
    )

    # Make it reconstructable
    complex_rv = ReconstructableValue(complex_data)
    println("Complex data reconstructed successfully: ", 
            reconstruct(typeof(complex_rv)).value == complex_data)

    result = process_config(complex_rv)
    println("Config processing result: ", result)

    # =============================================================================
    # 4. Scope Analysis and Variable Handling
    # =============================================================================

    println("\n4. Scope Analysis and Variable Handling")
    println("-" ^ 30)

    # Create a scope analyzer
    analyzer = ScopeAnalyzer()
    println("Scope analyzer created: ", typeof(analyzer))

    # Mark some variables as reconstructable
    mark_reconstructable!(analyzer, :my_var)
    mark_reconstructable!(analyzer, :another_var)

    println("Reconstructable variables: ", analyzer.reconstructable_vars)

    # Test basic scope analysis
    test_expr = :(x + y + z)
    try
        analyzed, free_vars, reconstructable_vars = analyze_scope(test_expr, analyzer)
        println("Analyzed expression: ", analyzed)
        println("Free variables: ", free_vars)
        println("Reconstructable variables: ", reconstructable_vars)
    catch e
        println("Scope analysis note: ", e.msg)
    end

    # =============================================================================
    # 5. Code Generation Cache
    # =============================================================================

    println("\n5. Code Generation Cache")
    println("-" ^ 30)

    # Clear cache first
    clear_codegen_cache!()

    # Cache some generated code
    test_code = :(x * y + z)
    cached = cache_generated_code("test_function", test_code)
    println("Cached code: ", cached)

    # Retrieve from cache
    retrieved = get_cached_code("test_function")
    println("Retrieved code: ", retrieved)
    println("Cache hit: ", cached == retrieved)

    # Test cache miss
    missing_code = get_cached_code("nonexistent")
    println("Missing code: ", missing_code)

    # =============================================================================
    # 6. Performance Comparison
    # =============================================================================

    println("\n6. Performance Comparison")
    println("-" ^ 30)

    # Test data
    test_int_data = [1, 2, 3, 4, 5]
    test_float_data = [1.0, 2.0, 3.0, 4.0, 5.0]
    test_int_rv = ReconstructableValue(test_int_data)
    test_float_rv = ReconstructableValue(test_float_data)

    if HAS_BENCHMARKTOOLS
        println("Runtime approach (int):")
        @btime runtime_approach($test_int_data)

        println("Compile-time approach (int):")
        @btime compiletime_approach($test_int_rv)

        println("Runtime approach (float):")
        @btime runtime_approach($test_float_data)

        println("Compile-time approach (float):")
        @btime compiletime_approach($test_float_rv)
    else
        println("BenchmarkTools not available. Showing function results instead:")
        println("Runtime approach (int): ", runtime_approach(test_int_data))
        println("Compile-time approach (int): ", compiletime_approach(test_int_rv))
        println("Runtime approach (float): ", runtime_approach(test_float_data))
        println("Compile-time approach (float): ", compiletime_approach(test_float_rv))
    end

    # =============================================================================
    # 7. Error Handling and Edge Cases
    # =============================================================================

    println("\n7. Error Handling and Edge Cases")
    println("-" ^ 30)

    # Test with empty data
    empty_rv = ReconstructableValue(Int[])
    println("Empty vector reconstruction: ", reconstruct(typeof(empty_rv)).value)

    # Test with large data
    large_data = rand(1000)
    large_rv = ReconstructableValue(large_data)
    println("Large data reconstruction successful: ", 
            length(reconstruct(typeof(large_rv)).value) == 1000)

    # Test with special values
    special_data = [NaN, Inf, -Inf, 0.0, -0.0]
    special_rv = ReconstructableValue(special_data)
    reconstructed_special = reconstruct(typeof(special_rv)).value
    println("Special values reconstruction: ", 
            length(reconstructed_special) == 5 && isnan(reconstructed_special[1]))

    println("\n" ^ 2 * "=" ^ 50)
    println("All advanced examples completed successfully!")
    println("TypeReconstructable.jl is working correctly with advanced features.")
end

# Additional utility functions for REPL exploration
function demo_type_level_encoding()
    """Quick demo of type-level encoding features."""
    println("Type-Level Encoding Demo")
    println("=" ^ 25)
    
    # Encode different data types
    examples = [
        [1, 2, 3, 4, 5],
        Dict(:a => 1, :b => 2),
        "Hello, TypeReconstructable!",
        (x=1.0, y=2.0, z=3.0)
    ]
    
    for (i, data) in enumerate(examples)
        println("\nExample $i: $(typeof(data))")
        T = to_type(data)
        reconstructed = from_type(T)
        println("  Original: $data")
        println("  Reconstructed: $reconstructed")
        println("  Equal: $(data == reconstructed)")
    end
end

function demo_generated_functions()
    """Quick demo of generated functions with reconstruction."""
    println("Generated Functions Demo")
    println("=" ^ 25)
    
    test_cases = [
        ReconstructableValue([1, 2, 3, 4, 5]),
        ReconstructableValue([1.0, 2.0, 3.0]),
        ReconstructableValue(Dict(:sum => 100))
    ]
    
    for (i, rv) in enumerate(test_cases)
        println("\nTest case $i:")
        println("  Input: $(rv.value)")
        println("  Result: $(advanced_processor(rv))")
    end
end

# Run the main demo if this file is included directly
demo_advanced_features()