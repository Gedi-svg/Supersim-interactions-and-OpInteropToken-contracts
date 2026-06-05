// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {FlashLoanHandler} from "@app/xChainEthLoan/FlashLoanHandler.sol";
import { IERC20 } from "../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ParaswapSwapScript is Script {
    using stdJson for string;
    int constant CHAIN_ID = 10; 
    uint256 constant destinationChain = 8453; // Base
    string constant SWAP_URL = "https://api.paraswap.io/swap";
    string constant PRICES_URL = "https://api.paraswap.io/prices";
    string constant TX_BUILDER_URL = "https://api.paraswap.io/transactions/{CHAIN_ID}"; // 137 = Polygon
    string constant TOKENS_LIST_URL = "https://api.paraswap.io/tokens/{CHAIN_ID}";
    string constant TX_BUILDER_SWAP_OBJ_URL = "https://api.paraswap.io/swap";
    address srcToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address destToken = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address WETH = 0x4200000000000000000000000000000000000006;
    address OP_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address BA_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 amount = 1 ether;
    address userAddress = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant flashLoanHandlerAddress = 0x0000000000000000000000000000000000000000; // Placeholder: replace with actual address
    address constant flashBorrowerAddress = 0x0000000000000000000000000000000000000000; // Placeholder: replace with actual address

    struct GenericData {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
    }
    struct ArbitrageData {
        bool _isArbitrageIn;
        address executor;
        GenericData swapData;
        uint256 partnerAndFee;
        bytes permit;
        bytes executorData;
        address executor_out;
        GenericData swapData_out;
        uint256 partnerAndFee_out;
        bytes permit_out;
        bytes executorData_out;
        uint256 deadline;
    }
    struct ArbitrageDataSell {
        address executor;
        GenericData swapData;
        uint256 partnerAndFee;
        bytes permit;
        bytes executorData;
        uint256 deadline;
    }
    struct ArbitrageDataBuy {
        address executor_out;
        GenericData swapData_out;
        uint256 partnerAndFee_out;
        bytes permit_out;
        bytes executorData_out;
        uint256 deadline;
    }

    function extractCallData(string memory txJson) internal pure returns (bytes memory) {
        return vm.parseBytes(txJson.readString("[4]"));
    }
    function run() external {
        // Fetch buy data
        string[] memory cmd = new string[](3);
        cmd[0] = "curl";
        cmd[1] = "-s";
        cmd[2] = string.concat(SWAP_URL, "?srcToken=", vm.toString(WETH), "&destToken=", vm.toString(OP_USDC), "&amount=", vm.toString(amount), "&userAddress=", vm.toString(userAddress), "&srcDecimals=18&destDecimals=6&side=SELL&network=10&version=6.2&slippage=100");
        string memory json = string(vm.ffi(cmd));
        vm.writeJson(json, "./tx_data/swap_data.json");
        uint256 sellAmt = json.readUint(".priceRoute.destAmount");

        // Extract priceRoute
        cmd[2] = string.concat("$data = '", json, "' | ConvertFrom-Json; $data.priceRoute | ConvertTo-Json -Depth 20 -Compress");
        cmd[0] = "powershell";
        cmd[1] = "-Command";
        string memory route = string(vm.ffi(cmd));

        // Extract gasPrice
        cmd[2] = string.concat("$data = '", json, "' | ConvertFrom-Json; $data.txParams.gasPrice");
        string memory gasP = string(vm.ffi(cmd));

        // Build post body
        string memory body = string(abi.encodePacked('{"srcToken":"', vm.toString(WETH), '","destToken":"', vm.toString(OP_USDC), '","srcAmount":"', vm.toString(amount), '","destAmount":', vm.toString(sellAmt), ',"userAddress":"', vm.toString(userAddress), '","gasPrice":"', gasP, '","priceRoute":', route, ',"srcDecimals":18,"destDecimals":6,"deadline":', vm.toString(block.timestamp + 300), ',"partner":"ArbieOptimizer","ignoreChecks":true,"onlyParams":true}'));

        // Build TX
        cmd = new string[](9);
        cmd[0] = "curl";
        cmd[1] = "-s";
        cmd[2] = "-X";
        cmd[3] = "POST";
        cmd[4] = "-H";
        cmd[5] = "Content-Type: application/json";
        cmd[6] = "--data";
        cmd[7] = body;
        cmd[8] = string.concat("https://api.paraswap.io/transactions/", vm.toString(CHAIN_ID));
        string memory txJson = string(vm.ffi(cmd));
        vm.writeJson(txJson, "./tx_data/built_tx.json");

        // Fetch sell data
        cmd = new string[](3);
        cmd[0] = "curl";
        cmd[1] = "-s";
        cmd[2] = string.concat(SWAP_URL, "?srcToken=", vm.toString(OP_USDC), "&destToken=", vm.toString(WETH), "&amount=", vm.toString(sellAmt), "&userAddress=", vm.toString(userAddress), "&srcDecimals=6&destDecimals=18&side=SELL&network=10&version=6.2&slippage=100");
        string memory jsonSell = string(vm.ffi(cmd));
        vm.writeJson(jsonSell, "./tx_data/swap_data_sell.json");
        uint256 sellAmtSell = jsonSell.readUint(".priceRoute.destAmount");

        // Extract priceRoute sell
        cmd[2] = string.concat("$data = '", jsonSell, "' | ConvertFrom-Json; $data.priceRoute | ConvertTo-Json -Depth 20 -Compress");
        cmd[0] = "powershell";
        cmd[1] = "-Command";
        string memory routeSell = string(vm.ffi(cmd));

        // Extract gasPrice sell
        cmd[2] = string.concat("$data = '", jsonSell, "' | ConvertFrom-Json; $data.txParams.gasPrice");
        string memory gasPSell = string(vm.ffi(cmd));

        // Build post body sell
        string memory bodySell = string(abi.encodePacked('{"srcToken":"', vm.toString(OP_USDC), '","destToken":"', vm.toString(WETH), '","srcAmount":"', vm.toString(sellAmt), '","destAmount":', vm.toString(sellAmtSell), ',"userAddress":"', vm.toString(userAddress), '","gasPrice":"', gasPSell, '","priceRoute":', routeSell, ',"srcDecimals":6,"destDecimals":18,"deadline":', vm.toString(block.timestamp + 300), ',"partner":"ArbieOptimizer","ignoreChecks":true,"onlyParams":true}'));

        // Build TX sell
        cmd = new string[](9);
        cmd[0] = "curl";
        cmd[1] = "-s";
        cmd[2] = "-X";
        cmd[3] = "POST";
        cmd[4] = "-H";
        cmd[5] = "Content-Type: application/json";
        cmd[6] = "--data";
        cmd[7] = bodySell;
        cmd[8] = string.concat("https://api.paraswap.io/transactions/", vm.toString(CHAIN_ID));
        string memory txJsonSell = string(vm.ffi(cmd));
        vm.writeJson(txJsonSell, "./tx_data/built_tx_sell.json");

        // Optional: simulate running the sell on the destination chain by forking a RPC and warping
        // Provide DEST_FORK_RPC (e.g. an archive RPC URL) and optional DEST_FORK_BLOCK via environment.
        // Example env: DEST_FORK_RPC=https://.../ DEST_FORK_BLOCK=17000000
        string memory destRpc = vm.envOr("DEST_FORK_RPC", string(""));
        if (bytes(destRpc).length > 0) {
            uint256 original = vm.activeFork();
            uint256 forkId = vm.createFork(destRpc);
            vm.selectFork(forkId);
            // optional block override
            uint256 forkBlock = vm.envOr("DEST_FORK_BLOCK", block.number);
            // set block number and timestamp forward slightly to simulate "later" execution
            vm.roll(forkBlock);
            vm.warp(block.timestamp + 30);

            // At this point the script is running on the destination-chain fork.
            // You can perform the second sell here (call contracts on the fork) using vm.startBroadcast()/stopBroadcast().

            // switch back to original fork
            vm.selectFork(original);
        }

        // Construct data
        bytes memory dataBuy = abi.encode(ArbitrageDataBuy({
            executor_out: txJson.readAddress("[0]"),
            swapData_out: GenericData({
                srcToken: IERC20(txJson.readAddress("[1][0]")),
                destToken: IERC20(txJson.readAddress("[1][1]")),
                fromAmount: txJson.readUint("[1][2]") * 10001 / 10000,
                toAmount: txJson.readUint("[1][3]"),
                quotedAmount: txJson.readUint("[1][4]"),
                metadata: bytes32(txJson.readUint("[1][5]")),
                beneficiary: payable(userAddress)
            }),
            partnerAndFee_out: txJson.readUint("[2]"),
            permit_out: vm.parseBytes(txJson.readString("[3]")),
            executorData_out: vm.parseBytes(txJson.readString("[4]")),
            deadline: block.timestamp + 300
        }));

        bytes memory dataSell = abi.encode(ArbitrageDataSell({
            executor: txJsonSell.readAddress("[0]"),
            swapData: GenericData({
                srcToken: IERC20(txJsonSell.readAddress("[1][0]")),
                destToken: IERC20(txJsonSell.readAddress("[1][1]")),
                fromAmount: txJsonSell.readUint("[1][2]") * 10001 / 10000,
                toAmount: txJsonSell.readUint("[1][3]"),
                quotedAmount: txJsonSell.readUint("[1][4]"),
                metadata: bytes32(txJsonSell.readUint("[1][5]")),
                beneficiary: payable(userAddress)
            }),
            partnerAndFee: txJsonSell.readUint("[2]"),
            permit: vm.parseBytes(txJsonSell.readString("[3]")),
            executorData: vm.parseBytes(txJsonSell.readString("[4]")),
            deadline: block.timestamp + 300
        }));
        bytes memory data = abi.encode(ArbitrageData({
            _isArbitrageIn: true,
            executor: txJsonSell.readAddress("[0]"),
            swapData: GenericData({
                srcToken: IERC20(txJsonSell.readAddress("[1][0]")),
                destToken: IERC20(txJsonSell.readAddress("[1][1]")),
                fromAmount: txJsonSell.readUint("[1][2]") * 10001 / 10000,
                toAmount: txJsonSell.readUint("[1][3]"),
                quotedAmount: txJsonSell.readUint("[1][4]"),
                metadata: bytes32(txJsonSell.readUint("[1][5]")),
                beneficiary: payable(userAddress)
            }),
            partnerAndFee: txJsonSell.readUint("[2]"),
            permit: vm.parseBytes(txJsonSell.readString("[3]")),
            executorData: vm.parseBytes(txJsonSell.readString("[4]")),
            executor_out: txJson.readAddress("[0]"),
            swapData_out: GenericData({
                srcToken: IERC20(txJson.readAddress("[1][0]")),
                destToken: IERC20(txJson.readAddress("[1][1]")),
                fromAmount: txJson.readUint("[1][2]") * 10001 / 10000,
                toAmount: txJson.readUint("[1][3]"),
                quotedAmount: txJson.readUint("[1][4]"),
                metadata: bytes32(txJson.readUint("[1][5]")),
                beneficiary: payable(userAddress)
            }),
            partnerAndFee_out: txJson.readUint("[2]"),
            permit_out: vm.parseBytes(txJson.readString("[3]")),
            executorData_out: vm.parseBytes(txJson.readString("[4]")),
            deadline: block.timestamp + 300
        }));
        uint256 profit = sellAmtSell > amount ? sellAmtSell - amount : 0;
        
        // Execute
        vm.startBroadcast();
        FlashLoanHandler(payable(flashLoanHandlerAddress)).initFlashLoan(destinationChain, payable(flashBorrowerAddress), userAddress, amount, data);
        vm.stopBroadcast();
    }
}
