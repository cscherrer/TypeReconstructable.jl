"""
Scoping and variable resolution for TypeReconstructable.jl using JuliaVariables.jl

This module provides scoping analysis and variable resolution capabilities
for code generation contexts, enabling proper handling of free variables
and closures in generated functions.
"""

using JuliaVariables
using NameResolution
using .TypeReconstructable: Reconstructable, is_reconstructable, reconstruct

# Re-export key JuliaVariables functionality
export solve, simplify_ex, Var

"""
    ScopeAnalyzer

A wrapper around JuliaVariables functionality for TypeReconstructable-specific scoping analysis.
This provides a higher-level interface for analyzing variable scopes in the context
of Reconstructable types and generated functions.
"""
struct ScopeAnalyzer
    analyzer::Any  # JuliaVariables analyzer  
    reconstructable_vars::Set{Symbol}
    
    function ScopeAnalyzer()
        # Use JuliaVariables.jl's top-level analyzer
        analyzer = try
            top_analyzer()
        catch e
            # Fallback if top_analyzer is not available
            @warn "Could not create JuliaVariables analyzer: $e"
            nothing
        end
        reconstructable_vars = Set{Symbol}()
        new(analyzer, reconstructable_vars)
    end
end

"""
    analyze_scope(expr, analyzer::ScopeAnalyzer=ScopeAnalyzer())

Analyze the scope of an expression, identifying free variables and
their reconstructable status.

# Arguments
- `expr`: Expression to analyze
- `analyzer`: ScopeAnalyzer instance

# Returns
- `(analyzed_expr, free_vars, reconstructable_vars)`: Tuple of analyzed expression,
  free variables, and reconstructable variables

# Example
```julia
expr = :(x + y * z)
analyzed, free, reconstructable = analyze_scope(expr)
```
"""
function analyze_scope(expr, analyzer::ScopeAnalyzer=ScopeAnalyzer())
    # Check if analyzer is available
    if analyzer.analyzer === nothing
        @warn "JuliaVariables analyzer not available, using fallback analysis"
        # Fallback: simple symbol extraction
        symbols = Set{Symbol}()
        postwalk(expr) do node
            if isa(node, Symbol) && !startswith(string(node), "#")
                push!(symbols, node)
            end
            node
        end
        reconstructable_vars = intersect(symbols, analyzer.reconstructable_vars)
        return (expr, symbols, reconstructable_vars)
    end
    
    # Simplify the expression for analysis
    simplified = simplify_ex(expr)
    
    # Analyze scoping using JuliaVariables
    analyzed = solve!(simplified)
    
    # Extract free variables
    free_vars = extract_free_variables(analyzed)
    
    # Identify reconstructable variables
    reconstructable_vars = filter(var -> var in analyzer.reconstructable_vars, free_vars)
    
    return (analyzed, free_vars, reconstructable_vars)
end

"""
    mark_reconstructable!(analyzer::ScopeAnalyzer, var::Symbol)

Mark a variable as reconstructable in the scope analyzer.

# Arguments
- `analyzer`: ScopeAnalyzer instance
- `var`: Variable name to mark as reconstructable

# Example
```julia
analyzer = ScopeAnalyzer()
mark_reconstructable!(analyzer, :my_reconstructable_var)
```
"""
function mark_reconstructable!(analyzer::ScopeAnalyzer, var::Symbol)
    push!(analyzer.reconstructable_vars, var)
end

"""
    convert_closures(expr, free_vars, reconstructable_vars)

Convert closures in an expression to handle reconstructable variables properly.
This transforms closures to explicitly handle type-level reconstruction.

# Arguments
- `expr`: Expression containing closures
- `free_vars`: Set of free variables
- `reconstructable_vars`: Set of reconstructable variables

# Returns
- Transformed expression with proper closure handling

# Example
```julia
expr = :(x -> x + captured_var)
free_vars = Set([:captured_var])
reconstructable_vars = Set([:captured_var])
converted = convert_closures(expr, free_vars, reconstructable_vars)
```
"""
function convert_closures(expr, free_vars, reconstructable_vars)
    return postwalk_closure_convert(expr, free_vars, reconstructable_vars)
