// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {CreateXScript} from "createx-forge/script/CreateXScript.sol";
import {GovernanceToken} from "@app/xChainEthLoan/CrosschainGOpToken.sol";

contract DeployCrosschainGOpToken is CreateXScript {
    function run() public withCreateX {
        uint256 privateKey = vm.envUint("WALLET_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deploying CrosschainGOpToken from:", deployer);

        vm.startBroadcast(privateKey);
        bytes32 salt = keccak256(abi.encodePacked("CrosschainGOpToken", block.timestamp));
        bytes memory initCode = type(GovernanceToken).creationCode;
        address tokenAddress = create3(salt, initCode);
        vm.stopBroadcast();

        GovernanceToken token = GovernanceToken(payable(tokenAddress));

        console.log("CrosschainGOpToken deployed at:", address(token));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
    }
}