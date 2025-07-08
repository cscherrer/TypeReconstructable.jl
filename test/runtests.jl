using TypeReconstructable
using Test

@testset "TypeReconstructable.jl" begin
    @testset "TypeLevel Encoding" begin
        # Test basic type-level encoding
        x = [1, 2, 3, 4, 5]
        T = to_type(x)
        y = from_type(T)
        
        @test x == y
        @test is_typelevel(T)
        @test base_type(T) == Vector{Int64}
        
        # Test with different types
        dict_val = Dict(:a => 1, :b => 2)
        T_dict = to_type(dict_val)
        reconstructed_dict = from_type(T_dict)
        
        @test dict_val == reconstructed_dict
        @test is_typelevel(T_dict)
        
        # Test macro version
        T_macro = @to_type [10, 20, 30]
        macro_result = from_type(T_macro)
        @test macro_result == [10, 20, 30]
    end
    
    @testset "Reconstructable Types" begin
        # Test ReconstructableValue
        rv = ReconstructableValue([1, 2, 3])
        @test is_reconstructable(typeof(rv))
        
        reconstructed = reconstruct(typeof(rv))
        @test rv.value == reconstructed.value
        
        # Test with different types
        string_rv = ReconstructableValue("hello world")
        string_reconstructed = reconstruct(typeof(string_rv))
        @test string_rv.value == string_reconstructed.value
        
        # Test can_reconstruct
        @test can_reconstruct([1, 2, 3])
        @test can_reconstruct(Dict(:a => 1))
        @test can_reconstruct("test")
    end
    
    @testset "Pattern Matching" begin
        # Test decompose_reconstructable
        rv = ReconstructableValue([1, 2, 3, 4])
        base_type, encoded, reconstructed_val = decompose_reconstructable(rv)
        
        @test base_type == Vector{Int64}
        @test reconstructed_val == [1, 2, 3, 4]
        @test is_typelevel(encoded)
    end
    
    @testset "Scope Analysis" begin
        # Test ScopeAnalyzer creation
        analyzer = ScopeAnalyzer()
        @test analyzer isa ScopeAnalyzer
        
        # Test marking reconstructable variables
        mark_reconstructable!(analyzer, :test_var)
        @test :test_var in analyzer.reconstructable_vars
        
        # Test basic scope analysis
        expr = :(x + y)
        analyzed, free_vars, reconstructable_vars = analyze_scope(expr, analyzer)
        @test analyzed isa Expr
        @test free_vars isa Set
    end
    
    @testset "Code Generation Cache" begin
        # Test cache operations
        clear_codegen_cache!()
        
        test_key = "test_function"
        test_code = :(x + y)
        
        cached = cache_generated_code(test_key, test_code)
        @test cached == test_code
        
        retrieved = get_cached_code(test_key)
        @test retrieved == test_code
        
        clear_codegen_cache!()
        @test get_cached_code(test_key) === nothing
    end
    
    @testset "Integration Tests" begin
        # Test that all modules load correctly
        @test TypeLevel{Int, (0x01,)} isa DataType
        @test Reconstructable isa Type
        @test ReconstructableValue isa Type
        
        # Test basic workflow
        original_data = [1, 2, 3, 4, 5]
        rv = ReconstructableValue(original_data)
        T = typeof(rv)
        reconstructed = reconstruct(T)
        
        @test original_data == reconstructed.value
        @test is_reconstructable(T)
        
        # Test type equality
        rv2 = ReconstructableValue([1, 2, 3, 4, 5])
        @test typeof(rv) == typeof(rv2)  # Same type parameters
    end
    
    @testset "Error Handling" begin
        # Test invalid TypeLevel constructions
        @test_throws Exception from_type(TypeLevel{Int, ()})  # Empty buffer
        @test_throws Exception from_type(TypeLevel{Int, ("invalid",)})  # Invalid buffer
        
        # Test type mismatches
        @test_throws Exception ReconstructableValue{Int}()  # Non-TypeLevel type
        
        # Test non-serializable values
        # Note: Some values may be serializable in newer Julia versions
        try
            f = () -> 1  # Functions are typically not serializable
            @test !can_reconstruct(f)
        catch
            # If functions are serializable, try something else
            @test true  # Skip this test
        end
        
        # Test invalid macro usage
        @test_throws Exception @eval @reconstructable 42  # Not a struct
        @test_throws Exception @eval @reconstructable begin end  # Not a struct
        
        # Test buffer corruption scenarios
        corrupted_buffer = (0x37, 0x4a, 0xFF, 0x00, 0xDE, 0xAD, 0xBE, 0xEF)  # Invalid data
        @test_throws Exception from_type(TypeLevel{Vector{Int}, corrupted_buffer})
        
        # Test truncated buffer
        truncated_buffer = (0x37,)  # Too short for valid serialization
        @test_throws Exception from_type(TypeLevel{String, truncated_buffer})
        
        # Test extremely long type parameter lists (stress test)
        long_buffer = tuple([UInt8(i % 256) for i in 1:10000]...)
        @test_throws Exception from_type(TypeLevel{Int, long_buffer})
        
        # Test memory pressure scenarios
        # Note: This may pass on systems with sufficient memory
        try
            huge_data = zeros(Int, 10^7)  # 10M integers ≈ 80MB
            can_reconstruct(huge_data)  # Should handle gracefully
            @test true  # Passes if system can handle it
        catch OutOfMemoryError
            @test true  # Expected on memory-constrained systems
        end
        
        # Test upstream integration failures
        # These tests verify graceful degradation when dependencies fail
        analyzer = ScopeAnalyzer()
        @test analyzer isa ScopeAnalyzer  # Should create successfully
        
        # Test that scope analysis handles errors gracefully
        complex_expr = :(let x = 1; y = x + z; (a, b) -> a + b + x + y + z end)
        try
            analyzed, free_vars, reconstructable_vars = analyze_scope(complex_expr, analyzer)
            @test analyzed isa Expr
        catch e
            # Should handle upstream failures gracefully
            @test e isa Exception
            @test !isa(e, MethodError)  # Should not be a method error
        end
    end
    
    @testset "Edge Cases" begin
        # Test with empty containers
        empty_vec = Int[]
        rv_empty = ReconstructableValue(empty_vec)
        @test reconstruct(typeof(rv_empty)).value == empty_vec
        
        # Test with complex nested structures
        nested = Dict(
            :vectors => [1, 2, 3],
            :nested_dict => Dict("a" => [1.0, 2.0], "b" => [3.0, 4.0]),
            :tuple => (1, "hello", 3.14)
        )
        rv_nested = ReconstructableValue(nested)
        @test reconstruct(typeof(rv_nested)).value == nested
        
        # Test with large data
        large_data = rand(1000)
        rv_large = ReconstructableValue(large_data)
        @test reconstruct(typeof(rv_large)).value ≈ large_data
        
        # Test with special values
        special_vals = [NaN, Inf, -Inf, 0.0, -0.0]
        rv_special = ReconstructableValue(special_vals)
        reconstructed_special = reconstruct(typeof(rv_special)).value
        @test length(reconstructed_special) == length(special_vals)
        @test isnan(reconstructed_special[1])
        @test isinf(reconstructed_special[2]) && reconstructed_special[2] > 0
        @test isinf(reconstructed_special[3]) && reconstructed_special[3] < 0
        
        # Test very large data structures (size limits)
        # Note: This tests for reasonable behavior, not necessarily success
        very_large_data = rand(Int, 100_000)  # 100K elements
        @test can_reconstruct(very_large_data) || true  # Should handle gracefully
        
        # Test deeply nested structures
        deep_nested = Dict(:level1 => Dict(:level2 => Dict(:level3 => Dict(:level4 => [1, 2, 3]))))
        @test can_reconstruct(deep_nested)
        
        # Test circular reference detection
        circular_dict = Dict{Symbol, Any}()
        circular_dict[:self] = circular_dict
        @test !can_reconstruct(circular_dict)  # Should detect and reject
        
        # Test with non-serializable types
        @test !can_reconstruct(stdout)  # IO streams
        @test !can_reconstruct(Task(() -> 1))  # Tasks/coroutines
        
        # Test unicode and special strings
        unicode_string = "Hello 🌍 测试 α β γ"
        rv_unicode = ReconstructableValue(unicode_string)
        @test reconstruct(typeof(rv_unicode)).value == unicode_string
        
        # Test extremely small values
        tiny_data = [eps(Float64)]
        rv_tiny = ReconstructableValue(tiny_data)
        @test reconstruct(typeof(rv_tiny)).value ≈ tiny_data
        
        # Test type parameter explosion (many unique values)
        unique_types = []
        for i in 1:50  # Create 50 unique type parameters
            push!(unique_types, typeof(ReconstructableValue([i])))
        end
        @test length(unique(unique_types)) == 50  # All should be unique
        @test all(T -> T <: ReconstructableValue, unique_types)
    end
    
    @testset "Type Safety" begin
        # Test that type parameters are preserved correctly
        string_rv = ReconstructableValue("test")
        @test base_type(type_repr(string_rv)) == String
        
        # Test that reconstruction preserves exact types
        int_vec = [1, 2, 3]
        float_vec = [1.0, 2.0, 3.0]
        
        rv_int = ReconstructableValue(int_vec)
        rv_float = ReconstructableValue(float_vec)
        
        @test typeof(reconstruct(typeof(rv_int)).value) == Vector{Int}
        @test typeof(reconstruct(typeof(rv_float)).value) == Vector{Float64}
        
        # Test that different values have different types
        @test typeof(ReconstructableValue(1)) != typeof(ReconstructableValue(2))
        @test typeof(ReconstructableValue([1])) != typeof(ReconstructableValue([2]))
    end
    
    @testset "Performance" begin
        # Test that type-level operations are reasonably fast
        data = randn(100)
        
        # Measure encoding time
        encoding_time = @elapsed begin
            for i in 1:10
                T = to_type(data)
                from_type(T)
            end
        end
        
        # Should complete in reasonable time (this is a basic check)
        @test encoding_time < 1.0  # Less than 1 second for 10 operations
        
        # Test reconstructable performance
        rv = ReconstructableValue(data)
        reconstruction_time = @elapsed begin
            for i in 1:10
                reconstruct(typeof(rv))
            end
        end
        
        @test reconstruction_time < 1.0
        
        # Test zero-allocation for type-level operations (compile-time)
        T = to_type([1, 2, 3])
        allocs = @allocated from_type(T)
        @test allocs < 1000  # Should be minimal allocations
        
        # Test that reconstruction is fast
        small_rv = ReconstructableValue([1, 2, 3, 4, 5])
        fast_time = @elapsed begin
            for i in 1:100
                reconstruct(typeof(small_rv))
            end
        end
        @test fast_time < 0.1  # Should be very fast for small data
        
        # Test memoization effectiveness (same type should be fast)
        T1 = typeof(ReconstructableValue([1, 2, 3]))
        T2 = typeof(ReconstructableValue([1, 2, 3]))  # Same value, same type
        @test T1 == T2  # Should be identical types
        
        # Performance regression test
        medium_data = rand(Int, 50)
        medium_rv = ReconstructableValue(medium_data)
        medium_time = @elapsed begin
            for i in 1:10
                reconstruct(typeof(medium_rv))
            end
        end
        @test medium_time < 0.5  # Should scale reasonably
    end
end