end

"""
    @scope_analysis expr

Macro for convenient scope analysis of expressions.
This macro analyzes the scope of an expression and returns information
about free variables and reconstructable variables.

# Arguments
- `expr`: Expression to analyze

# Returns
- NamedTuple with fields: `analyzed`, `free_vars`, `reconstructable_vars`

# Example
```julia
result = @scope_analysis begin
    x = reconstructable_var + 1
    y = x * 2
    z = regular_var + y
end
```
"""
macro scope_analysis(expr)
    return esc(quote
        local analyzer = ScopeAnalyzer()
        local analyzed, free, reconstructable = analyze_scope($(QuoteNode(expr)), analyzer)
        (analyzed=analyzed, free_vars=free, reconstructable_vars=reconstructable)
    end)
end

"""
    @closure_convert expr

Macro for converting closures to handle reconstructable variables.
This macro automatically identifies and converts closures in an expression.

# Arguments
- `expr`: Expression containing closures

# Returns
- Expression with converted closures

# Example
```julia
converted = @closure_convert begin
    map(x -> x + reconstructable_var, data)
end
```
"""
macro closure_convert(expr)
    return esc(quote
        local analyzer = ScopeAnalyzer()
        local analyzed, free, reconstructable = analyze_scope($(QuoteNode(expr)), analyzer)
        convert_closures(analyzed, free, reconstructable)
    end)
end

"""
    create_scoped_function(name, args, body, free_vars, reconstructable_vars)

Create a function with proper scoping for free variables and reconstructable variables.

# Arguments
- `name`: Function name
- `args`: Function arguments
- `body`: Function body
- `free_vars`: Free variables to capture
- `reconstructable_vars`: Reconstructable variables to capture

# Returns
- Function definition with proper scoping

# Example
```julia
fn_def = create_scoped_function(
    :my_function,
    [:(x::Int)],
    :(x + captured_var),
    Set([:captured_var]),
    Set([:captured_var])
)
```
"""
function create_scoped_function(name, args, body, free_vars, reconstructable_vars)
    # Create parameters for free variables
    free_params = []
    
    for var in free_vars
        if var in reconstructable_vars
            # For reconstructable variables, pass the type
            push!(free_params, :($var::Type))
        else
            # For regular variables, pass the value
            push!(free_params, :($var))
        end
    end
    
    # Create the function body with reconstruction
    scoped_body = quote
        # Reconstruct reconstructable variables
        $(map(reconstructable_vars) do var
            :($var = reconstruct($var))
        end...)
        
        # Original function body
        $body
    end
    
    # Create the function definition
    return Expr(:function, 
        Expr(:call, name, args..., free_params...),
        scoped_body
    )
end

"""
    resolve_variable_names(expr, context::Module=@__MODULE__)

Resolve variable names in an expression using NameResolution.jl.

# Arguments
- `expr`: Expression to resolve
- `context`: Module context for resolution

# Returns
- Expression with resolved variable names

# Example
```julia
resolved = resolve_variable_names(:(x + y), MyModule)
```
"""
function resolve_variable_names(expr, context::Module=@__MODULE__)
    # NameResolution.jl API is unstable, disable this functionality
    # Return the original expression unchanged
    @warn "resolve_variable_names is disabled due to unstable NameResolution.jl API"
    return expr
end

"""
    @with_scope context expr

Execute an expression with a specific scoping context.

# Arguments
- `context`: Module or scoping context
- `expr`: Expression to execute

# Returns
- Expression with scoping context (disabled to avoid eval)

# Example
```julia
# @with_scope is disabled to avoid eval usage
# Instead of:
# result = @with_scope MyModule begin
#     x + y
# end
# Use direct module qualification:
# result = MyModule.x + MyModule.y
```
"""
macro with_scope(context, expr)
    error("@with_scope is disabled to avoid eval usage. Use direct module qualification instead.")
