// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { ERC20 } from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {PredeployAddresses} from "../xChainLoan/PredeployAddresses.sol";
import { GenericData } from "../augustusContract/interfaces/IAugustusSwapper.sol";
import { IGenericSwapExactAmountIn } from "../augustusContract/interfaces/IGenericSwapAmountIn.sol";
import { IGenericSwapExactAmountOut } from "../augustusContract/interfaces/IGenericSwapAmountOut.sol";
import { ReentrancyGuard } from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract TradeContract is Ownable, ReentrancyGuard {
    uint256 public lastBalance;
    bytes4 constant PARASWAP_FN_SELECTOR = 0xe83ec731;
    address constant TOKEN_TRANSFER_PROXY_ADDR = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae; 
    address constant PARASWAP_ADDR = 0x6A000F20005980200259B80c5102003040001068;
    
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
    uint256 i;
    uint256 j;
    uint256 currentAllowance; 
   

    error NotOwner();
    error NotPool();
    error InvalidAssetsLength();

    modifier onlyOwner() override {
        if (msg.sender != Ownable.owner()) revert NotOwner();
        _;
    }

    constructor(){   
    }

    IGenericSwapExactAmountIn public AUGUSTUSAmountIn = IGenericSwapExactAmountIn(PARASWAP_ADDR);
    IGenericSwapExactAmountOut public AUGUSTUSAmountOut = IGenericSwapExactAmountOut(PARASWAP_ADDR);
    
        /// buy low on swapExactAmountIn, sell high on swapExactAmountOut
    function arbitrageIn(
        bytes memory userData
    ) public payable {
        
        (ArbitrageData memory arbData) =
        abi.decode(userData, (ArbitrageData));

        require(block.timestamp < arbData.deadline);
        
        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = IERC20(arbData.swapData_out.srcToken);
        tokens[1] = IERC20(arbData.swapData_out.destToken);
        tokens[2] = IERC20(arbData.swapData.srcToken);
        tokens[3] = IERC20(arbData.swapData.destToken); 
        address[] memory spenders = new address[](2);
        spenders[0] = address(PARASWAP_ADDR);
        spenders[1] =  address(TOKEN_TRANSFER_PROXY_ADDR);
        
    
        for (i = 0; i < tokens.length; i++) {
            for (j = 0; j < spenders.length; j++) {
                IERC20 token = IERC20(tokens[i]);
                currentAllowance = token.allowance(address(this), spenders[j]);
                if (currentAllowance <  type(uint256).max) {
                    token.approve(spenders[j],  type(uint256).max);
                }
            }
        }
        AUGUSTUSAmountIn.swapExactAmountIn(arbData.executor, arbData.swapData, arbData.partnerAndFee, arbData.permit, arbData.executorData);
        AUGUSTUSAmountIn.swapExactAmountIn(arbData.executor_out, arbData.swapData_out, arbData.partnerAndFee_out, arbData.permit_out, arbData.executorData_out);

        uint256 balance = IERC20(arbData.swapData_out.destToken).balanceOf(address(this));
        require(balance > 0);
        IERC20(arbData.swapData_out.destToken).approve(payable(msg.sender), balance);
        IERC20(arbData.swapData_out.destToken).transfer(payable(msg.sender), balance);
        
    }
    
    /// buy low on swapExactAmountOut, sell high on swapExactAmountIn
    function arbitrageOut(
         bytes memory userData
    ) public payable {
        (ArbitrageData memory arbData) =
        abi.decode(userData, (ArbitrageData));

        require(block.timestamp < arbData.deadline); // dev: deadline passed
        
        IERC20[] memory tokens = new IERC20[](4);
        tokens[0] = IERC20(arbData.swapData_out.srcToken);
        tokens[1] = IERC20(arbData.swapData_out.destToken);
        tokens[2] = IERC20(arbData.swapData.srcToken);
        tokens[3] = IERC20(arbData.swapData.destToken); 
        address[] memory spenders = new address[](2);
        spenders[0] = address(PARASWAP_ADDR);
        spenders[1] =  address(TOKEN_TRANSFER_PROXY_ADDR);
        
    
        for (i = 0; i < tokens.length; i++) {
            for (j = 0; j < spenders.length; j++) {
                IERC20 token = IERC20(tokens[i]);
                currentAllowance = token.allowance(address(this), spenders[j]);
                if (currentAllowance <  type(uint256).max) {
                    token.approve(spenders[j],  type(uint256).max);
                }
            }
        }
        AUGUSTUSAmountOut.swapExactAmountOut(arbData.executor_out, arbData.swapData_out, arbData.partnerAndFee_out, arbData.permit_out, arbData.executorData_out);
        AUGUSTUSAmountIn.swapExactAmountIn(arbData.executor, arbData.swapData, arbData.partnerAndFee, arbData.permit, arbData.executorData);

        uint256 balance = IERC20(arbData.swapData.destToken).balanceOf(address(this));
        require(balance > 0);
        IERC20(arbData.swapData.destToken).approve(payable(msg.sender), balance);
        IERC20(arbData.swapData.destToken).transfer(payable(msg.sender), balance);
        
    }

    function arbitrageBuy(
        bytes memory userData
    ) public payable returns (IERC20, uint256) {
        
        (ArbitrageDataBuy memory arbData) =
        abi.decode(userData, (ArbitrageDataBuy));

        require(block.timestamp < arbData.deadline);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(arbData.swapData_out.srcToken);
        tokens[1] = IERC20(arbData.swapData_out.destToken); 
        address[] memory spenders = new address[](2);
        spenders[0] = address(PARASWAP_ADDR);
        spenders[1] =  address(TOKEN_TRANSFER_PROXY_ADDR);
        
    
        for (i = 0; i < tokens.length; i++) {
            for (j = 0; j < spenders.length; j++) {
                IERC20 token = IERC20(tokens[i]);
                currentAllowance = token.allowance(address(this), spenders[j]);
                if (currentAllowance <  type(uint256).max) {
                    token.approve(spenders[j],  type(uint256).max);
                }
            }
        }
        AUGUSTUSAmountOut.swapExactAmountOut(arbData.executor_out, arbData.swapData_out, arbData.partnerAndFee_out, arbData.permit_out, arbData.executorData_out);

        uint256 balance = IERC20(arbData.swapData_out.destToken).balanceOf(address(this));
        require(balance > 0);
        IERC20(arbData.swapData_out.destToken).approve(payable(msg.sender), balance);
        IERC20(arbData.swapData_out.destToken).transfer(payable(msg.sender), balance);
        return (arbData.swapData_out.destToken, balance);
        
    }
    
    function arbitrageSell(
        bytes memory userData
    ) public payable returns(IERC20, uint256) {
        (ArbitrageDataSell memory arbData) =
        abi.decode(userData, (ArbitrageDataSell));
        require(block.timestamp < arbData.deadline);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(arbData.swapData.srcToken);
        tokens[1] = IERC20(arbData.swapData.destToken); 
        address[] memory spenders = new address[](2);
        spenders[0] = address(PARASWAP_ADDR);
        spenders[1] =  address(TOKEN_TRANSFER_PROXY_ADDR);
        
    
        for (i = 0; i < tokens.length; i++) {
            for (j = 0; j < spenders.length; j++) {
                IERC20 token = IERC20(tokens[i]);
                currentAllowance = token.allowance(address(this), spenders[j]);
                if (currentAllowance <  type(uint256).max) {
                    token.approve(spenders[j],  type(uint256).max);
                }
            }
        }

        AUGUSTUSAmountIn.swapExactAmountIn(arbData.executor, arbData.swapData, arbData.partnerAndFee, arbData.permit, arbData.executorData);

        uint256 balance = IERC20(arbData.swapData.destToken).balanceOf(address(this));
        require(balance > 0);
        IERC20(arbData.swapData.destToken).approve(payable(msg.sender), balance);
        IERC20(arbData.swapData.destToken).transfer(payable(msg.sender), balance);
        return (arbData.swapData.destToken, balance);
        
    }

    /**
    * @notice Allows the owner to withdraw tokens from the contract
    * @param token The token to withdraw
    * @param amount The amount to withdraw
    */
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(Ownable.owner(), amount);
    }

    /**
    * @notice Allows the owner to withdraw ETH from the contract
    */
    function withdrawETH() external onlyOwner {
        payable(Ownable.owner()).transfer(address(this).balance);
    }

    receive() external payable {}
    

}