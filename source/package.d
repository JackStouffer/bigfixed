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
    size_t prec;
public:
    /// Construct BigFixed from a built-in integral type
    this(T)(T x, size_t precision) pure nothrow if (isIntegral!T)
    {
        data = BigInt(x);
        prec = precision;
        data <<= prec;
    }
    /// Construct BigFixed from BigInt
    this(T : BigInt)(T x, size_t precision) pure nothrow
    {
        data = BigInt(x);
        prec = precision;
        data <<= prec;
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
    BigFixed convertPrecision(size_t newprecision) nothrow
    {
        long diff = (cast(long) newprecision) - prec;
        data <<= diff;
        prec = newprecision;
        return this;
    }
    ///
    @system unittest
    {
        auto b = BigFixed(5, 10);

        b.convertPrecision(5);
        assert(b == BigFixed(5, 5));

        assert(b.convertPrecision(10) == BigFixed(5, 10));
        assert(b == BigFixed(5, 10));
    }

    /// Assignment from built-in integer types
    BigFixed opAssign(T)(T x) pure nothrow if (isIntegral!T)
    {
        data = BigInt(x);
        data <<= prec;
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
        prec = x.prec;
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
}
