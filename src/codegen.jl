"""
Code generation utilities for TypeReconstructable.jl

This module provides macros and utilities for creating generated functions
that can reconstruct values from their type representations and generate
optimized code with automatic memoization.
"""

using .TypeReconstructable: Reconstructable, reconstruct, type_repr, is_reconstructable, 
                TypeLevel, from_type, is_typelevel

"""
    @autogen function_definition

Macro to create a generated function that automatically reconstructs
Reconstructable arguments from their types before generating code.

The generated function will:
1. Reconstruct Reconstructable values from their type parameters
2. Generate optimized code based on the reconstructed values
3. Benefit from Julia's automatic memoization for generated functions

# Arguments
- `function_definition`: A function definition where some parameters are Reconstructable

# Usage
```julia
@autogen function my_function(x::ReconstructableValue{T}) where T
    # This code runs at compile time
    val = reconstruct(typeof(x))
    if val.value isa Vector
        return :(\$val.value[1] + \$val.value[2])
    else
        return :(\$val.value * 2)
    end
end
```

# Generated Function Pattern
The macro transforms the function into a generated function that:
- Takes type parameters encoding the reconstructable values
- Reconstructs the values at compile time
- Generates optimized code based on the reconstructed values
"""
macro autogen(func_def)
    if func_def.head != :function
        error("@autogen can only be applied to function definitions")
    end
    
    # Extract function signature and body
    sig = func_def.args[1]
    body = func_def.args[2]
    
    # Parse the function signature
    func_name, params, where_clause = parse_function_signature(sig)
    
    # Transform parameters to handle Reconstructable types
    new_params, reconstruction_code = transform_parameters(params)
    
    # Create the generated function
    generated_func = quote
        @generated function $(func_name)($(new_params...)) $(where_clause)
            # Reconstruction code
            $(reconstruction_code...)
            
            # Original function body
            $(body)
        end
    end
    
    return esc(generated_func)
end

"""
    @codegen expr

Macro to mark an expression as code generation content within an @autogen function.
This helps distinguish between compile-time computation and generated code.

# Arguments
- `expr`: An expression that generates code

# Returns
- The expression wrapped with appropriate code generation markers
"""
macro codegen(expr)
    return esc(expr)
end

"""
    reconstruct_args(args...)

Helper function to reconstruct multiple arguments if they are Reconstructable.
This is useful in generated functions that need to handle mixed argument types.

# Arguments
- `args...`: Arguments that may or may not be Reconstructable

# Returns
- Tuple of reconstructed values
"""
function reconstruct_args(args...)
    return map(args) do arg
        if is_reconstructable(typeof(arg))
            reconstruct(typeof(arg))
        else
            arg
        end
    end
end

"""
    @generated_with_reconstruction function_definition

Lower-level macro that creates a generated function with explicit reconstruction logic.
This provides more control than @autogen but requires manual handling of reconstruction.

# Arguments
- `function_definition`: A function definition

# Example
```julia
@generated_with_reconstruction function my_func(x::ReconstructableValue{T}) where T
    # Manually reconstruct the value
    val = from_type(T)
    
    # Generate code based on the value
    if val isa Vector
        return :(\$(val[1]) + \$(val[2]))
    else
        return :(\$val * 2)
    end
end
```
"""
macro generated_with_reconstruction(func_def)
    if func_def.head != :function
        error("@generated_with_reconstruction can only be applied to function definitions")
    end
    
    # Simply add @generated to the function
    generated_func = Expr(:macrocall, Symbol("@generated"), __source__, func_def)
    
    return esc(generated_func)
end

