"""
Reconstructable trait system for TypeReconstructable.jl

This module provides a trait-based system for values that can be reconstructed
from their type representations, building on the TypeLevel encoding system.
"""

using .TypeReconstructable: TypeLevel, to_type, from_type, is_typelevel, base_type

"""
    Reconstructable{T}

Abstract type representing values that can be reconstructed from their type.
Types that implement this trait can be encoded as types and later reconstructed
with zero runtime overhead.

# Type Parameters
- `T`: The type-level representation of the value

# Interface
Types implementing this trait should provide:
- `reconstruct(::Type{ReconstructableType{T}})` - Reconstruct the value from its type
- `type_repr(::ReconstructableType)` - Get the type representation

# Example
```julia
struct MyModel{T} <: Reconstructable{T}
    data::Any
end

# Implement the interface
reconstruct(::Type{MyModel{T}}) where T = MyModel(from_type(T))
type_repr(m::MyModel) = to_type(m.data)
```
"""
abstract type Reconstructable{T} end

"""
    reconstruct(::Type{R}) where R <: Reconstructable

Reconstruct a value from its type representation.
This is the core interface method for the Reconstructable trait.

# Arguments
- `::Type{R}`: A Reconstructable type

# Returns
- The reconstructed value

# Example
```julia
T = ReconstructableValue(42)
x = reconstruct(typeof(T))  # 42
```
"""
function reconstruct end

"""
    type_repr(x::Reconstructable)

Get the type representation of a reconstructable value.

# Arguments
- `x`: A Reconstructable value

# Returns
- The type representation (typically a TypeLevel type)
"""
function type_repr end

"""
    ReconstructableValue{T} <: Reconstructable{T}

A concrete implementation of Reconstructable that can wrap any value
and make it reconstructable from its type.

# Type Parameters
- `T`: The TypeLevel encoding of the wrapped value

# Fields
- `value`: The wrapped value (not stored at runtime when reconstructed)

# Example
```julia
rv = ReconstructableValue([1, 2, 3])
T = typeof(rv)  # ReconstructableValue{TypeLevel{Vector{Int64}, (...)}}
x = reconstruct(T)  # ReconstructableValue([1, 2, 3])
```
"""
struct ReconstructableValue{T} <: Reconstructable{T}
    value::Any
    
    function ReconstructableValue{T}() where T
        # Constructor for type-only reconstruction
        if !is_typelevel(T)
            error("Expected TypeLevel type, got $T")
        end
        value = from_type(T)
        new{T}(value)
    end
    
    function ReconstructableValue(value)
        # Check if value can be reconstructed
        if !can_reconstruct(value)
            error("Value of type $(typeof(value)) cannot be made reconstructable")
        end
        T = to_type(value)
        new{T}(value)
    end
end

# Implement the Reconstructable interface for ReconstructableValue
reconstruct(::Type{ReconstructableValue{T}}) where T = ReconstructableValue{T}()
type_repr(rv::ReconstructableValue{T}) where T = T

"""
    @reconstructable struct_def

Macro to automatically generate a Reconstructable wrapper for a struct.
This creates a parameterized type that encodes the struct's field values
in its type parameters.

# Arguments
- `struct_def`: A struct definition

# Returns
- A struct that implements the Reconstructable interface

# Example
```julia
@reconstructable struct MyModel
    weights::Vector{Float64}
    bias::Float64
end

# Usage
m = MyModel([1.0, 2.0], 0.5)
T = typeof(m)  # MyModel{...}
m2 = reconstruct(T)  # MyModel([1.0, 2.0], 0.5)
```
"""
macro reconstructable(struct_def)
    if !isa(struct_def, Expr) || struct_def.head != :struct
        error("@reconstructable can only be applied to struct definitions, got $(typeof(struct_def))")
    end
    
    # Extract struct information
    struct_name = struct_def.args[2]
    if isa(struct_name, Expr) && struct_name.head == :(<:)
        # Handle inheritance
        struct_name = struct_name.args[1]
    end
    
    # Validate struct name
    if !isa(struct_name, Symbol)
        error("Invalid struct name: expected Symbol, got $(typeof(struct_name))")
    end
    
    # Generate the parameterized struct
    param_name = gensym("T")
    
    # Create the new struct definition
    new_struct = quote
        struct $(struct_name){$(param_name)} <: Reconstructable{$(param_name)}
            $(struct_def.args[3].args...)
            
            function $(struct_name){$(param_name)}() where $(param_name)
                # Reconstruct from type
                values = from_type($(param_name))
                new{$(param_name)}(values...)
            end
            
            function $(struct_name)(args...)
                # Create with type encoding
                T = to_type(args)
                new{T}(args...)
            end
        end
        
        # Implement the Reconstructable interface
        reconstruct(::Type{$(struct_name){$(param_name)}}) where $(param_name) = $(struct_name){$(param_name)}()
        type_repr(x::$(struct_name){$(param_name)}) where $(param_name) = $(param_name)
    end
    
    return esc(new_struct)
end

"""
    make_reconstructable(T::Type)

Create a Reconstructable wrapper type for an existing type.

# Arguments
- `T`: The type to wrap

# Returns
- A new type that implements Reconstructable

# Example
```julia
ReconstructableDict = make_reconstructable(Dict)
rd = ReconstructableDict(Dict(:a => 1, :b => 2))
T = typeof(rd)
rd2 = reconstruct(T)  # Reconstructed dictionary
```
"""
function make_reconstructable(::Type{T}) where T
    return ReconstructableValue{to_type(T)}
end

"""
    is_reconstructable(::Type{T}) where T

Check if a type implements the Reconstructable trait.

# Arguments
- `T`: The type to check

# Returns
- `true` if `T` is reconstructable, `false` otherwise
"""
is_reconstructable(::Type{T}) where T = T <: Reconstructable

"""
    can_reconstruct(x)

Check if a value can be made reconstructable (i.e., can be serialized).

# Arguments
- `x`: The value to check

# Returns
- `true` if the value can be made reconstructable, `false` otherwise
"""
function can_reconstruct(x)
    try
        type_level = to_type(x)
        # Also try to reconstruct to ensure roundtrip works
        from_type(type_level)
        return true
    catch e
        # Log the specific error for debugging
        @debug "Cannot reconstruct value of type $(typeof(x)): $e"
        return false
    end
end

# Export public interface
export Reconstructable, ReconstructableValue, reconstruct, type_repr, 
       @reconstructable, make_reconstructable, is_reconstructable, can_reconstruct