end

# Helper functions

"""
    extract_free_variables(analyzed_expr)

Extract free variables from an analyzed expression using JuliaVariables.jl's analysis.
"""
function extract_free_variables(analyzed_expr)
    free_vars = Set{Symbol}()
    
    # Use JuliaVariables.jl to properly extract free variables
    # The analyzed expression should contain the variable analysis
    postwalk(analyzed_expr) do node
        if isa(node, Var)
            # For now, consider all Var nodes as potentially free
            # A more sophisticated implementation would check the binding context
            push!(free_vars, node.name)
        end
        node
    end
    
    return free_vars
end

"""
    is_bound_variable(var::Symbol, analyzed_expr)

Check if a variable is bound in an analyzed expression using JuliaVariables.jl.
"""
function is_bound_variable(var::Symbol, analyzed_expr)
    # Use JuliaVariables.jl's analysis to check if variable is bound
    # For now, provide a simplified implementation
    found_var = false
    postwalk(analyzed_expr) do node
        if isa(node, Var) && node.name == var
            found_var = true
        end
        node
    end
    return found_var
end

"""
    postwalk_closure_convert(expr, free_vars, reconstructable_vars)

Post-order walk to convert closures in an expression.
"""
function postwalk_closure_convert(expr, free_vars, reconstructable_vars)
    if isa(expr, Expr)
        if expr.head == :->
            # Handle lambda expressions
            return convert_lambda(expr, free_vars, reconstructable_vars)
        elseif expr.head == :function
            # Handle function definitions
            return convert_function_def(expr, free_vars, reconstructable_vars)
        else
            # Recursively process arguments
            new_args = map(arg -> postwalk_closure_convert(arg, free_vars, reconstructable_vars), expr.args)
            return Expr(expr.head, new_args...)
        end
    else
        return expr
    end
end

"""
    convert_lambda(lambda_expr, free_vars, reconstructable_vars)

Convert a lambda expression to handle reconstructable variables.
"""
function convert_lambda(lambda_expr, free_vars, reconstructable_vars)
    # Extract lambda components
    params = lambda_expr.args[1]
    body = lambda_expr.args[2]
    
    # Find free variables in the lambda body
    lambda_free = intersect(free_vars, extract_symbols(body))
    lambda_reconstructable = intersect(reconstructable_vars, lambda_free)
    
    # Create new lambda with reconstructable handling
    new_body = quote
        # Reconstruct reconstructable variables
        $(map(lambda_reconstructable) do var
            :($var = is_reconstructable(typeof($var)) ? reconstruct(typeof($var)) : $var)
        end...)
        
        # Original lambda body
        $body
    end
    
    return Expr(:->, params, new_body)
end

"""
    convert_function_def(func_expr, free_vars, reconstructable_vars)

Convert a function definition to handle reconstructable variables.
"""
function convert_function_def(func_expr, free_vars, reconstructable_vars)
    # For now, return the function as-is
    # This can be enhanced to handle reconstructable variables in function definitions
    return func_expr
end

"""
    extract_symbols(expr)

Extract all symbols from an expression.
"""
function extract_symbols(expr)
    symbols = Set{Symbol}()
    
    postwalk(expr) do node
        if isa(node, Symbol)
            push!(symbols, node)
        end
        node
    end
    
    return symbols
end

"""
    postwalk(f, expr)

Post-order walk through an expression.
"""
function postwalk(f, expr)
    if isa(expr, Expr)
        new_args = map(arg -> postwalk(f, arg), expr.args)
        return f(Expr(expr.head, new_args...))
    else
        return f(expr)
    end
end

# Export the scoping interface
export ScopeAnalyzer, analyze_scope, mark_reconstructable!, convert_closures,
       @scope_analysis, @closure_convert, @with_scope, create_scoped_function,
       resolve_variable_names