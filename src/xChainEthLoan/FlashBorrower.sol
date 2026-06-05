// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TradeContract} from "./VDummyContract.sol";
import {GovernanceToken} from "./CrosschainGOpToken.sol";
import {IFlashBorrower} from "./InterfaceFlashBorrower.sol";
import {FlashLoanHandler} from "./FlashLoanHandler.sol";
import { IERC20 } from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract FlashBorrower is IFlashBorrower {
    address public immutable flashLoanHandler; // Security: lock to your handler
    TradeContract public immutable tradeContract;

    constructor(address _tradeContractAddress, address _flashLoanHandler) {
        tradeContract = TradeContract(payable(_tradeContractAddress));
        flashLoanHandler = _flashLoanHandler;
    }

    function onFlashLoan(
        uint256 amount, 
        address flashLoanHandlerAddress, 
        bytes calldata userData // Changed to calldata for gas savings
    ) external payable override {
        // Security Check
        require(msg.sender == flashLoanHandler, "Only Handler");
        require(flashLoanHandlerAddress == flashLoanHandler, "Invalid Handler Address");

        // 1. Run the trade
        executeArbitrage(amount, userData);

        // 2. Return everything (Loan + Profit)
        uint256 totalToReturn = address(this).balance;
        (bool success, ) = payable(flashLoanHandler).call{value: totalToReturn}("");
        require(success, "Failed to return funds");
    }

    function executeArbitrage(uint256 ethAmount, bytes calldata userData) private {
        // No need to check balance here; onFlashLoan is 'payable', 
        // so the ethAmount is already in the balance.
        tradeContract.arbitrageIn{value: ethAmount}(userData);
    }

    receive() external payable {}
}



