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
    BigFixed convertQ(size_t newQ) nothrow
    {
        if (this.Q != newQ)
        {
            sizediff_t diff = (cast(long) newQ) - this.Q;
            data <<= diff;
            this.Q = newQ;
        }
        return this;
    }
    ///
    @system unittest
    {
        auto b = BigFixed(5, 10);

        b.convertQ(5);
        assert(b == BigFixed(5, 5));

        assert(b.convertQ(10) == BigFixed(5, 10));
        assert(b == BigFixed(5, 10));
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
        auto result = BigFixed(0,this.Q);
        result.data = 1;
        return result;
    }
    ///
    @system unittest
    {
        auto b1 = BigFixed(0,1).resolution;
        assert(b1.toDecimalString(1) == "0.5");

        auto b2 = BigFixed(100,1).resolution;
        assert(b2.toDecimalString(1) == "0.5");

        auto b3 = BigFixed(100,3).resolution;
        assert(b3.toDecimalString(3) == "0.125");
    }
}
