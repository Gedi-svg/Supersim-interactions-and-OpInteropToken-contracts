// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import { IERC20 } from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
interface IFlashBorrower {
    /**
     * @param amount The amount of tokens lent.
     * @param flashLoanHandlerAddress the address of the flashLoanHandler contract.
     */
    function onFlashLoan(uint256 amount, address flashLoanHandlerAddress, bytes memory userData) external payable;
    /*
    function onBuy(address srcToken, uint256 amount, address flashLoanHandlerAddress, bytes memory userData) external payable returns (IERC20, uint256);
    function onSell(uint256 amount, address flashLoanHandlerAddress, bytes memory userData) external payable returns (IERC20, uint256);
    */
    receive() external payable;
}