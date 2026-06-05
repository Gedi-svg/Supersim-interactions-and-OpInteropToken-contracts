// SPDX-License-Identifier: MIT

/*
    
    import {IVault} from "../../../../dependencies/balancer-v2/pkg/interfaces/contracts/vault/IVault.sol";
    import {IERC20 } from "../../../../dependencies/balancer-v2/pkg/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
    import {IFlashLoanRecipient} from "../../../../dependencies/balancer-v2/pkg/interfaces/contracts/vault/IFlashLoanRecipient.sol";
    import {Ownable} from "../../../../dependencies/openzeppelin/contracts/access/Ownable.sol";
    import '../../../../dependencies/uniswap-v3-core/contracts/libraries/LowGasSafeMath.sol';
    import "../../../../dependencies/openzeppelin/contracts/security/ReentrancyGuard.sol";
    import { GenericData } from "./augustusContract/interfaces/IAugustusSwapper.sol";
    import { IGenericSwapExactAmountIn } from "./augustusContract/interfaces/IGenericSwapAmountIn.sol";
    import { IGenericSwapExactAmountOut } from "./augustusContract/interfaces/IGenericSwapAmountOut.sol";

    /**
    * @title FlashLoanRecipient
    * @notice A basic flashloan receiver contract for Balancer V2
    * @dev This contract is intended as a starting point for learning how to use Balancer V2 flashloans.
    * It simply takes out a flashloan and returns the funds. You would add your own logic where indicated.
    */
    /*
    contract BalFlashLoan is IFlashLoanRecipient, Ownable, ReentrancyGuard {
        
        using LowGasSafeMath for uint256;


        bytes4 constant PARASWAP_FN_SELECTOR = 0xe83ec731;
        address constant TOKEN_TRANSFER_PROXY_ADDR = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae; 
        address constant PARASWAP_ADDR = 0x6A000F20005980200259B80c5102003040001068;
        IVault private constant balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    

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


        uint256 i;
        uint256 j;
        uint256 currentAllowance; 
        address private inputAsset;
        uint256 private amountToReturn;
        

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
        

        function executeFlashLoan(address[] memory tokens, uint256[] memory amounts, bytes memory userData) external onlyOwner {
            if (tokens.length < 2) revert InvalidAssetsLength();

        // Cast the tokens array to IERC20[]
            IERC20[] memory tokenContracts = new IERC20[](tokens.length);
            for ( i = 0; i < tokens.length; i++) {
                tokenContracts[i] = IERC20(tokens[i]);
            }
            
            address[] memory spenders = new address[](3);
            spenders[0] = address(PARASWAP_ADDR);
            spenders[1] =  address(TOKEN_TRANSFER_PROXY_ADDR);
            spenders[2] =  address(balancerVault);
        
            for (i = 0; i < tokens.length; i++) {
                for (j = 0; j < spenders.length; j++) {
                    IERC20 token = IERC20(tokens[i]);
                    currentAllowance = token.allowance(address(this), spenders[j]);
                    if (currentAllowance <  type(uint256).max) {
                        token.approve(spenders[j],  type(uint256).max);
                    }
                }
            }
            
            balancerVault.flashLoan(this, tokenContracts, amounts, userData);  
        }

        /**
        * @notice This function is called by the Balancer Vault after it has sent the flashloaned amounts.
        * @dev This function must return the flashloaned amounts plus fees before it ends.
        * @param userData Arbitrary data passed from the `executeFlashLoan` function.
       
        function receiveFlashLoan(
            IERC20[] memory tokens,
            uint256[] memory amounts,
            uint256[] memory feeAmounts,
            bytes memory userData
        ) external override{
            require(msg.sender == address(balancerVault));

            inputAsset = address(tokens[0]);
            amountToReturn = amounts[0] + feeAmounts[0];

            decodeAndExecuteArbitrage(userData);

            for (i = 0; i < tokens.length; i++) {
                IERC20(tokens[i]).transfer(address(balancerVault), amounts[i] + feeAmounts[i]);
            }
            inputAsset = address(0);
            amountToReturn = 0;
        }

        function decodeAndExecuteArbitrage(bytes memory userData) internal {
            (ArbitrageData memory arbData) =
                abi.decode(userData, (ArbitrageData));

            if (arbData._isArbitrageIn) {
                arbitrageIn(
                    arbData.executor,
                    arbData.swapData,
                    arbData.partnerAndFee,
                    arbData.permit,
                    arbData.executorData,
                    arbData.executor_out,
                    arbData.swapData_out,
                    arbData.partnerAndFee_out,
                    arbData.permit_out,
                    arbData.executorData_out,
                    arbData.deadline
                );
            } else {
                arbitrageOut(
                    arbData.executor,
                    arbData.swapData,
                    arbData.partnerAndFee,
                    arbData.permit,
                    arbData.executorData,
                    arbData.executor_out,
                    arbData.swapData_out,
                    arbData.partnerAndFee_out,
                    arbData.permit_out,
                    arbData.executorData_out,
                    arbData.deadline
                );
            }
        }
        /// buy low on swapExactAmountIn, sell high on swapExactAmountOut
        function arbitrageIn(
            address executor,
            GenericData memory swapData,
            uint256 partnerAndFee,
            bytes memory permit,
            bytes memory executorData,
            address executor_out,
            GenericData memory swapData_out,
            uint256 partnerAndFee_out,
            bytes memory permit_out,
            bytes memory executorData_out,
            uint256 _deadline
        ) public {
            require(block.timestamp < _deadline);
        

        
            AUGUSTUSAmountIn.swapExactAmountIn(executor, swapData, partnerAndFee, permit, executorData);
            AUGUSTUSAmountOut.swapExactAmountOut(executor_out, swapData_out, partnerAndFee_out, permit_out, executorData_out);

            uint256 balance = IERC20(inputAsset).balanceOf(address(this));
            uint256 profit = LowGasSafeMath.sub(balance, amountToReturn);

            require(profit > 0); // dev: no profit
            // transfer profit out and set storage variables to 0
            IERC20(inputAsset).transfer(Ownable.owner(), profit);
            
        }

        /// buy low on swapExactAmountOut, sell high on swapExactAmountIn
        function arbitrageOut(
            address executor,
            GenericData memory swapData,
            uint256 partnerAndFee,
            bytes memory permit,
            bytes memory executorData,
            address executor_out,
            GenericData memory swapData_out,
            uint256 partnerAndFee_out,
            bytes memory permit_out,
            bytes memory executorData_out,
            uint256 _deadline
        ) public {
            require(block.timestamp < _deadline); // dev: deadline passed
            
            AUGUSTUSAmountOut.swapExactAmountOut(executor_out, swapData_out, partnerAndFee_out, permit_out, executorData_out);
            AUGUSTUSAmountIn.swapExactAmountIn(executor, swapData, partnerAndFee, permit, executorData);

            uint256 balance = IERC20(inputAsset).balanceOf(address(this));
            uint256 profit = LowGasSafeMath.sub(balance, amountToReturn);

            require(profit > 0); // dev: no profit
            // transfer profit out and set storage variables to 0
            IERC20(inputAsset).transfer(Ownable.owner(), profit);
        }

        /**
        * @notice Allows the owner to withdraw tokens from the contract
        * @param token The token to withdraw
        * @param amount The amount to withdraw
        
        function withdrawToken(address token, uint256 amount) external onlyOwner {
            IERC20(token).transfer(Ownable.owner(), amount);
        }

        /**
        * @notice Allows the owner to withdraw ETH from the contract
        
        function withdrawETH() external onlyOwner {
            payable(Ownable.owner()).transfer(address(this).balance);
        }

        receive() external payable {}
        
    }
    */