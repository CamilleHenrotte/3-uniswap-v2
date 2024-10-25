// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

library UniswapV2Library {
    // Sort tokens by address to ensure consistent ordering
    error UniswapV2Library_IdenticalAddresses();
    error UniswapV2Library_ZeroAddress();
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert UniswapV2Library_IdenticalAddresses();
        }
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert UniswapV2Library_ZeroAddress();
        }
    }

    // Calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address token0, address token1) public pure returns (address pair) {
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198f8fbbf785487aa39f430f63b76db002cb326e37da348845f7ab"
                        )
                    )
                )
            )
        );
    }
    function isContract(address _addr) public view returns (bool) {
        uint32 size;
        // Check if the address contains any code (i.e., if it's a contract)
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
