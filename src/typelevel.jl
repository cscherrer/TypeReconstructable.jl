"""
TypeLevel encoding system for TypeReconstructable.jl

This module provides functionality to encode arbitrary Julia values as types,
enabling compile-time reconstruction of values from their type representations.
The approach is based on serialization to a buffer that is then encoded as 
type parameters.
"""

using Serialization

"""
    TypeLevel{T,Buf}

A type that encodes a value of type `T` in its type parameters using a 
serialized buffer representation `Buf`.

# Type Parameters
- `T`: The original type of the encoded value
- `Buf`: A tuple of UInt8 values representing the serialized buffer

# Example
```julia
x = [1, 2, 3]
T = to_type(x)  # TypeLevel{Vector{Int64}, (0x37, 0x4a, ...)}
y = from_type(T)  # [1, 2, 3]
```
"""
struct TypeLevel{T,Buf} end

"""
    to_type(x::T) where T

Encode a value `x` as a TypeLevel type by serializing it to a buffer
and encoding the buffer as type parameters.

# Arguments
- `x`: The value to encode

# Returns
- `Type{TypeLevel{T,Buf}}`: A type encoding the value

# Example
```julia
x = Dict(:a => 1, :b => 2)
T = to_type(x)
# T isa Type{TypeLevel{Dict{Symbol,Int64}, (...)}}
```
"""
function to_type(x::T) where T
    # Serialize the value to a buffer
    io = IOBuffer()
    try
        serialize(io, x)
    catch e
        error("Cannot serialize value of type $T: $e")
    end
    buffer = take!(io)
    
    # Check for empty buffer
    if isempty(buffer)
        error("Serialization produced empty buffer for value of type $T")
    end
    
    # Convert buffer to tuple of UInt8 for type encoding
    buf_tuple = Tuple(buffer)
    
    return TypeLevel{T, buf_tuple}
end

"""
    from_type(::Type{TypeLevel{T,Buf}}) where {T,Buf}

Reconstruct a value from its TypeLevel type representation by deserializing
the encoded buffer.

# Arguments
- `::Type{TypeLevel{T,Buf}}`: The TypeLevel type encoding the value

# Returns
- The reconstructed value of type `T`

# Example
```julia
T = to_type([1, 2, 3])
x = from_type(T)  # [1, 2, 3]
```
"""
function from_type(::Type{TypeLevel{T,Buf}}) where {T,Buf}
    # Validate buffer tuple
    if !isa(Buf, Tuple) || !all(x -> isa(x, UInt8), Buf)
        error("Invalid buffer tuple: expected Tuple of UInt8, got $Buf")
    end
    
    # Convert tuple back to buffer
    buffer = collect(UInt8, Buf)
    
    # Check for empty buffer
    if isempty(buffer)
        error("Cannot deserialize from empty buffer")
    end
    
    # Deserialize the value
    io = IOBuffer(buffer)
    try
        value = deserialize(io)
        # Verify type matches
        if !isa(value, T)
            error("Type mismatch: expected $T, got $(typeof(value))")
        end
        return value::T
    catch e
        error("Cannot deserialize value of type $T: $e")
    end
end

"""
    @to_type(expr)

Macro version of `to_type` that operates on expressions at compile time.

# Arguments
- `expr`: An expression that evaluates to a value

# Returns
- A TypeLevel type encoding the value

# Example
```julia
T = @to_type [1, 2, 3]
x = from_type(T)  # [1, 2, 3]
```
"""
macro to_type(expr)
    return :(to_type($(esc(expr))))
end

"""
    is_typelevel(::Type{T}) where T

Check if a type is a TypeLevel type.

# Arguments
- `T`: The type to check

# Returns
- `true` if `T` is a TypeLevel type, `false` otherwise
"""
is_typelevel(::Type{TypeLevel{T,Buf}}) where {T,Buf} = true
is_typelevel(::Type{T}) where T = false

"""
    base_type(::Type{TypeLevel{T,Buf}}) where {T,Buf}

Extract the base type from a TypeLevel type.

# Arguments
- `::Type{TypeLevel{T,Buf}}`: A TypeLevel type

# Returns
- The base type `T`
"""
base_type(::Type{TypeLevel{T,Buf}}) where {T,Buf} = T

"""
    type_equal(::Type{TypeLevel{T1,Buf1}}, ::Type{TypeLevel{T2,Buf2}}) where {T1,T2,Buf1,Buf2}

Check if two TypeLevel types encode the same value by comparing their buffers.

# Arguments
- Two TypeLevel types to compare

# Returns
- `true` if they encode the same value, `false` otherwise
"""
type_equal(::Type{TypeLevel{T1,Buf1}}, ::Type{TypeLevel{T2,Buf2}}) where {T1,T2,Buf1,Buf2} = 
    T1 == T2 && Buf1 == Buf2

# Export public interface
export TypeLevel, to_type, from_type, @to_type, is_typelevel, base_type, type_equal