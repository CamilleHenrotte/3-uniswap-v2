// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library FixedPointLibrary {
    uint224 constant Q112 = 2 ** 112;

    struct FixedPoint {
        uint112 integer;
        uint112 decimal;
    }

    function div(FixedPoint memory x, FixedPoint memory y) public pure returns (FixedPoint memory result) {
        uint256 quotient = ((x.integer * Q112 + x.decimal) * Q112) / (y.integer * Q112 + y.decimal);
        result = FixedPoint({integer: uint112(quotient / Q112), decimal: uint112(quotient % Q112)});
    }

    function mul(FixedPoint memory x, FixedPoint memory y) public pure returns (FixedPoint memory result) {
        uint256 product = ((x.integer * Q112 + x.decimal) * (y.integer * Q112 + y.decimal)) / Q112;
        result = FixedPoint({integer: uint112(product / Q112), decimal: uint112(product % Q112)});
    }

    function add(FixedPoint memory x, FixedPoint memory y) public pure returns (FixedPoint memory result) {
        uint256 xValue = uint256(x.integer) * Q112 + x.decimal;
        uint256 yValue = uint256(y.integer) * Q112 + y.decimal;
        uint256 sum;
        unchecked {
            sum = xValue + yValue;
        }
        result = FixedPoint({integer: uint112(sum / Q112), decimal: uint112(sum % Q112)});
    }
}
