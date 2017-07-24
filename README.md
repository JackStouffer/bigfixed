# bigfixed

[![Build Status](https://travis-ci.org/kotet/bigfixed.svg?branch=master)](https://travis-ci.org/kotet/bigfixed)
[![Coverage Status](https://coveralls.io/repos/github/kotet/bigfixed/badge.svg)](https://coveralls.io/github/kotet/bigfixed)
[![DUB](https://img.shields.io/dub/v/bigfixed.svg)](https://code.dlang.org/packages/bigfixed)
[![DUB](https://img.shields.io/dub/dt/bigfixed.svg)](https://code.dlang.org/packages/bigfixed)

This module provides arbitrary precision fixed-point arithmetic.

```d
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
```

### Documentation

Run `dub fetch bigfixed && dub build bigfixed -b docs`.