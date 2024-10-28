//SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./UniswapV2Pair.sol";

contract UniswapV2Factory {
    error UniswapV2Factory_Forbidden();
    error UniswapV2Factory_PairExists();
    address public feeTo;
    address public feeToSetter;

    event PairCreated(address indexed token0, address indexed token1, address pair);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pair = _pairFor(address(this), token0, token1);
        if (_isContract(pair)) {
            revert UniswapV2Factory_PairExists();
        } else {
            UniswapV2Pair(pair).initialize(token0, token1);
            emit PairCreated(token0, token1, pair);
        }
        return pair;
    }

    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) revert UniswapV2Factory_Forbidden();
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) revert UniswapV2Factory_Forbidden();
        feeToSetter = _feeToSetter;
    }
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert UniswapV2Library_IdenticalAddresses();
        }
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert UniswapV2Library_ZeroAddress();
        }
    }

    function _pairFor(address factory, address token0, address token1) internal pure returns (address pair) {
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
    function _isContract(address _addr) internal view returns (bool) {
        uint32 size;
        // Check if the address contains any code (i.e., if it's a contract)
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
