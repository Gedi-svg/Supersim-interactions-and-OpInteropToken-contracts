// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
//import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Test, console} from "forge-std/Test.sol";
import {IFlashBorrower} from "./InterfaceFlashBorrower.sol";
import {FlashLoanVault} from "./FlashLoanVault.sol";
import {GovernanceToken} from "./CrosschainGOpToken.sol";
import {ICrossL2Inbox} from "@contracts-bedrock/L2/interfaces/ICrossL2Inbox.sol";
import {ISuperchainWETH} from "@contracts-bedrock/L2/interfaces/ISuperchainWETH.sol";
import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {ISuperchainETHBridge} from "@contracts-bedrock/L2/interfaces/ISuperchainETHBridge.sol";
import {CrossDomainMessageLib} from "../xChainLoan/CrossDomainMessageLib.sol";
import {Identifier} from "../xChainLoan/IIdentifier.sol";
import {PredeployAddresses} from "../xChainLoan/PredeployAddresses.sol";
import {ISuperchainTokenBridge} from "@contracts-bedrock/L2/interfaces/ISuperchainTokenBridge.sol";
import {SuperchainTokenBridge} from "@contracts-bedrock/L2/SuperchainTokenBridge.sol";
import {L2ToL2CrossDomainMessenger} from "@contracts-bedrock/L2/L2ToL2CrossDomainMessenger.sol";
import { IERC20 } from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "../../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Identifier} from "../xChainLoan/IIdentifier.sol";

error IdOriginNotFlashLoanHandler();

