module JuliaFormat

export format_code

import Base: operator_precedence, uni_ops, isoperator

struct FormatError <: Exception
    msg::AbstractString
end

expr_and_type(x::Expr, expr_type::Symbol) = x.head === expr_type

expr_and_type(x, expr_type::Symbol) = false

isoperator(x::Expr) = false

function format_code(code_string::T) where T <: AbstractString
    code_array = T[]
    fragment, parse_start_index = Meta.parse(code_string, 1)
    while fragment !== nothing
        push!(code_array, format(fragment))

        fragment, parse_start_index = Meta.parse(code_string, parse_start_index)
    end

    return join(code_array, "\n")
end

function format(code::Expr; parent_precedence=0)
    return format(code, Val{code.head}(); parent_precedence=parent_precedence)
end

format(linenode::LineNumberNode) = linenode.line > 1 ? "\n" : ""

format(sym::Symbol) = string(sym)

format(var::Union{Real, Char, String}) = repr(var)

# a fallback for methods which don't take kwargs
format(args...; kwargs...) = format(args...)

## Function Calls

# different call types represent different formatting behaviour cases

abstract type CallType end

struct ScalarMultiply <: CallType
    parent_precedence::Int
    precedence::Int
end

struct UnaryCall <: CallType
    parent_precedence::Int
    precedence::Int
end

struct InfixCall <: CallType
    parent_precedence::Int
    precedence::Int
end

struct FunctionCall <: CallType
    parent_precedence::Int
    precedence::Int
end

function CallType(code::Expr; parent_precedence=0)
    func = code.args[1]
    args = code.args[2:end]
    nargs = length(args)

    if func === :* && nargs == 2 && isa(args[1], Real) && isa(args[2], Symbol)
        return ScalarMultiply(parent_precedence, operator_precedence(:*))
    elseif func in uni_ops && nargs == 1
        return UnaryCall(parent_precedence, operator_precedence(func))
    elseif isoperator(func) && nargs > 1 && ~any(x->expr_and_type(x, :...), args)
        return InfixCall(parent_precedence, operator_precedence(func))
    else
        return FunctionCall(parent_precedence, 0)
    end
end

function format(code::Expr, v::Val{:call}; parent_precedence=0)
    return format(code, v, CallType(code; parent_precedence=parent_precedence))
end

function format(code::Expr, ::Val{:call}, ::ScalarMultiply)
    return "$(format(code.args[2]))$(format(code.args[3]))"
end

function format(code::Expr, ::Val{:call}, ::UnaryCall)
    return "$(format(code.args[1]))$(format(code.args[2]))"
end

function format(code::Expr, ::Val{:call}, callobj::InfixCall)
    buffer = IOBuffer()

    needs_parens = callobj.precedence < callobj.parent_precedence
    if needs_parens
        print(buffer, '(')
    end

    join(
        buffer,
        map(code.args[2:end]) do x
            return format(x; parent_precedence=callobj.precedence)
        end,
        " $(format(code.args[1])) ",
    )

    if needs_parens
        print(buffer, ')')
    end

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:call}, ::FunctionCall)
    buffer = IOBuffer()

    nargs = length(code.args) - 1
    print(buffer, format(code.args[1]), '(')
    if nargs > 0
        args = Any[]
        kwargs = Any[]
        semicolon_kwargs = Any[]

        for arg in code.args[2:end]
            if expr_and_type(arg, :parameters)
                # kwargs after a semicolon, only appears once
                semicolon_kwargs = arg.args
            elseif expr_and_type(arg, :kw)
                push!(kwargs, arg)
            else
                push!(args, arg)
            end
        end

        join(buffer, map(format, args), ", ")

        append!(kwargs, semicolon_kwargs)
        if !isempty(kwargs)
            print(buffer, "; ")
            join(buffer, map(format, kwargs), ", ")
        end
    end
    print(buffer, ')')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:...})
    return "$(format(code.args[1]))..."
end

function format(code::Expr, ::Val{:kw})
    buffer = IOBuffer()
    op = :(=)
    prec = operator_precedence(op)

    print(buffer, format(code.args[1]; parent_precedence=prec))
    print(buffer, op)
    print(buffer, format(code.args[2]; parent_precedence=prec))

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:(=>)})
    buffer = IOBuffer()
    op = code.head
    prec = operator_precedence(op)

    print(buffer, format(code.args[1]; parent_precedence=prec))
    print(buffer, ' ', op, ' ')
    print(buffer, format(code.args[2]; parent_precedence=prec))

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:(:)})
    return join(map(format, code.args), ":")
end


## Assignment

