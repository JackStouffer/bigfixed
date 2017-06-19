module bigfixed;

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
    BigFixed convertQ(size_t newQ) pure nothrow
    {
        if (this.Q != newQ)
        {
            sizediff_t diff = (cast(long) newQ) - this.Q;
            data <<= diff;
            this.Q = newQ;
        }
        return this;
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

        b.convertQ(5);
        assert(b == BigFixed(5, 5));

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

        auto b = this.data * (10 ^^ decimal_digits);
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
    @property BigFixed resolution()
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
    /// Implements bitwise assignment operators from BigInt of the form `BigFixed op= BigInt
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
}
