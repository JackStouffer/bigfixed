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
    immutable size_t prec;
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
}
