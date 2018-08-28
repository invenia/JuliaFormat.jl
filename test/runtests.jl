using JuliaFormat
if VERSION >= v"0.7-"
    using Test
else
    using BaseTestNext
    const Test = BaseTestNext
end

@testset "in == out" begin
    same_strs = [
        "",
        "sum()",
        "foo(a, b)",
        "bar(x...)",
        "baz(x; y=3)",
        "foo(a, b, c...; x=3, y=foo(a, b, c; x=3, y=1))",
        "foobar(a, b, c...)\nx(x)",
        "+a",
        "sum(+a, -b, ~c, !d)",
        "a + b",
        "a + b + c",
        "a + b + c + d + e + f + g",
        "+(a, b...)",
        "/(a, b...)",
        "+(a, b, c...)",
        "/(a, b, c...)",
        "100x + 3y + 1",
        "100 + 3 / 4 - 10",
        "(3 + 4) * 5",
        "3 // 4",
        "x = 3",
        "x += 3",
        "x -= 3",
        "x /= 3",
        "x *= 3",
        "x ÷= 3",
        "x \\= 3",
        "x &= 3",
        "x |= 3",
        "x ^= 3",
        "x \$= 3",
        "x %= 3",
        "x //= 3",
        "x <<= 3",
        "x >>= 3",
        "x >>>= 3",
        "x := 3",
        "x .*= 3",
        "x .+= 3",
        "x ./= 3",
        "x .-= 3",
        "x .÷= 3",
        "x .\\= 3",
        "x .^= 3",
        "x .%= 3",
        "x = ((4 + 2) ^ 2 * 4 - 9) * 10",
        "x, y = (4, 5)",
        "using Foo",
        "import Foo",
        "import Foo: bar",
        "0x1010",
        "x::Int64",
        "foo::Union{Int64, Float64}",
        "abstract Foo{T} <: Bar{T, Int64}",
        "100000.0",
        "a <= b",
        "b > c",
        "foo ∈ bar",
        "foo ⊂ bar",
        "typealias Foo Union{Bar, Baz}",
        "typealias Foo{T} Bar{T}",
        "const foo = bar",
        "local foo",
        "local foo = bar",
        "global foo",
        "global foo = bar",
        "Dict{Foo, Bar}('a' => 3, 'b' => 1.0)",
        "1:4",
        "1:4:5",
        "\$foobar",
        "\$(foo * bar)",
        "Foo.bar",
        "Foo.(bar)",
        "Foo.(bar * baz)",
        "[1, \"2\", '3', 4.0, 25 // 5]",
        "{1, \"2\", '3', 4.0, 25 // 5}",
        "[1 \"2\" '3' 4.0 25 // 5]",
        "[1; \"2\"; '3'; 4.0; 25 // 5]",
        "[1 \"2\"; '3' 4.0]",
        "{1 \"2\"; '3' 4.0}",
        "ASCIIString[1; \"2\"; '3'; 4.0; 25 // 5]",
        "typeof(3)[1 \"2\"; '3' 4.0]",
        "ASCIIString[1, \"2\", '3', 4.0]",
        "typeof(3)[1, \"2\", '3', 4.0]",
        "foo[1, \"2\", '3', 4.0]",
        "(foo + 1)[1, \"2\", '3', 4.0]",
        "foo < bar || foo > bar && foo != bar"
    ]

    for same_str in same_strs
        @test same_str == format_code(same_str)
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
        ("baz( ;x =3)", "baz(; x=3)"),
        ("1 : 4 : 5", "1:4:5"),
        ("3//4", "3 // 4")
    ]

    for (code_in, code_out) in code_pairs
        @test code_out == format_code(code_in)
    end
end

@testset "transformations" begin
    code_pairs = [
        ("foo(a=3, b=4)", "foo(; a=3, b=4)"),
        ("foo(a=3; b=4)", "foo(; a=3, b=4)"),
        ("2x^2 + 3x + 1", "2 * x ^ 2 + 3x + 1"),
        ("(x, y) = 4, 5", "x, y = (4, 5)"),
        ("1e6", "1.0e6"),
        ("100e6", "1.0e8"),
        ("1000000.0", "1.0e6"),
        ("1000000.0000001", "1.0000000000001e6"),
        ("\$(foo)", "\$foo"),
        ("(foo)[1, \"2\", '3', 4.0]", "foo[1, \"2\", '3', 4.0]")
    ]

    for (code_in, code_out) in code_pairs
        @test code_out == format_code(code_in)
    end
end
