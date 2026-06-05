// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {MintManager} from "@app/MintManager.sol";
import {TestOPToken} from "@app/TestOPToken.sol";

contract runMintManager is Script {
    function run() public {
        uint256 privateKey = vm.envUint("WALLET_KEY");
        address caller = vm.addr(privateKey);

        address MintManagerAddress = address(0x676808E69f0327B669208Bf4CBFe6062b8b9479d); // MintManager for test token
        address opTokenAddress = address(0x353d79186D10eb63C022a0ACAb4aB61836cA1985); // Fresh test OP token
        address recipient = address(0x2bF2e447A5e57A5eEf79C3f12Ee865B4730e3a21);

        MintManager mintManager = MintManager(MintManagerAddress);
        TestOPToken opToken = TestOPToken(opTokenAddress);

        // Check current owners
        address mintManagerOwner = mintManager.owner();
        address opTokenOwner = opToken.owner();

        console.log("MintManager address:", MintManagerAddress);
        console.log("MintManager owner:", mintManagerOwner);
        console.log("Test OP Token owner:", opTokenOwner);
        console.log("Script caller:", caller);

        // Verify ownership is set up correctly
        require(opTokenOwner == MintManagerAddress, "Test OP token ownership not transferred to MintManager");
        require(mintManagerOwner == caller, "Caller is not the owner of MintManager");

        // Mint tokens
        console.log("Minting 1000 tokens to:", recipient);
        vm.startBroadcast(privateKey);
        mintManager.mint(recipient, 1000);
        vm.stopBroadcast();
        console.log("Mint successful!");
    }
}