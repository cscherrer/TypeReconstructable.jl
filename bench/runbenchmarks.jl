#!/usr/bin/env julia
"""
Benchmark Suite for TypeReconstructable.jl

This implements best practices for Julia benchmarking and regression tracking
following the recommendations from BenchmarkTools.jl and RegressionTests.jl.

Usage:
    julia --project bench/runbenchmarks.jl
"""

using BenchmarkTools
using TypeReconstructable
using Serialization
using Dates

# Create the main benchmark suite
const SUITE = BenchmarkGroup()

# =============================================================================
# Type-Level Encoding Benchmarks
# =============================================================================

SUITE["typelevel"] = BenchmarkGroup()

# Use proper interpolation to avoid global variable access
let
    small_data = [1, 2, 3, 4, 5]
    medium_data = rand(Int, 100)
    large_data = rand(Float64, 1000)
    
    SUITE["typelevel"]["encode_small"] = @benchmarkable to_type($small_data)
    SUITE["typelevel"]["encode_medium"] = @benchmarkable to_type($medium_data)
    SUITE["typelevel"]["encode_large"] = @benchmarkable to_type($large_data)
    
    # Pre-compute types for decoding benchmarks
    small_T = to_type(small_data)
    medium_T = to_type(medium_data)
    large_T = to_type(large_data)
    
    SUITE["typelevel"]["decode_small"] = @benchmarkable from_type($small_T)
    SUITE["typelevel"]["decode_medium"] = @benchmarkable from_type($medium_T)
    SUITE["typelevel"]["decode_large"] = @benchmarkable from_type($large_T)
end

# =============================================================================
# Reconstructable Types Benchmarks
# =============================================================================

SUITE["reconstructable"] = BenchmarkGroup()

let
    # Test data
    small_data = [1, 2, 3, 4, 5]
    medium_data = rand(Int, 100)
    large_data = rand(Float64, 1000)
    
    # Creation benchmarks
    SUITE["reconstructable"]["create_small"] = @benchmarkable ReconstructableValue($small_data)
    SUITE["reconstructable"]["create_medium"] = @benchmarkable ReconstructableValue($medium_data)
    SUITE["reconstructable"]["create_large"] = @benchmarkable ReconstructableValue($large_data)
    
    # Pre-create reconstructable values for reconstruction benchmarks
    small_rv = ReconstructableValue(small_data)
    medium_rv = ReconstructableValue(medium_data)
    large_rv = ReconstructableValue(large_data)
    
    SUITE["reconstructable"]["reconstruct_small"] = @benchmarkable reconstruct($(typeof(small_rv)))
    SUITE["reconstructable"]["reconstruct_medium"] = @benchmarkable reconstruct($(typeof(medium_rv)))
    SUITE["reconstructable"]["reconstruct_large"] = @benchmarkable reconstruct($(typeof(large_rv)))
    
    # Type checking benchmarks
    SUITE["reconstructable"]["is_reconstructable"] = @benchmarkable is_reconstructable($(typeof(small_rv)))
    SUITE["reconstructable"]["can_reconstruct"] = @benchmarkable can_reconstruct($small_data)
end

# =============================================================================
# Generated Functions Benchmarks
# =============================================================================

SUITE["generated"] = BenchmarkGroup()

# Create a test generated function
@generated function benchmark_generated_func(rv::ReconstructableValue{T}) where T
    val = from_type(T)
    if val isa Vector{Int}
        return quote
            sum($(val)) + length($(val))
        end
    else
        return quote
            $(val)
        end
    end
end

let
    int_rv = ReconstructableValue([1, 2, 3, 4, 5])
    float_rv = ReconstructableValue([1.0, 2.0, 3.0])
    
    SUITE["generated"]["int_vector"] = @benchmarkable benchmark_generated_func($int_rv)
    SUITE["generated"]["float_vector"] = @benchmarkable benchmark_generated_func($float_rv)
end

# =============================================================================
# Performance Comparison Benchmarks
# =============================================================================

SUITE["comparison"] = BenchmarkGroup()

# Runtime approach
function runtime_process(data)
    if data isa Vector{Int}
        return sum(data) + length(data)
    else
        return data
    end
end

# Compile-time approach
@generated function compiletime_process(rv::ReconstructableValue{T}) where T
    val = from_type(T)
    if val isa Vector{Int}
        return quote
            sum($(val)) + length($(val))
        end
    else
        return quote
            $(val)
        end
    end
end

let
    test_data = [1, 2, 3, 4, 5]
    test_rv = ReconstructableValue(test_data)
    
    SUITE["comparison"]["runtime"] = @benchmarkable runtime_process($test_data)
    SUITE["comparison"]["compiletime"] = @benchmarkable compiletime_process($test_rv)
end

# =============================================================================
# Pattern Matching Benchmarks
# =============================================================================

SUITE["patterns"] = BenchmarkGroup()

let
    rv = ReconstructableValue([1, 2, 3, 4, 5])
    
    SUITE["patterns"]["decompose"] = @benchmarkable decompose_reconstructable($rv)
end

# =============================================================================
# Caching Benchmarks
# =============================================================================

SUITE["caching"] = BenchmarkGroup()

let
    test_code = :(x + y)
    
    # Setup and teardown for cache operations
    SUITE["caching"]["store"] = @benchmarkable cache_generated_code("test_key", $test_code) setup=(clear_codegen_cache!())
    SUITE["caching"]["retrieve"] = @benchmarkable get_cached_code("test_key") setup=(cache_generated_code("test_key", $test_code))
    SUITE["caching"]["clear"] = @benchmarkable clear_codegen_cache!() setup=(cache_generated_code("test_key", $test_code))
