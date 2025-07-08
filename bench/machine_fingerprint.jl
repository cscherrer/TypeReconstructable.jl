#!/usr/bin/env julia
"""
Machine Fingerprinting for Performance Baselines

This module creates unique fingerprints for machines to enable
machine-specific performance baselines and regression detection.
"""

using Pkg
using SHA

struct MachineFingerprint
    hash::String
    cpu_model::String
    cpu_cores::Int
    memory_gb::Float64
    julia_version::String
    os_info::String
    architecture::String
    cpu_features::Vector{String}
end

function get_cpu_info()
    """Get CPU information from /proc/cpuinfo or system commands"""
    cpu_model = "Unknown"
    cpu_cores = Sys.CPU_THREADS
    
    try
        if Sys.islinux()
            # Read from /proc/cpuinfo
            cpuinfo = read("/proc/cpuinfo", String)
            
            # Extract CPU model
            for line in split(cpuinfo, '\n')
                if startswith(line, "model name")
                    cpu_model = strip(split(line, ':')[2])
                    break
                end
            end
            
        elseif Sys.isapple()
            # Use system_profiler on macOS
            try
                result = read(`system_profiler SPHardwareDataType`, String)
                for line in split(result, '\n')
                    if contains(line, "Processor Name")
                        cpu_model = strip(split(line, ':')[2])
                        break
                    end
                end
            catch
                cpu_model = "Apple Silicon"
            end
            
        elseif Sys.iswindows()
            # Use wmic on Windows
            try
                result = read(`wmic cpu get name /value`, String)
                for line in split(result, '\n')
                    if startswith(line, "Name=")
                        cpu_model = strip(split(line, '=')[2])
                        break
                    end
                end
            catch
                cpu_model = "Windows CPU"
            end
        end
    catch
        # Fallback to basic info
        cpu_model = "Unknown CPU"
    end
    
    return cpu_model, cpu_cores
end

function get_memory_info()
    """Get total system memory in GB"""
    try
        if Sys.islinux()
            meminfo = read("/proc/meminfo", String)
            for line in split(meminfo, '\n')
                if startswith(line, "MemTotal:")
                    kb = parse(Int, split(line)[2])
                    return kb / 1024.0 / 1024.0  # Convert KB to GB
                end
            end
        elseif Sys.isapple()
            result = read(`sysctl hw.memsize`, String)
            bytes = parse(Int, split(result)[2])
            return bytes / 1024.0^3  # Convert bytes to GB
        elseif Sys.iswindows()
            result = read(`wmic computersystem get TotalPhysicalMemory /value`, String)
            for line in split(result, '\n')
                if startswith(line, "TotalPhysicalMemory=")
                    bytes = parse(Int, split(line, '=')[2])
                    return bytes / 1024.0^3  # Convert bytes to GB
                end
            end
        end
    catch
        # Fallback
        return 0.0
    end
    
    return 0.0
end

function get_cpu_features()
    """Get CPU features that affect performance"""
    features = String[]
    
    try
        if Sys.islinux()
            cpuinfo = read("/proc/cpuinfo", String)
            for line in split(cpuinfo, '\n')
                if startswith(line, "flags")
                    flags = split(strip(split(line, ':')[2]))
                    # Only keep performance-relevant flags
                    perf_flags = filter(f -> f in ["avx", "avx2", "avx512f", "sse4_1", "sse4_2", "fma", "bmi1", "bmi2"], flags)
                    append!(features, perf_flags)
                    break
                end
            end
        end
    catch
        # Fallback - no features detected
    end
    
    return sort(unique(features))
end

function create_machine_fingerprint()
    """Create a unique fingerprint for this machine"""
    
    # Collect machine information
    cpu_model, cpu_cores = get_cpu_info()
    memory_gb = get_memory_info()
    julia_version = string(VERSION)
    os_info = string(Sys.KERNEL, " ", Sys.ARCH)
    architecture = string(Sys.ARCH)
    cpu_features = get_cpu_features()
    
    # Create a hash of the key performance characteristics
    hash_input = join([
        cpu_model,
        string(cpu_cores),
        string(round(memory_gb, digits=1)),
        julia_version,
        os_info,
        architecture,
        join(cpu_features, ",")
    ], "|")
    
    machine_hash = bytes2hex(sha256(hash_input))
    
    return MachineFingerprint(
        machine_hash,
        cpu_model,
        cpu_cores,
        memory_gb,
        julia_version,
        os_info,
        architecture,
        cpu_features
    )
end

function get_baseline_filename(fingerprint::MachineFingerprint)
    """Get the baseline filename for this machine"""
    return "benchmark_baseline_$(fingerprint.hash[1:16]).jls"
end

function show_machine_info(fingerprint::MachineFingerprint)
    """Display machine information for debugging"""
    println("Machine Fingerprint: $(fingerprint.hash[1:16])...")
    println("CPU Model: $(fingerprint.cpu_model)")
    println("CPU Cores: $(fingerprint.cpu_cores)")
    println("Memory: $(round(fingerprint.memory_gb, digits=1)) GB")
    println("Julia Version: $(fingerprint.julia_version)")
    println("OS: $(fingerprint.os_info)")
    println("Architecture: $(fingerprint.architecture)")
    println("CPU Features: $(join(fingerprint.cpu_features, ", "))")
end

# Export main functions
export MachineFingerprint, create_machine_fingerprint, get_baseline_filename, show_machine_info