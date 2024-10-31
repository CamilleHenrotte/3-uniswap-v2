// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MathLibrary {
    /// @notice Calculates the square root of a given number using the Babylonian method.
    /// @param y The number to calculate the square root of.
    /// @return z The calculated square root.
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // If y == 0, z will be 0 by default.
    }
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
