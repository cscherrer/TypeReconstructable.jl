#!/usr/bin/env julia
"""
Regression Test for TypeReconstructable.jl

This implements a simple regression detection system for performance monitoring
in CI/CD environments. It compares current benchmarks against a baseline.

Usage:
    julia --project bench/regression_test.jl [baseline_file]
"""

using BenchmarkTools
using TypeReconstructable
using Serialization
using Statistics

# Include the main benchmark suite and machine fingerprinting
include("runbenchmarks.jl")
include("machine_fingerprint.jl")

struct RegressionResult
    benchmark::String
    current_time::Float64
    baseline_time::Float64
    ratio::Float64
    change_percent::Float64
    status::Symbol  # :improvement, :regression, :stable
    is_significant::Bool
end

function detect_regression(current_results, baseline_results; threshold=0.1)
    """
    Detect performance regressions by comparing current results to baseline.
    
    Args:
        current_results: Current benchmark results
        baseline_results: Baseline benchmark results
        threshold: Minimum change percentage to consider significant (default 10%)
    
    Returns:
        Vector of RegressionResult objects
    """
    
    results = RegressionResult[]
    
    # Key benchmarks to monitor for regressions
    key_benchmarks = [
        ("typelevel", "encode_small"),
        ("typelevel", "decode_small"),
        ("typelevel", "encode_medium"),
        ("typelevel", "decode_medium"),
        ("reconstructable", "reconstruct_small"),
        ("reconstructable", "reconstruct_medium"),
        ("generated", "int_vector"),
        ("comparison", "runtime"),
        ("comparison", "compiletime"),
        ("patterns", "decompose"),
        ("caching", "store"),
        ("caching", "retrieve")
    ]
    
    for (group, bench) in key_benchmarks
        benchmark_name = "$group.$bench"
        
        # Check if benchmark exists in both results
        if haskey(current_results, group) && haskey(current_results[group], bench) &&
           haskey(baseline_results, group) && haskey(baseline_results[group], bench)
            
            # Get median times (more robust than minimum for regression detection)
            current_time = BenchmarkTools.median(current_results[group][bench]).time
            baseline_time = BenchmarkTools.median(baseline_results[group][bench]).time
            
            # Calculate ratio and percentage change
            ratio = current_time / baseline_time
            change_percent = (ratio - 1) * 100
            
            # Determine status
            is_significant = abs(change_percent) > threshold * 100
            
            status = if ratio > (1 + threshold) && is_significant
                :regression
            elseif ratio < (1 - threshold) && is_significant
                :improvement
            else
                :stable
            end
            
            push!(results, RegressionResult(
                benchmark_name,
                current_time,
                baseline_time,
                ratio,
                change_percent,
                status,
                is_significant
            ))
        end
    end
    
    return results
end

