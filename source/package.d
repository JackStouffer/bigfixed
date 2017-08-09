/// This module provides arbitrary precision fixed-point arithmetic.
module bigfixed;
///
@system unittest
{
    // Return the square root of `n` to `prec` decimal places by a method of bisection.
    string sqrt(ulong n, size_t prec)
    {
        import std.conv : to;
        import std.math : ceil, log10;

        immutable size_t q = (prec / log10(2.0)).ceil.to!size_t() + 1;
        auto low = BigFixed(0, q);
        auto high = BigFixed(n, q);

        while ((high - low) != high.resolution) // BigFixed is integer internally.
        {
            immutable BigFixed mid = (high + low) >> 1; // Shift Expressions can be used.
            immutable bool isLess = (mid * mid) < n;
            if (isLess)
            {
                low = mid;
            }
            else
            {
                high = mid;
            }
        }
        return low.toDecimalString(prec);
    }
    // 10 digits before the 1,000th digit. See http://www.h2.dion.ne.jp/~dra/suu/chi2/heihoukon/2.html
    immutable sqrt2_tail = "9518488472";
    assert(sqrt(2, 1000)[$ - 10 .. $] == sqrt2_tail);
}

import std.bigint : BigInt;
import std.traits : isIntegral;

/**
    A struct representing Fixed point number.
*/
struct BigFixed
{
private:
    BigInt data;
    size_t Q;
public:
    /// Construct BigFixed from a built-in integral type
    this(T)(T x, size_t Q) pure nothrow if (isIntegral!T)
    {
        data = BigInt(x);
        this.Q = Q;
        data <<= this.Q;
    }
    /// Construct BigFixed from BigInt
    this(T : BigInt)(T x, size_t Q) pure nothrow
    {
        data = BigInt(x);
        this.Q = Q;
        data <<= this.Q;
    }
    ///
    @system unittest
    {
        immutable ulong i = ulong.max;
        immutable bfi1 = BigFixed(i, 10);
        immutable bfi2 = BigFixed(BigInt(ulong.max), 10);
        assert(bfi1 == bfi2);
    }

    ///
    BigFixed convertQ(size_t newQ) pure nothrow const
    {
        if (this.Q != newQ)
        {
            BigFixed b = this;
            sizediff_t diff = (cast(long) newQ) - b.Q;
            b.data <<= diff;
            b.Q = newQ;
            return b;
        }
        else
        {
            return this;

        }
    }
    /// the number of fractional bits
    @property size_t fractional_bits() pure nothrow
    {
        return this.Q;
    }
    ///
    @system unittest
    {
        auto b = BigFixed(5, 10);

        assert(b.convertQ(10) == BigFixed(5, 10));
        assert(b.fractional_bits == 10);
    }

    /// Assignment from built-in integer types
    BigFixed opAssign(T)(T x) pure nothrow if (isIntegral!T)
    {
        data = BigInt(x);
        data <<= this.Q;
        return this;
    }
    ///
    @system unittest
    {
        auto b = BigFixed(5, 10);
        b = 2;
        assert(b == BigFixed(2, 10));
    }

    /// Assignment from another BigFixed
    BigFixed opAssign(T : BigFixed)(T x) pure @nogc
    {
        data = x.data;
        this.Q = x.Q;
        return this;
    }
    ///
    @system unittest
    {
        immutable b1 = BigFixed(123, 5);
        auto b2 = BigFixed(456, 10);
        b2 = b1;
        assert(b2 == BigFixed(123, 5));
    }

    /// Convert the BigFixed to string
    string toDecimalString(size_t decimal_digits)
    {
        import std.conv : to;
        import std.string : rightJustify;

        auto b = this.data * (BigInt(10) ^^ decimal_digits);
        b >>= this.Q;
        immutable str = b.to!string;
        immutable sign = (this.data < 0) ? "-" : "";
        immutable begin = sign.length;
        if (str.length - begin <= decimal_digits)
        {
            return sign ~ "0." ~ rightJustify(str[begin .. $], decimal_digits, '0');
        }
        else
        {
            return sign ~ str[begin .. $ - decimal_digits] ~ "." ~ str[$ - decimal_digits .. $];
        }
    }

