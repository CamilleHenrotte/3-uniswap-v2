// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IUniswapV2Factory {
    /// @notice Emitted when a new pair is created.
    /// @param token0 The first token in the pair.
    /// @param token1 The second token in the pair.
    /// @param pair The address of the created pair.
    event PairCreated(address indexed token0, address indexed token1, address pair);

    /// @notice The address to which fees are sent.
    function feeTo() external view returns (address);

    /// @notice The address that can set the fee recipient address.
    function feeToSetter() external view returns (address);

    /// @notice Creates a new pair for the provided token addresses.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @return pair The address of the created pair.
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /// @notice Sets the address to which fees will be sent.
    /// @param _feeTo The address to set as the fee recipient.
    function setFeeTo(address _feeTo) external;

    /// @notice Sets the address that can modify the fee recipient.
    /// @param _feeToSetter The address to set as the fee setter.
    function setFeeToSetter(address _feeToSetter) external;
}