function run_regression_test(baseline_file=nothing)
    """
    Run regression test comparing current performance to baseline.
    Uses machine-specific baselines to handle performance differences across machines.
    """
    
    println("TypeReconstructable.jl Regression Test")
    println("=" ^ 40)
    
    # Get machine fingerprint
    fingerprint = create_machine_fingerprint()
    println("\nMachine Information:")
    show_machine_info(fingerprint)
    println()
    
    # Run current benchmarks
    println("Running current benchmarks...")
    current_results = run_benchmarks()
    
    # Determine baseline file
    if baseline_file !== nothing && isfile(baseline_file)
        println("Loading baseline from: $baseline_file")
        baseline_results = deserialize(baseline_file)
    else
        # Use machine-specific baseline
        baseline_dir = joinpath(@__DIR__, "results")
        mkpath(baseline_dir)
        machine_baseline = joinpath(baseline_dir, get_baseline_filename(fingerprint))
        
        if isfile(machine_baseline)
            println("Loading machine-specific baseline from: $machine_baseline")
            baseline_results = deserialize(machine_baseline)
        else
            println("No machine-specific baseline found.")
            
            # Try to load generic baseline as fallback
            generic_baseline = joinpath(baseline_dir, "benchmark_baseline.jls")
            if isfile(generic_baseline)
                println("Loading generic baseline from: $generic_baseline")
                baseline_results = deserialize(generic_baseline)
                println("⚠️  Warning: Using generic baseline. Results may not be accurate for this machine.")
                println("   Consider creating a machine-specific baseline with: julia bench/regression_test.jl baseline")
            else
                println("No baseline found. Creating machine-specific baseline...")
                serialize(machine_baseline, current_results)
                println("Machine-specific baseline saved to: $machine_baseline")
                println("Run this test again to detect regressions.")
                return
            end
        end
    end
    
    # Detect regressions
    println("\nAnalyzing performance changes...")
    regression_results = detect_regression(current_results, baseline_results)
    
    # Report results
    println("\nRegression Analysis Results")
    println("=" ^ 30)
    
    # Count results by status
    regressions = filter(r -> r.status == :regression, regression_results)
    improvements = filter(r -> r.status == :improvement, regression_results)
    stable = filter(r -> r.status == :stable, regression_results)
    
    println("Total benchmarks: $(length(regression_results))")
    println("Regressions: $(length(regressions))")
    println("Improvements: $(length(improvements))")
    println("Stable: $(length(stable))")
    
    # Show detailed results
    if !isempty(regressions)
        println("\n🔴 PERFORMANCE REGRESSIONS:")
        for result in regressions
            println("  $(result.benchmark): $(BenchmarkTools.prettytime(result.current_time)) vs $(BenchmarkTools.prettytime(result.baseline_time)) ($(result.change_percent > 0 ? "+" : "")$(round(result.change_percent, digits=1))%)")
        end
    end
    
    if !isempty(improvements)
        println("\n🟢 PERFORMANCE IMPROVEMENTS:")
        for result in improvements
            println("  $(result.benchmark): $(BenchmarkTools.prettytime(result.current_time)) vs $(BenchmarkTools.prettytime(result.baseline_time)) ($(result.change_percent > 0 ? "+" : "")$(round(result.change_percent, digits=1))%)")
        end
    end
    
    if !isempty(stable)
        println("\n✅ STABLE PERFORMANCE:")
        for result in stable
            println("  $(result.benchmark): $(BenchmarkTools.prettytime(result.current_time)) vs $(BenchmarkTools.prettytime(result.baseline_time)) ($(result.change_percent > 0 ? "+" : "")$(round(result.change_percent, digits=1))%)")
        end
    end
    
    # Summary and exit code
    println("\n" * "=" ^ 40)
    if !isempty(regressions)
        println("❌ REGRESSION TEST FAILED: $(length(regressions)) performance regressions detected")
        exit(1)  # Exit with error code for CI
    else
        println("✅ REGRESSION TEST PASSED: No performance regressions detected")
        if !isempty(improvements)
            println("🎉 Bonus: $(length(improvements)) performance improvements detected!")
        end
        exit(0)  # Exit with success code
    end
end

function create_baseline(output_file=nothing)
    """
    Create a new baseline by running benchmarks and saving results.
    Creates machine-specific baseline by default.
    """
    
    # Get machine fingerprint
    fingerprint = create_machine_fingerprint()
    println("Creating baseline for machine:")
    show_machine_info(fingerprint)
    println()
    
    if output_file === nothing
        # Create machine-specific baseline
        baseline_dir = joinpath(@__DIR__, "results")
        mkpath(baseline_dir)
        output_file = joinpath(baseline_dir, get_baseline_filename(fingerprint))
    end
    
    println("Creating new baseline...")
    results = run_benchmarks()
    
    # Ensure directory exists
    mkpath(dirname(output_file))
    
    # Save baseline
    serialize(output_file, results)
    println("Machine-specific baseline saved to: $output_file")
    
    return results
end

# Command line interface
function main()
    args = ARGS
    
    if length(args) == 0
        # Run regression test with default baseline
        run_regression_test()
    elseif args[1] == "baseline"
        # Create new baseline
        if length(args) >= 2
            create_baseline(args[2])
        else
            create_baseline()
        end
    elseif args[1] == "machine"
        # Show machine information
        fingerprint = create_machine_fingerprint()
        println("Machine Fingerprint Information:")
        println("=" ^ 40)
        show_machine_info(fingerprint)
        println("\nMachine-specific baseline file: $(get_baseline_filename(fingerprint))")
    elseif args[1] == "help"
        println("Usage:")
        println("  julia bench/regression_test.jl                    # Run regression test")
        println("  julia bench/regression_test.jl baseline [file]    # Create new baseline")
        println("  julia bench/regression_test.jl machine            # Show machine information")
        println("  julia bench/regression_test.jl [baseline_file]    # Compare against specific baseline")
        println("  julia bench/regression_test.jl help               # Show this help")
    else
        # Run regression test with specified baseline
        run_regression_test(args[1])
    end
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end