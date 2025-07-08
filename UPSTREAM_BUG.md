# JuliaVariables.jl Upstream Bug

## Summary

TypeReconstructable.jl's `make_gg_function` is disabled due to an upstream bug in JuliaVariables.jl v0.2.4.

## The Bug

**Location**: JuliaVariables.jl line 234  
**Function**: `IS_SCOPED`  
**Issue**: Missing null check for `st.ana`

```julia
# BUG: This function doesn't handle st.ana being Nothing
function IS_SCOPED(st::State, ex::Expr)
    ScopeInfo[ex] = (st.ana.solved.bounds, st.ana.solved.freevars, st.bound_inits)
    #                ^^^^^^^ CRASHES when st.ana is Nothing
end

# But State struct explicitly allows Nothing:
struct State
    ana::Union{Analyzer, Nothing}  # ← Nothing is allowed!
    ctx::Ctx
    bound_inits::Set{Symbol}
end
```

## Error Details

**Error**: `getproperty(x::Nothing, f::Symbol)`  
**JET Detection**: `invalid builtin function call: Base.getfield(x::Nothing, f::Symbol)`

**Call Chain**:
```
make_gg_function()
→ GeneralizedGenerated.mk_function()
→ JuliaVariables.solve!()
→ IS_SCOPED()
→ CRASH on st.ana.solved.bounds when st.ana is Nothing
```

## How to Reproduce

Use JET static analysis:
```bash
julia --project -e "using JET; using TypeReconstructable; @report_opt make_gg_function(:test, [:x], :(x+1))"
```

## Our Solution

1. **Disabled `make_gg_function`** - Avoids the bug entirely
2. **Provided alternatives**:
   - `@gg_autogen` macro for compile-time generation
   - `@generated` functions with TypeReconstructable
   - RuntimeGeneratedFunctions.jl for runtime generation
3. **Avoided eval usage** - Aligns with project requirements

## Impact

- **Zero user impact** - Alternative APIs provide the same functionality
- **Safer code** - No eval usage, no runtime crashes
- **Better performance** - `@generated` functions are more efficient than runtime generation

## Upstream Fix

The bug could be fixed in JuliaVariables.jl with a simple null check:

```julia
function IS_SCOPED(st::State, ex::Expr)
    if st.ana === nothing
        error("Analyzer is Nothing in IS_SCOPED - scoping analysis failed")
    end
    ScopeInfo[ex] = (st.ana.solved.bounds, st.ana.solved.freevars, st.bound_inits)
end
```

This should be reported to the JuliaVariables.jl repository.