contract FlashLoanHandler {
    /// @notice Thrown when trying to validate a cross chain message with a block number
    ///         that is greater than 2^64.
    error BlockNumberTooHigh();
    
    /// @notice Thrown when trying to validate a cross chain message with a timestamp
    ///         that is greater than 2^64.
    error TimestampTooHigh();

    /// @notice Thrown when trying to validate a cross chain message with a log index
    ///         that is greater than 2^32.
    error LogIndexTooHigh();
    /// @notice The error emitted when a required message has not been relayed.
    error RequiredMessageNotSuccessful(bytes32 msgHash);
    /// @notice The error emitted when the caller is not the L2toL2CrossDomainMessenger.
    error CallerNotL2toL2CrossDomainMessenger();
    /// @notice The error emitted when the original sender of the cross-domain message is not this same address as this contract.
    error InvalidCrossDomainSender();
    //IL2ToL2CrossDomainMessenger public constant MESSENGER = IL2ToL2CrossDomainMessenger(0xEd9D063eB17554Ca12Ade4cDe935c5D4d237b097);
    /// @notice The mask for the most significant bits of the checksum.
    /// @dev    Used to set the most significant byte to zero.
    bytes32 internal constant _MSB_MASK = bytes32(~uint256(0xff << 248));

    /// @notice Mask used to set the first byte of the bare checksum to 3 (0x03).
    bytes32 internal constant _TYPE_3_MASK = bytes32(uint256(0x03 << 248));
    event flashLoanRecieved(
        bytes32 indexed flashLoanId,
        uint256 ethAmount,
        uint256 chainid,
        address indexed user
    );
    event flashLoanRepayed(
        bytes32 indexed flashLoanId,
        uint256 ethAmount,
        uint256 chainid,
        address indexed user
    );
    event soldEth(
        bytes32 indexed flashLoanId,
        uint256 ethAmount,
        uint256 chainid,
        address indexed user
    );
    event boughtEth(
        bytes32 indexed flashLoanId,
        uint256 ethAmount,
        uint256 chainid,
        address indexed user
    );
    event sentProfit(
        bytes32 indexed flashLoanId,
        uint256 ethAmount,
        uint256 chainid,
        address indexed user
    );
    event noProfit(
        bytes32 indexed flashLoanId,
        uint256 chainid,
        address indexed user
    );
    event CrosschainFlashLoanInitiated(
        uint256 indexed destinationChain, address indexed borrower, uint256 amount, uint256 fee
    );

    event CrosschainFlashLoanCompleted(uint256 indexed sourceChain, address indexed borrower, uint256 amount);

    error InsufficientFee();
    error TransferFailed();
    error CallFailed();
    address payable flashBorrowerDefaultAddress;
    SuperchainTokenBridge bridges = new SuperchainTokenBridge();
    L2ToL2CrossDomainMessenger MESSENGER = L2ToL2CrossDomainMessenger(address(bridges.MESSENGER()));
    address payable superchainWEthAddress = payable(0x4200000000000000000000000000000000000024);
   
    ISuperchainETHBridge superchainWEth = ISuperchainETHBridge(superchainWEthAddress);
    //L2ToL2CrossDomainMessenger public mess = bridge.MESSENGER;
    //IL2ToL2CrossDomainMessenger public messenger = IL2ToL2CrossDomainMessenger(address(mess));
    
    
    address token = address(0x4200000000000000000000000000000000000006);
    
    
    address payable flashLoanVaultAddress;
    //FlashLoanVault flashLoanVault;
    // The vault on this chain
    FlashLoanVault public immutable vault;
    uint256 public immutable flatFee;
    // Owner who can withdraw fees
    address public immutable owner;
    constructor(address _flashLoanVaultAddress) {
        flashLoanVaultAddress = payable(_flashLoanVaultAddress);
        vault = FlashLoanVault(flashLoanVaultAddress);
       
    }

    
    /// @notice Initializer.
    
    
    function recieveEthForArbitrageSourceChain(
        uint256 destinationChain,
        address caller,
        uint256 laonAmount,
        bytes32 flashLoanId,
        address payable flashBorrower,
        bytes memory userData
    ) public payable {
        bytes32 sendEthMsgHash = superchainWEth.sendETH{
            value: address(this).balance
        }(address(this), destinationChain);

        MESSENGER.sendMessage(
            destinationChain,
            address(this),
            abi.encodeWithSelector(
                this.recieveEthForArbitrageDestinationChain.selector,
                sendEthMsgHash,
                uint256(block.chainid),
                caller,
                laonAmount,
                flashLoanId,
                flashBorrower,
                userData
            )
        );
    }

    function recieveEthForArbitrageDestinationChain(
        bytes32 sendEthMsgHash,
        uint256 sourceChain,
        address caller,
        uint256 loanAmount,
        bytes32 flashLoanId,
        address payable flashBorrower,
        bytes memory userData
        
    ) external {
        CrossDomainMessageLib.requireCrossDomainCallback();
        CrossDomainMessageLib.requireMessageSuccess(sendEthMsgHash);

        //this.callOnFlashLoan(flashLoanId, caller, flashBorrower, userData);
            
        //tranferToSourceChain(sourceChain, caller, loanAmount, flashLoanId);
        
    }
    /*
    function callOnFlashLoan(
        bytes32 flashLoanId,
        address caller,
        address payable flashBorrower,
        bytes memory userData
    ) external {
        uint256 ethAmount = address(this).balance;

        try
            IFlashBorrower(flashBorrower).onFlashLoan{value: ethAmount}(
                ethAmount,
                address(this),
                userData
            )
        {
            emit soldEth(
                flashLoanId,
                address(this).balance,
                block.chainid,
                caller
            );
        } catch {
            revert("onFlashLoan Function Failed");
        }

        if (address(this).balance < ethAmount) {
            revert("Sufficient Funds Were Not Returned");
        }

        emit boughtEth(
            flashLoanId,
            address(this).balance,
            block.chainid,
            caller
        );
    }
  
    function callOnBuy(
        bytes32 flashLoanId,
        address caller,
        address payable flashBorrower,
        bytes memory userData,
        address srcToken,
        uint256 amount
    ) external returns(IERC20, uint256){
        uint256 ethAmount = address(this).balance;

        
        (IERC20 SrcTokenOut, uint256 SrcTokenOutAmount) = IFlashBorrower(flashBorrower).onBuy(
            srcToken,
            amount,
            address(this),
            userData
        );

        emit boughtEth(
            flashLoanId,
            address(this).balance,
            block.chainid,
            caller
        );

        return (SrcTokenOut, SrcTokenOutAmount);
    

    }
    
    function callOnSell(
        bytes32 flashLoanId,
        address caller,
        address payable flashBorrower,
        bytes memory userData
    ) external returns(IERC20, uint256){
        uint256 ethAmount = address(this).balance;

        
        (IERC20 DestTokenOut, uint256 DestTokenOutAmount) = IFlashBorrower(flashBorrower).onSell{value: ethAmount}(
            ethAmount,
            address(this),
            userData
        );

        emit soldEth(
            flashLoanId,
            address(this).balance,
            block.chainid,
            caller
        );

        return (DestTokenOut, DestTokenOutAmount);
        
    }
    */
    function tranferToSourceChain(
        uint256 sourceChain,
        address caller,
        uint256 loanAmount,
        bytes32 flashLoanId
    ) public {
        bytes32 sendEthMsgHashBack = superchainWEth.sendETH{
            value: address(this).balance
        }(address(this), sourceChain);

        MESSENGER.sendMessage(
            sourceChain,
            address(this),
            abi.encodeWithSelector(
                this.recieveEthOnSourceChainFromDestinationChain.selector,
                sendEthMsgHashBack,
                caller,
                loanAmount,
                flashLoanId
            )
        );
    }

    function recieveEthOnSourceChainFromDestinationChain(
        bytes32 sendEthMsgHash,
        address caller,
        uint256 loanAmount,
        bytes32 flashLoanId
    ) external {
        CrossDomainMessageLib.requireCrossDomainCallback();
        CrossDomainMessageLib.requireMessageSuccess(sendEthMsgHash);
        // add intermiduate swapback to loan token if needed
        int256 profit = int256(address(this).balance) - int256(loanAmount);

        if (profit > 0) {
            flashLoanVaultAddress.call{value: loanAmount}("");
            emit flashLoanRepayed(
                flashLoanId,
                loanAmount,
                block.chainid,
                caller
            );
            payable(caller).call{value: address(this).balance}("");
            emit sentProfit(
                flashLoanId,
                uint256(profit),
                block.chainid,
                caller
            );
        } else {
            flashLoanVaultAddress.call{value: address(this).balance}("");
            emit flashLoanRepayed(
                flashLoanId,
                loanAmount,
                block.chainid,
                caller
            );
            emit noProfit(flashLoanId, block.chainid, caller);
        }
    }
   
    /*
    function tranferToSourceChainERC20( 
        uint256 sourceChain,
        address caller,
        uint256 amount,
        address destToken,
        address srcToken,
        bytes32 flashLoanId,
        address payable flashBorrower,
        bytes memory userDataBuy
    ) private returns (bytes32)
    {
        // Transfer the destination token into the governance wrapper and mint gOp tokens
        // Approve gOpToken to pull the underlying token from this contract, then deposit
        IERC20(destToken).approve(address(gOpToken), amount);
        gOpToken.deposit(destToken, amount);

        // Approve bridge to transfer gOpToken and send across chains
        IERC20(address(gOpToken)).approve(address(bridge), amount);

        // Send wrapped tokens (gOpToken) to source chain
        bytes32 sendERC20MsgHash = bridge.sendERC20(address(gOpToken), address(this), amount, sourceChain);
        messenger.sendMessage(
            sourceChain,
            address(this),
            abi.encodeWithSelector(
                this.recieveERC20OnSourceChainFromDestinationChain.selector,
                sendERC20MsgHash,
                srcToken,
                caller,
                amount,
                flashLoanId,
                flashBorrower,
                userDataBuy
            )
        );
    
    }

    function recieveERC20OnSourceChainFromDestinationChain(
        bytes32 sendERC20MsgHash,
        address srcToken,
        address caller,
        uint256 amount,
        bytes32 flashLoanId,
        address payable flashBorrower,
        bytes memory userDataBuy
    ) external {
        CrossDomainMessageLib.requireCrossDomainCallback();
        // CrossDomainMessageLib.requireMessageSuccess uses a special error signature that the
        // auto-relayer performs special handling on. The auto-relayer parses the _sendWethMsgHash
        // and waits for the _sendWethMsgHash to be relayed before relaying this message.
        CrossDomainMessageLib.requireMessageSuccess(sendERC20MsgHash);
        uint256 loanAmount = 0;
        // We received gOpToken via the bridge; withdraw will burn the gOpToken and
        // transfer the original underlying token (srcToken) back to this contract.
        // No prior approve on srcToken is required here.
        gOpToken.withdraw(srcToken, amount);
        require(IERC20(srcToken).balanceOf(address(this)) > 0, "No tokens received from wrapper");

        // Transfer the underlying token to the flash borrower
        IERC20(srcToken).transfer(flashBorrower, amount);

        (IERC20 SrcTokenOut, uint256 SrcTokenOutAmount) = this.callOnBuy(flashLoanId, caller, flashBorrower, userDataBuy, srcToken, amount);
            //TODO: Define Proper Events For Failiure
        
         // add intermiduate swapback to loan token if needed
        int256 profit = int256(address(this).balance) - int256(loanAmount);

        if (profit > 0) {
            flashLoanVaultAddress.call{value: loanAmount}("");
            emit flashLoanRepayed(
                flashLoanId,
                loanAmount,
                block.chainid,
                caller
            );
            payable(caller).call{value: address(this).balance}("");
            emit sentProfit(
                flashLoanId,
                uint256(profit),
                block.chainid,
                caller
            );
        } else {
            flashLoanVaultAddress.call{value: address(this).balance}("");
            emit flashLoanRepayed(
                flashLoanId,
                loanAmount,
                block.chainid,
                caller
            );
            emit noProfit(flashLoanId, block.chainid, caller);
        }
    }
    */
    function initFlashLoan(
        uint256 destinationChain,
        address payable flashBorrower,
        address caller,
        uint256 loanAmountRecieved,
        bytes memory userData
    ) public {
        require(
            destinationChain != block.chainid,
            "Destination Chain Cannot Be Same As Source Chain"
        );
        /*
        bool loanAmount = flashLoanVault.processLoanRequest(loanAmountRecieved);
        require(loanAmount == true);
        bytes32 flashLoanId = keccak256(
            abi.encodePacked(loanAmountRecieved, caller, block.number)
        );
        */
        vault.createLoan(address(token), loanAmountRecieved, address(this),  1 hours);
        bytes32 flashLoanId = keccak256(
            abi.encodePacked(loanAmountRecieved, caller, block.number)
        );
        emit flashLoanRecieved(
            flashLoanId,
            loanAmountRecieved,
            block.chainid,
            caller
        );

        this.recieveEthForArbitrageSourceChain(
            destinationChain,
            caller,
            loanAmountRecieved,
            flashLoanId,
            flashBorrower,
            userData
        );
    }
    /*
    function callFlashLoanHandlerSimple(
        uint256 destinationChain,  
        uint256 loanAmountRecieved,
        bytes memory userDataBuy,
        bytes memory userDataSell
        ) public {
        this.initFlashLoan(
            destinationChain,
            flashBorrowerDefaultAddress,
            msg.sender,
            loanAmountRecieved,
            userDataBuy,
            userDataSell
        );
    }

    function callFlashLoanHandler(
        ICrossL2Inbox.Identifier calldata msgId,
        bytes calldata msgData,
        uint256 destinationChain,
        uint256 loanAmountRecieved,
        bytes memory userDataBuy,
        bytes memory userDataSell
    ) public {
        if (msgId.origin != address(this)) revert IdOriginNotFlashLoanHandler();
        
        ICrossL2Inbox(PredeployAddresses.CROSS_L2_INBOX).validateMessage(
            msgId,
            keccak256(msgData)
        );

        this.initFlashLoan(
            destinationChain,
            flashBorrowerDefaultAddress,
            msg.sender,
            loanAmountRecieved,
            userDataBuy,
            userDataSell
        );
    }

    function callFlashLoanHandlerAdvanced(
        uint256 destinationChain,
        address flashBorrowerAddress,
        uint256 loanAmountRecieved,
        bytes memory userDataBuy,
        bytes memory userDataSell
    ) public {
        this.initFlashLoan(
            destinationChain,
            payable(flashBorrowerAddress),
            msg.sender,
            loanAmountRecieved,
            userDataBuy,
            userDataSell
        );
    }
    */
    /// @notice Initiates a cross-chain flash loan
    /// @param destinationChain The chain ID where the flash loan will be executed
    /// @param amount The amount to borrow
    /// @param target The contract to call on the destination chain
    /// @param data The calldata to execute on the target contract
    function initiateCrosschainFlashLoan(uint256 destinationChain, uint256 amount, address target, bytes calldata data)
        external
        payable
        returns (bytes32)
    {
        // Check that sufficient fee was paid
        if (msg.value < flatFee) revert InsufficientFee();
        IERC20(token).approve(address(bridges), amount);
        IERC20(token).approve(address(this), amount);
        
        // Send tokens to destination chain
        bytes32 sendERC20MsgHash = bridges.sendERC20(address(token), address(this), amount, destinationChain);

        return MESSENGER.sendMessage(
            destinationChain,
            target,
            abi.encodeWithSelector(
                this.executeCrosschainFlashLoan.selector,
                sendERC20MsgHash,
                block.chainid,
                msg.sender,
                amount,
                target,
                data
            )
        );
    }

    /// @notice Executes the flash loan on the destination chain and returns tokens
    /// @param sendERC20MsgHash The hash of the message responsible for sending the ERC20 tokens to the destination chain
    /// @param sourceChain The chain ID where the flash loan was initiated
    /// @param borrower The address that initiated the flash loan
    /// @param amount The amount to borrow
    /// @param target The contract to call with the borrowed funds
    
    function executeCrosschainFlashLoan(
        bytes32 sendERC20MsgHash,
        uint256 sourceChain,
        address borrower,
        uint256 amount,
        address target
       // bytes memory data
    ) external {
        requireCrossDomainCallback();
        // CrossDomainMessageLib.requireMessageSuccess uses a special error signature that the
        // auto-relayer performs special handling on. The auto-relayer parses the _sendWethMsgHash
        // and waits for the _sendWethMsgHash to be relayed before relaying this message.
        requireMessageSuccess(sendERC20MsgHash);

        // give approval to the vault to transfer tokens
        IERC20(token).approve(address(vault), amount);

        // Create flash loan
        bytes32 loanId = vault.createLoan(address(token), amount, address(this), 1 hours);

        // Execute flash loan
        vault.executeFlashLoan(loanId, target);

        //transfer tokens to vault before reclaiming
        /*
        // Send tokens back to this contract on source chain
        bridge.sendERC20(
            address(token),
            address(this), // Send back to this contract on source chain
            amount,
            sourceChain
        );
        */

        emit CrosschainFlashLoanCompleted(sourceChain, borrower, amount);
    }

    /// @notice Allows owner to withdraw accumulated fees
    function withdrawFees() external {
        require(msg.sender == owner, "Not authorized");
        (bool success,) = owner.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

     /// @notice Checks if the msgHash has been relayed and reverts with a special error signature
    /// that the auto-relayer performs special handling on if the msgHash has not been relayed.
    /// If the auto-relayer encounters this error, it will parse the msgHash and wait for the
    /// msgHash to be relayed before relaying the message that calls this function. This ensures
    /// that any required message is relayed before the message that depends on it.
    /// @param msgHash The hash of the message to check if it has been relayed.
    function requireMessageSuccess(bytes32 msgHash) internal view {
        if (
            !IL2ToL2CrossDomainMessenger(address(MESSENGER)).successfulMessages(msgHash)
        ) {
            revert RequiredMessageNotSuccessful(msgHash);
        }
    }

    /// @notice Checks if the caller is the L2toL2CrossDomainMessenger. It is important to use this check
    /// on cross-domain messages that should only be relayed through the L2toL2CrossDomainMessenger.
    function requireCallerIsCrossDomainMessenger() internal view {
        if (msg.sender != address(this)) {
            revert CallerNotL2toL2CrossDomainMessenger();
        }
    }

    /// @notice While relaying a message through the L2toL2CrossDomainMessenger, checks
    /// that the original sender of the cross-domain message is this same address.
    /// It is important to use this check on cross-domain messages that should only be
    /// sent and relayed by the same contract on different chains.
    function requireCrossDomainCallback() internal view {
        //requireCallerIsCrossDomainMessenger();

        if (
            IL2ToL2CrossDomainMessenger(address(MESSENGER)).crossDomainMessageSender()
                != address(this)
        ) revert InvalidCrossDomainSender();
    }

    /// @notice Calculates a custom checksum for a cross chain message `Identifier` and `msgHash`.
    /// @param _id The identifier of the message.
    /// @param _msgHash The hash of the message.
    /// @return checksum_ The checksum of the message.
    function calculateChecksum(Identifier memory _id, bytes32 _msgHash) public pure returns (bytes32 checksum_) {
        if (_id.blockNumber > type(uint64).max) revert BlockNumberTooHigh();
        if (_id.logIndex > type(uint32).max) revert LogIndexTooHigh();
        if (_id.timestamp > type(uint64).max) revert TimestampTooHigh();

        // Hash the origin address and message hash together
        bytes32 logHash = keccak256(abi.encodePacked(_id.origin, _msgHash));

        // Downsize the identifier fields to match the needed type for the custom checksum calculation.
        uint64 blockNumber = uint64(_id.blockNumber);
        uint64 timestamp = uint64(_id.timestamp);
        uint32 logIndex = uint32(_id.logIndex);

        // Pack identifier fields with a left zero padding (uint96(0))
        bytes32 idPacked = bytes32(abi.encodePacked(uint96(0), blockNumber, timestamp, logIndex));

        // Hash the logHash with the packed identifier data
        bytes32 idLogHash = keccak256(abi.encodePacked(logHash, idPacked));

        // Create the final hash by combining idLogHash with chainId
        bytes32 bareChecksum = keccak256(abi.encodePacked(idLogHash, _id.chainId));

        // Apply bit masking to create the final checksum
        checksum_ = (bareChecksum & _MSB_MASK) | _TYPE_3_MASK;
    }
    receive() external payable {}
}