    /// Minimum number that can be represented greater than 0
    @property BigFixed resolution() pure const nothrow
    {
        auto result = BigFixed(0, this.Q);
        result.data = 1;
        return result;
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(0, 1).resolution;
        assert(b1.toDecimalString(1) == "0.5");

        auto b2 = BigFixed(100, 1).resolution;
        assert(b2.toDecimalString(1) == "0.5");

        auto b3 = BigFixed(100, 3).resolution;
        assert(b3.toDecimalString(3) == "0.125");
    }
    /// Implements assignment operators from BigFixed of the form `BigFixed op= BigFixed`
    BigFixed opOpAssign(string op, T : BigFixed)(T y) pure nothrow 
            if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        static if (op == "+" || op == "-")
        {
            (this.data).opOpAssign!op(y.convertQ(this.Q).data);
        }
        else static if (op == "*")
        {
            this.data *= y.convertQ(this.Q).data;
            this.data >>= this.Q;
        }
        else static if (op == "/")
        {
            this.data <<= this.Q;
            this.data /= y.convertQ(this.Q).data;
        }
        else
            static assert(0, "BigFixed " ~ op[0 .. $ - 1] ~ "= " ~ T.stringof ~ " is not supported");
        return this;
    }

    @system unittest
    {
        auto b1 = BigFixed(1, 10);
        b1 /= BigFixed(4, 10);
        assert(b1.toDecimalString(2) == "0.25");
        b1 += BigFixed(1, 0);
        assert(b1.toDecimalString(2) == "1.25");
        b1 *= BigFixed(2, 5);
        assert(b1.toDecimalString(2) == "2.50");
        b1 -= BigFixed(1, 0);
        assert(b1.toDecimalString(2) == "1.50");
    }
    /// Implements assignment operators from built-in integers of the form `BigFixed op= Integer`
    BigFixed opOpAssign(string op, T)(T y) pure nothrow 
            if ((op == "+" || op == "-" || op == "*" || op == "/" || op == ">>"
                || op == "<<" || op == "|" || op == "&" || op == "^") && isIntegral!T)
    {
        static if (op == "+" || op == "-")
        {
            (this.data).opOpAssign!op(BigInt(y) << this.Q);
        }
        else static if (op == "*" || op == "/" || op == ">>" || op == "<<"
                || op == "|" || op == "&" || op == "^")
        {
            (this.data).opOpAssign!op(y);
        }
        else
            static assert(0, "BigFixed " ~ op[0 .. $ - 1] ~ "= " ~ T.stringof ~ " is not supported");
        return this;
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(1, 10);
        b1 /= 4;
        assert(b1.toDecimalString(2) == "0.25");
        b1 += 1;
        assert(b1.toDecimalString(2) == "1.25");
        b1 *= 2;
        assert(b1.toDecimalString(2) == "2.50");
        b1 -= 1;
        assert(b1.toDecimalString(2) == "1.50");
        b1 <<= 1;
        assert(b1.toDecimalString(2) == "3.00");
        b1 >>= 2;
        assert(b1.toDecimalString(2) == "0.75");
        b1 |= (1 << 5);
        assert(b1.toDecimalString(5) == "0.78125");
        b1 &= (1 << 5);
        assert(b1.toDecimalString(5) == "0.03125");
        b1 ^= (1 << 5);
        assert(b1.toDecimalString(5) == "0.00000");
    }
    /// Implements bitwise assignment operators from BigInt of the form `BigFixed op= BigInt`
    BigFixed opOpAssign(string op, T : BigInt)(T y) pure nothrow 
            if (op == "+" || op == "-" || op == "*" || op == "/" || op == "|" || op == "&"
                || op == "^")
    {
        static if (op == "+" || op == "-")
        {
            (this.data).opOpAssign!op(y << this.Q);
        }
        else static if (op == "*" || op == "/" || op == "|" || op == "&" || op == "^")
        {
            (this.data).opOpAssign!op(y);
        }
        else
            static assert(0, "BigFixed " ~ op[0 .. $ - 1] ~ "= " ~ T.stringof ~ " is not supported");
        return this;
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(1, 10);
        b1 /= BigInt(4);
        assert(b1.toDecimalString(2) == "0.25");
        b1 += BigInt(1);
        assert(b1.toDecimalString(2) == "1.25");
        b1 *= BigInt(2);
        assert(b1.toDecimalString(2) == "2.50");
        b1 -= BigInt(1);
        assert(b1.toDecimalString(2) == "1.50");
        b1 |= BigInt(1 << 5);
        assert(b1.toDecimalString(5) == "1.53125");
        b1 &= BigInt(1 << 5);
        assert(b1.toDecimalString(5) == "0.03125");
        b1 ^= BigInt(1 << 5);
        assert(b1.toDecimalString(5) == "0.00000");
    }
    /// Implements binary operators between BigFixed
    BigFixed opBinary(string op, T : BigFixed)(T y) pure nothrow const 
            if (op == "+" || op == "*" || op == "-" || op == "/")
    {
        BigFixed r = this;
        return r.opOpAssign!(op)(y);
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(1, 10);
        assert((b1 / BigFixed(4, 10)).toDecimalString(2) == "0.25");
        assert((b1 + BigFixed(2, 10)).toDecimalString(2) == "3.00");
        assert((b1 * BigFixed(2, 10)).toDecimalString(2) == "2.00");
        assert((b1 - BigFixed(1, 10)).toDecimalString(2) == "0.00");
    }
    /// Implements binary operators between BigInt
    BigFixed opBinary(string op, T : BigInt)(T y) pure nothrow const 
            if (op == "|" || op == "&" || op == "^")
    {
        BigFixed r = this;
        return r.opOpAssign!(op)(y);
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(1, 10);
        assert((b1 | (BigInt(1) << 9)).toDecimalString(2) == "1.50");
        assert((b1 & (BigInt(1) << 9)).toDecimalString(2) == "0.00");
        assert((b1 ^ (BigInt(1) << 9)).toDecimalString(2) == "1.50");
    }
    /// Implements binary operators between Integer
    BigFixed opBinary(string op, T)(T y) pure nothrow const 
            if ((op == "+" || op == "-" || op == "*" || op == "/" || op == ">>"
                || op == "<<" || op == "|" || op == "&" || op == "^") && isIntegral!T)
    {
        BigFixed r = this;
        return r.opOpAssign!(op)(y);
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(1, 10);
        assert((b1 + 1).toDecimalString(2) == "2.00");
        assert((b1 - 1).toDecimalString(2) == "0.00");
        assert((b1 * 2).toDecimalString(2) == "2.00");
        assert((b1 / 2).toDecimalString(2) == "0.50");
        assert((b1 >> 1).toDecimalString(2) == "0.50");
        assert((b1 << 1).toDecimalString(2) == "2.00");
        assert((b1 | (1 << 9)).toDecimalString(2) == "1.50");
        assert((b1 & 1).toDecimalString(2) == "0.00");
        assert((b1 ^ (1 << 9)).toDecimalString(2) == "1.50");
    }
    /// Implements binary operators of the form `Integer op BigFixed`
    BigFixed opBinaryRight(string op, T)(T y) pure nothrow const 
            if ((op == "+" || op == "*" || op == "|" || op == "&" || op == "^") && isIntegral!T)
    {
        return this.opBinary!(op)(y);
    }
    /// ditto
    BigFixed opBinaryRight(string op, T)(T y) pure nothrow 
            if ((op == "-" || op == "/") && isIntegral!T)
    {
        return BigFixed(y, this.Q).opBinary!(op)(this);
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(1, 10);
        assert((1 + b1).toDecimalString(2) == "2.00");
        assert((1 - b1).toDecimalString(2) == "0.00");
        assert((2 * b1).toDecimalString(2) == "2.00");
        assert((2 / b1).toDecimalString(2) == "2.00");
        assert(((1 << 9) | b1).toDecimalString(2) == "1.50");
        assert((1 & b1).toDecimalString(2) == "0.00");
        assert(((1 << 9) ^ b1).toDecimalString(2) == "1.50");
    }
    /// Implements BigFixed equality test
    bool opEquals()(auto ref const BigFixed y) const pure @nogc
    {
        return (this.data == y.data) && (this.Q == y.Q);
    }
    ///
    @system unittest
    {
        auto x = BigFixed(1, 10) / 2;
        auto y = BigFixed(5, 10) / 2;
        assert(x == x);
        assert(x != y);
        assert((x + 2) == y);
    }
    /** Implements 3-way comparisons of BigFixed with BigFixed
        or BigFixed with built-in integers.
    **/
    int opCmp(ref const BigFixed y) pure nothrow const
    {
        return this.data.opCmp(y.convertQ(this.Q).data);
    }
    /// ditto
    int opCmp(T)(T y) pure nothrow const if (isIntegral!T)
    {
        return this.data.opCmp(BigInt(y) << this.Q);
    }
    ///
    @system unittest
    {
        immutable x = BigFixed(100, 10);
        immutable y = BigFixed(10, 10);
        immutable int z = 50;
        const int w = 200;

        assert(y < x);
        assert(x > z);
        assert(z > y);
        assert(x < w);
    }
    /// Implement toHash so that BigFixed works properly as an AA key.
    size_t toHash() const @safe nothrow
    {
        return this.data.toHash() + this.Q;
    }
    ///
    @safe unittest
    {
        string[BigFixed] aa;
        aa[BigFixed(123, 10)] = "abc";
        aa[BigFixed(456, 10)] = "def";
        aa[BigFixed(456, 5)] = "ghi";

        assert(aa[BigFixed(123, 10)] == "abc");
        assert(aa[BigFixed(456, 10)] == "def");
        assert(aa[BigFixed(456, 5)] == "ghi");
    }
    /// Implements BigFixed unary operators.
    BigFixed opUnary(string op)() pure nothrow const 
            if (op == "+" || op == "-" || op == "~")
    {
        static if (op == "+")
        {
            return this;
        }
        else static if (op == "-")
        {
            BigFixed r = this;
            r.data = -r.data;
            return r;
        }
        else static if (op == "~")
        {
            BigFixed r = this;
            r.data = ~r.data;
            return r;
        }
    }
    ///
    @system unittest
    {
        immutable x = BigFixed(1, 10) / 2;

        assert(+x == x);
        assert(-x == BigFixed(-1, 10) / 2);
        assert(~x == -x - x.resolution);
    }
}