end

# =============================================================================
# Benchmark Execution and Results
# =============================================================================

function run_benchmarks()
    println("Running TypeReconstructable.jl Benchmark Suite")
    println("=" ^ 50)
    
    # Tune the benchmark suite
    println("Tuning benchmark suite...")
    tune!(SUITE)
    
    # Run the benchmarks
    println("Running benchmarks...")
    results = run(SUITE, verbose=true)
    
    # Save results for regression tracking
    results_dir = joinpath(@__DIR__, "results")
    mkpath(results_dir)
    
    # Save with timestamp
    timestamp = string(now())
    results_file = joinpath(results_dir, "benchmark_results_$(timestamp).jls")
    serialize(results_file, results)
    
    # Also save as latest for comparison
    latest_file = joinpath(results_dir, "benchmark_results_latest.jls")
    serialize(latest_file, results)
    
    println("\nResults saved to: $results_file")
    println("Latest results: $latest_file")
    
    return results
end

function load_latest_results()
    latest_file = joinpath(@__DIR__, "results", "benchmark_results_latest.jls")
    if isfile(latest_file)
        return deserialize(latest_file)
    else
        @warn "No previous results found"
        return nothing
    end
end

function compare_results(current_results, previous_results=nothing)
    if previous_results === nothing
        previous_results = load_latest_results()
    end
    
    if previous_results === nothing
        println("No previous results to compare against")
        return
    end
    
    println("\nPerformance Comparison")
    println("=" ^ 30)
    
    # Compare key benchmarks
    key_benchmarks = [
        ("typelevel", "encode_small"),
        ("typelevel", "decode_small"),
        ("reconstructable", "reconstruct_small"),
        ("generated", "int_vector"),
        ("comparison", "runtime"),
        ("comparison", "compiletime")
    ]
    
    for (group, bench) in key_benchmarks
        if haskey(current_results, group) && haskey(current_results[group], bench) &&
           haskey(previous_results, group) && haskey(previous_results[group], bench)
            
            current_time = minimum(current_results[group][bench]).time
            previous_time = minimum(previous_results[group][bench]).time
            
            ratio = current_time / previous_time
            change = (ratio - 1) * 100
            
            status = if ratio > 1.1
                "🔴 REGRESSION"
            elseif ratio < 0.9
                "🟢 IMPROVEMENT"
            else
                "✅ STABLE"
            end
            
            println("$group.$bench: $(BenchmarkTools.prettytime(current_time)) vs $(BenchmarkTools.prettytime(previous_time)) ($(change > 0 ? "+" : "")$(round(change, digits=1))%) $status")
        end
    end
end

function show_summary(results)
    println("\nBenchmark Summary")
    println("=" ^ 20)
    
    # Show key metrics
    key_benchmarks = [
        ("typelevel", "encode_small", "Type encoding (small)"),
        ("typelevel", "decode_small", "Type decoding (small)"),
        ("reconstructable", "reconstruct_small", "Reconstruction"),
        ("generated", "int_vector", "Generated function"),
        ("comparison", "runtime", "Runtime approach"),
        ("comparison", "compiletime", "Compile-time approach")
    ]
    
    for (group, bench, description) in key_benchmarks
        if haskey(results, group) && haskey(results[group], bench)
            result = results[group][bench]
            median_time = BenchmarkTools.median(result).time
            allocs = BenchmarkTools.median(result).allocs
            
            println("$description: $(BenchmarkTools.prettytime(median_time)) ($allocs allocations)")
        end
    end
    
    # Performance assertions
    println("\nPerformance Assertions")
    println("-" ^ 20)
    
    # Check that generated functions are fast
    if haskey(results, "generated") && haskey(results["generated"], "int_vector")
        gen_time = BenchmarkTools.median(results["generated"]["int_vector"]).time
        if gen_time < 10_000  # Less than 10μs
            println("✅ Generated functions are fast: $(BenchmarkTools.prettytime(gen_time))")
        else
            println("⚠️  Generated functions are slow: $(BenchmarkTools.prettytime(gen_time))")
        end
    end
    
    # Check that reconstruction is reasonable
    if haskey(results, "reconstructable") && haskey(results["reconstructable"], "reconstruct_small")
        recon_time = BenchmarkTools.median(results["reconstructable"]["reconstruct_small"]).time
        if recon_time < 1_000_000  # Less than 1ms
            println("✅ Reconstruction is fast: $(BenchmarkTools.prettytime(recon_time))")
        else
            println("⚠️  Reconstruction is slow: $(BenchmarkTools.prettytime(recon_time))")
        end
    end
    
    # Check compile-time vs runtime performance
    if haskey(results, "comparison") && haskey(results["comparison"], "runtime") && haskey(results["comparison"], "compiletime")
        runtime_time = BenchmarkTools.median(results["comparison"]["runtime"]).time
        compiletime_time = BenchmarkTools.median(results["comparison"]["compiletime"]).time
        
        if compiletime_time <= runtime_time * 2  # At most 2x slower
            println("✅ Compile-time approach is competitive: $(BenchmarkTools.prettytime(compiletime_time)) vs $(BenchmarkTools.prettytime(runtime_time))")
        else
            println("⚠️  Compile-time approach is slow: $(BenchmarkTools.prettytime(compiletime_time)) vs $(BenchmarkTools.prettytime(runtime_time))")
        end
    end
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    results = run_benchmarks()
    show_summary(results)
    compare_results(results)
end