// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {FlashLoanHandler} from  "@app/xChainEthLoan/FlashLoanHandler.sol";
import {FlashLoanVault} from "@app/xChainEthLoan/FlashLoanVault.sol";
import {Script, console} from "forge-std/Script.sol";
import { IERC20 } from "../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract receiveLoan is Script{
function run() external {
    FlashLoanVault fv = FlashLoanVault(payable(address(0xA210a1f794A76E28B79DfE9b6735161340efb89E)));
    FlashLoanHandler fh10 = new FlashLoanHandler(payable(address(fv)));
    //FlashLoanHandler fh8453;
    //vm.startBroadcast(vm.envUint("WALLET_KEY"));
    vm.deal(address(fh10), 1e18);
    address token = address(0x4200000000000000000000000000000000000006);
    IERC20(token).approve(address(fh10), 1e18);
    
    fh10.initiateCrosschainFlashLoan(8453, 1e18, address(fh10), "");
    /*
    fh10.recieveEthForArbitrageSourceChain(
        8453,
        address(fv),
        1e18,
        "",
        payable(address(0x89530565a4Fb09E38fD320C84bf02d3dd8a3b2e1)),
        ""
    );

    */
    vm.createSelectFork("https://base-mainnet.infura.io/v3/c4e84f8357f144f2b340c6b402b40f0f");
    bytes32 sendERC20MsgHash = 0x5fee8d4e85220962c6825e392b320a2fccc612285cd4ae2c37e6f0c0aa078cb4;

    fh10.executeCrosschainFlashLoan(sendERC20MsgHash, 10, address(fh10),  1e18, address(fh10));
   // vm.stopBroadcast();
}

}