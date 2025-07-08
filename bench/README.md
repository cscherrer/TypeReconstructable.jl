# Performance Benchmarking and Regression Testing

This directory contains TypeReconstructable.jl's performance benchmarking and regression testing infrastructure.

## 🎯 **Goals**

1. **Track performance regressions** across development cycles
2. **Ensure zero runtime overhead** promise is maintained
3. **Handle cross-machine performance differences** with machine-specific baselines
4. **Provide detailed performance metrics** for optimization

## 📁 **Files**

- `runbenchmarks.jl` - Main benchmark suite using BenchmarkTools.jl
- `regression_test.jl` - Regression detection system with machine fingerprinting
- `machine_fingerprint.jl` - Machine-specific baseline system
- `results/` - Benchmark results and baselines storage

## 🚀 **Usage**

### Basic Benchmarking

```bash
# Run comprehensive benchmark suite
julia --project bench/runbenchmarks.jl

# Creates timestamped results and shows performance summary
```

### Regression Testing

```bash
# Create machine-specific baseline (run once per machine)
julia --project bench/regression_test.jl baseline

# Run regression test against baseline
julia --project bench/regression_test.jl

# Show machine information and fingerprint
julia --project bench/regression_test.jl machine
```

### CI/CD Integration

```bash
# In CI pipeline:
julia --project bench/regression_test.jl

# Exit codes:
# 0 = No regressions detected
# 1 = Performance regressions found
```

## 🔧 **Machine-Specific Baselines**

The system addresses cross-machine performance differences by:

### 1. **Machine Fingerprinting**
Creates unique fingerprints based on:
- CPU model and features (AVX, SSE, etc.)
- Core count and memory
- OS and architecture
- Julia version

### 2. **Automatic Baseline Management**
- **First run**: Creates machine-specific baseline automatically
- **Subsequent runs**: Compares against machine-specific baseline
- **Fallback**: Uses generic baseline if machine-specific not found

### 3. **Baseline File Naming**
```
benchmark_baseline_6a77d27e1a1a6b04.jls  # Machine-specific
benchmark_baseline.jls                   # Generic fallback
```

## 📊 **Performance Metrics**

### **Key Benchmarks Tracked**

| Category | Benchmark | Target | Description |
|----------|-----------|--------|-------------|
| **Type-level** | `encode_small` | <1μs | Type encoding performance |
| **Type-level** | `decode_small` | <500ns | Type decoding performance |
| **Reconstructable** | `reconstruct_small` | <500ns | Value reconstruction |
| **Generated** | `int_vector` | <10ns | Generated function overhead |
| **Comparison** | `compiletime` vs `runtime` | ≤2x | Zero overhead verification |

### **Performance Assertions**

1. **Generated functions** must be <10μs (zero overhead)
2. **Reconstruction** must be <1ms (reasonable compile-time cost)
3. **Compile-time approach** must be ≤2x runtime approach

## 🏗️ **Architecture**

### **Cross-Machine Compatibility**

The system handles performance differences across machines through:

#### **1. Hardware Fingerprinting**
```julia
# Machine characteristics that affect performance
- CPU model and features
- Memory configuration  
- Architecture (x86_64, ARM, etc.)
- OS kernel and version
```

#### **2. Baseline Strategy**
```
Machine A: baseline_6a77d27e1a1a6b04.jls (AMD Ryzen 9950X)
Machine B: baseline_8b23f45c2e3d7a91.jls (Intel Core i7)
Machine C: baseline_9c34g56d3f4e8b02.jls (Apple M2)
```

#### **3. Regression Detection**
- **10% threshold** for significance (configurable)
- **Median-based comparison** for statistical robustness
- **Machine-specific baselines** eliminate cross-machine noise

### **Statistical Methodology**

- **Robust statistics**: Uses median times instead of minimums
- **Significance testing**: 10% threshold for meaningful changes
- **Multiple samples**: BenchmarkTools.jl automatic sampling
- **Noise tolerance**: Machine-specific baselines reduce false positives

## 🔄 **CI/CD Integration**

### **GitHub Actions Example**

```yaml
name: Performance Regression Test
on: [push, pull_request]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: julia-actions/setup-julia@v1
        with:
          version: '1.11'
      
      - name: Install dependencies
        run: julia --project -e 'using Pkg; Pkg.instantiate()'
      
      - name: Run regression test
        run: julia --project bench/regression_test.jl
```

### **Baseline Management in CI**

1. **Cache baselines** per runner type (ubuntu-latest, macos-latest, etc.)
2. **Store baselines** in repository or external storage
3. **Regenerate baselines** when hardware changes
4. **Alert on regressions** with detailed reports

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **"No baseline found"**
```bash
# Create baseline for this machine
julia --project bench/regression_test.jl baseline
```

#### **"Using generic baseline" warning**
```bash
# Machine-specific baseline not found, using fallback
# Consider creating machine-specific baseline for accuracy
```

#### **High performance variability**
```bash
# Check machine fingerprint
julia --project bench/regression_test.jl machine

# Ensure consistent environment (no background tasks)
# Consider adjusting regression threshold
```

### **Performance Debugging**

```bash
# Show detailed benchmark results
julia --project bench/runbenchmarks.jl

# Compare specific benchmarks
julia --project -e "include(\"bench/runbenchmarks.jl\"); results = run_benchmarks()"
```

## 📈 **Best Practices**

1. **Create baselines** on each target machine/environment
2. **Run tests** in consistent environments (no background load)
3. **Monitor trends** over time, not just absolute values
4. **Update baselines** when making intentional performance changes
5. **Use machine fingerprints** to identify environment changes

## 🎯 **Future Enhancements**

- **Historical trending** with performance databases
- **Multiple baseline comparison** for performance characterization
- **Automated baseline updates** based on performance improvements
- **Performance profiling** integration for regression root cause analysis