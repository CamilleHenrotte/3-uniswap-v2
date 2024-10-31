// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashBorrower is IERC3156FlashBorrower {
    address public lastInitiator;
    address public lastToken;
    uint256 public lastAmount;
    uint256 public lastFee;
    bytes public lastData;

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @notice Function called by the lender during the flash loan.
    /// @param initiator The address that initiated the loan
    /// @param token The address of the token being borrowed
    /// @param amount The amount of tokens borrowed
    /// @param fee The fee for the loan
    /// @param data Arbitrary data sent by the initiator
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        // Store loan information for test verification
        lastInitiator = initiator;
        lastToken = token;
        lastAmount = amount;
        lastFee = fee;
        lastData = data;

        // Approve the lender to withdraw the total amount (loan + fee)
        IERC20(token).approve(msg.sender, amount + fee);

        // Return the success callback signature to confirm loan handling
        return CALLBACK_SUCCESS;
    }
}
