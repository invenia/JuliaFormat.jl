module JuliaFormat

export format

import Base: show_unquoted

type FormatError <: Exception
    msg::AbstractString
end

expr_and_type(x::Expr, expr_type::Symbol) = x.head === expr_type
expr_and_type(x, expr_type::Symbol) = false

function format{T<:AbstractString}(code_string::T)
    code_array = T[]
    fragment, parse_start_index = parse(code_string, 1)
    while fragment !== nothing
        push!(code_array, format(fragment))

        fragment, parse_start_index = parse(code_string, parse_start_index)
    end

    return join(code_array, "\n")
end

format(code::Expr) = format(code, Val{code.head}())

format(var) = string(var)

function format(code::Expr, ::Val{:call})
    buffer = IOBuffer()

    nargs = length(code.args) - 1
    print(buffer, code.args[1], '(')
    if nargs > 0
        kwargs = Any[]
        semicolon_kwargs = Any[]
        # todo: make this a map and join
        for i = 2:nargs
            if expr_and_type(code.args[i], :parameters)
                # kwargs after a semicolon
                semicolon_kwargs = code.args[i].args
            elseif expr_and_type(code.args[i], :kw)
                push!(kwargs, code.args[i])
            else
                print(buffer, format(code.args[i]))
                print(buffer, ", ")
            end
        end
        if expr_and_type(code.args[end], :parameters)
            semicolon_kwargs = code.args[end].args
        elseif expr_and_type(code.args[end], :kw)
            push!(kwargs, code.args[end])
        else
            print(buffer, format(code.args[end]))
        end

        append!(kwargs, semicolon_kwargs)
        if !isempty(kwargs)
            print(buffer, "; ")
            print_joined(buffer, map(format, kwargs), ", ")
        end
    end
    print(buffer, ')')

    return takebuf_string(buffer)
end

function format(code::Expr, ::Val{:...})
    return "$(format(code.args[1]))..."
end

function format(code::Expr, ::Val{:kw})
    return "$(format(code.args[1]))=$(format(code.args[2]))"
end

end # module
