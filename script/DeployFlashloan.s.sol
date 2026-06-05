// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {ICreateX} from "createx-forge/script/ICreateX.sol";
import {MintManager} from "@app/MintManager.sol";
import {DeployUtils} from "./Lib/DeployUtils.sol";
// import {FlashLoanVault} from "@app/xChainEthLoan/FlashLoanVault.sol";
// import {FlashLoanHandler} from "@app/xChainEthLoan/FlashLoanHandler.sol";
// import {GovernanceToken} from "@app/xChainLoan/CrosschainFlashLoanToken.sol";
// import {CrosschainFlashLoanBridge} from "@app/xChainLoan/CrosschainFlashLoanBridge.sol";
// import {TargetContract} from "@app/TargetContract.sol";

// Example forge script for deploying as an alternative to sup: super-cli (https://github.com/ethereum-optimism/super-cli)
contract Deploy is Script {
    /// @notice Array of RPC URLs to deploy to, deploy to supersim 901 and 902 by default.
    string[] private rpcUrls = ["https://optimism-mainnet.infura.io/v3/c4e84f8357f144f2b340c6b402b40f0f"];
    
    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    function run() public {
        for (uint256 i = 0; i < rpcUrls.length; i++) {
            string memory rpcUrl = rpcUrls[i];

            console.log("Deploying to RPC: ", rpcUrl);
            vm.createSelectFork(rpcUrl);
            
            vm.startBroadcast(vm.envUint("WALLET_KEY"));
            //deployFlashLoanVault();

            deployMinter();
            vm.stopBroadcast();
            //deployCrosschainFlashLoanToken();
            //deployCrosschainFlashLoanBridge();
            //deployTargetContract();
        }
    }

    function deployMinter() public returns (address addr_) {
        address token = address(0x4200000000000000000000000000000000000042);
        address owner = address(0x2bF2e447A5e57A5eEf79C3f12Ee865B4730e3a21);
        bytes memory initCode =
            abi.encodePacked(type(MintManager).creationCode, abi.encode(owner, token));
        addr_ = DeployUtils.deployContract("MintManager", _implSalt(), initCode);
    }
    function deployCrosschainFlashLoanBridge() public returns (address addr_) {
        // Commented out to avoid version conflicts
        // address vault = 0xA210a1f794A76E28B79DfE9b6735161340efb89E;
        // bytes memory initCode = abi.encodePacked(type(FlashLoanHandler).creationCode, abi.encode(vault));
        // addr_ = DeployUtils.deployContract("FlashLoanHandler", _implSalt(), initCode);
        addr_ = address(0);
    }
   
    function deployFlashLoanVault() public returns (address addr_) {
        // Commented out to avoid version conflicts
        // bytes memory initCode = abi.encodePacked(type(FlashLoanVault).creationCode);
        // addr_ = DeployUtils.deployContract("FlashLoanVault", _implSalt(), initCode);
        addr_ = address(0);
    }
    /*
    function deployCrosschainFlashLoanToken() public broadcast returns (address addr_) {
        bytes memory initCode = abi.encodePacked(type(GovernanceToken).creationCode);
        addr_ = DeployUtils.deployContract("GovernanceToken", _implSalt(), initCode);
    }

    

    function deployTargetContract() public broadcast returns (address addr_) {
        bytes memory initCode = abi.encodePacked(type(TargetContract).creationCode);
        addr_ = DeployUtils.deployContract("TargetContract", _implSalt(), initCode);
    }
     */
    /// @notice The CREATE2 salt to be used when deploying a contract.
    function _implSalt() internal view returns (bytes32) {
        return keccak256(abi.encodePacked(vm.envOr("DEPLOY_SALT", string("ethers"))));
    }
   
}