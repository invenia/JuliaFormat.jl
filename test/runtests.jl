using JuliaFormat
using Base.Test

@testset "in == out" begin
    same_strs = [
        "sum()",
        "foo(a, b)",
        "bar(x...)",
        "baz(x; y=3)",
        "foobar(a, b, c...)\nx(x)"
    ]

    for same_str in same_strs
        @test same_str == format(same_str)
    end
end

@testset "whitespace" begin
    code_pairs = [
        ("sum( )", "sum()"),
        ("foo(a,b)", "foo(a, b)"),
        ("foo( a, b )", "foo(a, b)"),
        ("bar(x ...)", "bar(x...)"),
        ("bar(x... )", "bar(x...)"),
        ("baz(x;y=3)", "baz(x; y=3)"),
        ("baz(x ; y = 3)", "baz(x; y=3)"),
        ("baz( ;x =3)", "baz(; x=3)")
    ]

    for (code_in, code_out) in code_pairs
        @test code_out == format(code_in)
    end
end

@testset "transformations" begin
    code_pairs = [
        ("foo(a=3, b=4)", "foo(; a=3, b=4)"),
        ("foo(a=3; b=4)", "foo(; a=3, b=4)")
    ]

    for (code_in, code_out) in code_pairs
        @test code_out == format(code_in)
    end
end