"""
    parse_function_signature(sig)

Parse a function signature into its components.

# Arguments
- `sig`: Function signature expression

# Returns
- `(func_name, params, where_clause)`: Parsed components
"""
function parse_function_signature(sig)
    if !isa(sig, Expr)
        error("Expected Expr for function signature, got $(typeof(sig))")
    end
    
    if sig.head == :where
        # Function with where clause
        func_sig = sig.args[1]
        if length(sig.args) < 2
            error("Invalid where clause: expected at least 2 arguments")
        end
        where_clause = Expr(:where, sig.args[2:end]...)
    else
        func_sig = sig
        where_clause = nothing
    end
    
    if !isa(func_sig, Expr) || func_sig.head != :call
        error("Invalid function signature: expected call expression, got $(func_sig)")
    end
    
    if length(func_sig.args) < 1
        error("Invalid function call: expected at least function name")
    end
    
    func_name = func_sig.args[1]
    params = func_sig.args[2:end]
    
    # Validate function name
    if !isa(func_name, Symbol)
        error("Invalid function name: expected Symbol, got $(typeof(func_name))")
    end
    
    return func_name, params, where_clause
end

"""
    transform_parameters(params)

Transform function parameters to handle Reconstructable types.

# Arguments
- `params`: List of parameter expressions

# Returns
- `(new_params, reconstruction_code)`: Transformed parameters and reconstruction code
"""
function transform_parameters(params)
    new_params = []
    reconstruction_code = []
    
    for param in params
        if isa(param, Expr) && param.head == :(::)
            # Typed parameter
            param_name = param.args[1]
            param_type = param.args[2]
            
            # Check if this is a Reconstructable type pattern
            if is_reconstructable_pattern(param_type)
                # Transform to type parameter
                push!(new_params, :(::Type{$(param_name)}))
                push!(reconstruction_code, :($(param_name) = reconstruct($(param_name))))
            else
                push!(new_params, param)
            end
        else
            push!(new_params, param)
        end
    end
    
    return new_params, reconstruction_code
end

"""
    is_reconstructable_pattern(type_expr)

Check if a type expression represents a Reconstructable type pattern.

# Arguments
- `type_expr`: Type expression to check

# Returns
- `true` if it's a Reconstructable pattern, `false` otherwise
"""
function is_reconstructable_pattern(type_expr)
    if isa(type_expr, Expr) && type_expr.head == :curly
        # Parameterized type
        base_type = type_expr.args[1]
        return base_type == :ReconstructableValue || base_type == :Reconstructable
    elseif isa(type_expr, Symbol)
        return type_expr == :Reconstructable
    end
    return false
end

"""
    @inline_generated function_definition

Macro to create a generated function that is marked for inlining.
This can provide additional performance benefits for simple generated functions.

# Arguments
- `function_definition`: A function definition

# Example
```julia
@inline_generated function simple_op(x::ReconstructableValue{T}) where T
    val = from_type(T)
    return :(\$val * 2)
end
```
"""
macro inline_generated(func_def)
    generated_func = Expr(:macrocall, Symbol("@generated"), __source__, func_def)
    inline_func = Expr(:macrocall, Symbol("@inline"), __source__, generated_func)
    return esc(inline_func)
end

"""
    codegen_cache

A global cache for storing generated code to avoid repeated computation.
This is primarily used for debugging and introspection.
"""
const codegen_cache = Dict{Any, Any}()

"""
    cache_generated_code(key, code)

Cache generated code for debugging and introspection.

# Arguments
- `key`: Cache key (typically function name and argument types)
- `code`: Generated code expression
"""
function cache_generated_code(key, code)
    codegen_cache[key] = code
    return code
end

"""
    get_cached_code(key)

Retrieve cached generated code.

# Arguments
- `key`: Cache key

# Returns
- Cached code expression or `nothing` if not found
"""
function get_cached_code(key)
    return get(codegen_cache, key, nothing)
end

"""
    clear_codegen_cache!()

Clear the code generation cache.
"""
function clear_codegen_cache!()
    empty!(codegen_cache)
end

# Export public interface
export @autogen, @codegen, @generated_with_reconstruction, @inline_generated,
       reconstruct_args, cache_generated_code, get_cached_code, clear_codegen_cache!