const AssignmentVals = Union{
    Val{:(=)},
    Val{:*=},
    Val{:+=},
    Val{:/=},
    Val{:-=},
    Val{:÷=},
    Val{:\=},
    Val{:&=},
    Val{:|=},
    Val{:^=},
    Val{:$=},
    Val{:%=},
    Val{://=},
    Val{:<<=},
    Val{:>>=},
    Val{:>>>=},
    Val{:(:=)},
    Val{:.*=},
    Val{:.+=},
    Val{:./=},
    Val{:.-=},
    Val{:.÷=},
    Val{:.\=},
    Val{:.^=},
    Val{:.%=}
}

function format(code::Expr, ::AssignmentVals)
    buffer = IOBuffer()
    op = code.head
    prec = operator_precedence(op)

    if expr_and_type(code.args[1], :tuple)
        join(buffer, map(format, code.args[1].args), ", ")
    else
        print(buffer, format(code.args[1]; parent_precedence=prec))
    end

    print(buffer, ' ', code.head, ' ')
    print(buffer, format(code.args[2]; parent_precedence=prec))

    return String(take!(buffer))
end

function format(code::Expr, ::Union{Val{:local}, Val{:global}, Val{:const}})
    return "$(code.head) $(format(code.args[1]))"
end

## Tuples

function format(code::Expr, ::Val{:tuple})
    buffer = IOBuffer()

    print(buffer, '(')
    join(buffer, map(format, code.args), ", ")
    print(buffer, ')')

    return String(take!(buffer))
end

## Importing

function format(code::Expr, ::Val{:using})
    return "using $(format(code.args[1]))"
end

function format(code::Expr, ::Val{:import})
    if length(code.args) == 1
        return "import $(format(code.args[1]))"
    else
        return "import $(format(code.args[1])): $(format(code.args[2]))"
    end
end

## Types

function format(code::Expr, ::Val{:(::)})
    buffer = IOBuffer()
    op = code.head
    prec = operator_precedence(op)

    print(buffer, format(code.args[1]; parent_precedence=prec))
    print(buffer, op)
    print(buffer, format(code.args[2]; parent_precedence=prec))

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:curly})
    buffer = IOBuffer()

    print(buffer, format(code.args[1]))
    print(buffer, '{')
    join(buffer, map(format, code.args[2:end]), ", ")
    print(buffer, '}')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:<:})  # note: only subtyping, not comparison
    buffer = IOBuffer()
    op = code.head
    prec = operator_precedence(op)

    print(buffer, format(code.args[1]; parent_precedence=prec))
    print(buffer, ' ', op, ' ')
    print(buffer, format(code.args[2]; parent_precedence=prec))

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:abstract})
    return "abstract $(format(code.args[1]))"
end

function format(code::Expr, ::Val{:typealias})
    return "typealias $(format(code.args[1])) $(format(code.args[2]))"
end

function format(code::Expr, ::Val{:.})
    buffer = IOBuffer()
    op = code.head
    prec = operator_precedence(op)

    print(buffer, format(code.args[1]; parent_precedence=prec), '.')

    if isa(code.args[2], QuoteNode)
        print(buffer, format(code.args[2].value; parent_precedence=prec))
    else
        print(buffer, '(', format(code.args[2]), ')')
    end

    return String(take!(buffer))
end

## Comparison

function format(code::Expr, ::Val{:comparison})
    buffer = IOBuffer()
    op = code.args[2]
    prec = operator_precedence(op)

    print(buffer, format(code.args[1]; parent_precedence=prec))
    print(buffer, ' ', op, ' ')
    print(buffer, format(code.args[3]; parent_precedence=prec))

    return String(take!(buffer))
end

function format(code::Expr, ::Union{Val{:&&},Val{:||}})
    buffer = IOBuffer()
    op = code.head
    prec = operator_precedence(op)

    print(buffer, format(code.args[1]; parent_precedence=prec))
    print(buffer, ' ', op, ' ')
    print(buffer, format(code.args[2]; parent_precedence=prec))

    return String(take!(buffer))
end

## Metaprogramming

function format(code::Expr, ::Val{:$})
    arg = code.args[1]

    if isa(arg, Symbol)
        return "\$$arg"
    else
        return "\$($(format(arg)))"
    end
end

## Arrays and Indexing

function format(code::Expr, ::Val{:vect})
    buffer = IOBuffer()

    print(buffer, '[')
    join(buffer, map(format, code.args), ", ")
    print(buffer, ']')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:cell1d})
    buffer = IOBuffer()

    print(buffer, '{')
    join(buffer, map(format, code.args), ", ")
    print(buffer, '}')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:cell2d})
    buffer = IOBuffer()

    rows, cols = code.args[1:2]

    print(buffer, '{')
    for i = 1:(rows - 1)
        for j = 1:(cols - 1)
            print(buffer, format(code.args[(j - 1) * rows + i + 2]), ' ')
        end
        print(buffer, format(code.args[(cols - 1) * rows + i + 2]), "; ")
    end
    for j = 1:(cols - 1)
        print(buffer, format(code.args[j * rows + 2]), ' ')
    end
    print(buffer, format(code.args[cols * rows + 2]))
    print(buffer, '}')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:hcat})
    buffer = IOBuffer()

    print(buffer, '[')
    join(buffer, map(format, code.args), ' ')
    print(buffer, ']')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:row})
    return join(map(format, code.args), ' ')
end

function format(code::Expr, ::Val{:vcat})
    buffer = IOBuffer()

    print(buffer, '[')
    join(buffer, map(format, code.args), "; ")
    print(buffer, ']')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:typed_vcat})
    buffer = IOBuffer()

    print(buffer, format(code.args[1]))
    print(buffer, '[')
    join(buffer, map(format, code.args[2:end]), "; ")
    print(buffer, ']')

    return String(take!(buffer))
end

function format(code::Expr, ::Val{:ref})
    buffer = IOBuffer()

    if expr_and_type(code.args[1], :call) && !(isa(CallType(code.args[1]), FunctionCall))
        print(buffer, '(', format(code.args[1]), ')')
    else
        print(buffer, format(code.args[1]))
    end

    print(buffer, '[')
    join(buffer, map(format, code.args[2:end]), ", ")
    print(buffer, ']')

    return String(take!(buffer))
end

end # module
