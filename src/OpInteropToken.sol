// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20 } from "../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20Burnable } from "../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Votes, ERC20Permit } from "../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Ownable } from "../lib/interop/lib/optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { Predeploys } from "@contracts-bedrock/libraries/Predeploys.sol";
import { Unauthorized } from "@contracts-bedrock/libraries/errors/CommonErrors.sol";

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC7802 is IERC165 {
    event CrosschainMint(address indexed to, uint256 amount, address indexed sender);
    event CrosschainBurn(address indexed from, uint256 amount, address indexed sender);
    function crosschainMint(address _to, uint256 _amount) external;
    function crosschainBurn(address _from, uint256 _amount) external;
}

/// @title GovernanceToken Wrapper (wOP_FL)
contract OpInteropToken is IERC7802, ERC20Burnable, ERC20Votes, Ownable {
    // The official Predeploy address for the standard OP token on all Superchain L2s
    address public constant STANDARD_OP = 0x4200000000000000000000000000000000000042;

    event Wrapped(address indexed account, uint256 amount);
    event Unwrapped(address indexed account, uint256 amount);

    constructor() ERC20("Wrapped OP Flash Loan", "wOP_FL") ERC20Permit("Wrapped OP Flash Loan") Ownable() { }

    // --- Wrapper Functions ---
    /// @notice Allows the owner to mint tokens.
    /// @param _account The account receiving minted tokens.
    /// @param _amount  The amount of tokens to mint.
    function mint(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }
    /// @notice Allows the owner to burn tokens.
    /// @param _account The account receiving minted tokens.
    /// @param _amount  The amount of tokens to mint.
    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }
    /**
     * @notice Locks Standard OP tokens and mints wOP_FL 1:1.
     * @dev User must approve this contract to spend STANDARD_OP first.
     */
    function deposit(uint256 _amount) public {
        require(_amount > 0, "Amount must be > 0");
        // Transfer actual OP from user to this contract vault
        bool success = IERC20(STANDARD_OP).transferFrom(msg.sender, address(this), _amount);
        require(success, "OP Transfer failed");

        // Mint the wrapped interoperable token
        _mint(msg.sender, _amount);
        emit Wrapped(msg.sender, _amount);
    }

    /**
     * @notice Burns wOP_FL and releases Standard OP tokens 1:1.
     */
    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount must be > 0");
        // Burn the interoperable token
        _burn(msg.sender, _amount);

        // Release the underlying standard OP asset
        bool success = IERC20(STANDARD_OP).transfer(msg.sender, _amount);
        require(success, "OP Release failed");
        emit Unwrapped(msg.sender, _amount);
    }

    // --- IERC7802 Cross-chain Logic ---

    function crosschainMint(address _to, uint256 _amount) external {
        if (msg.sender != Predeploys.SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        _mint(_to, _amount);
        emit CrosschainMint(_to, _amount, msg.sender);
    }

    function crosschainBurn(address _from, uint256 _amount) external {
        if (msg.sender != Predeploys.SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
        _burn(_from, _amount);
        emit CrosschainBurn(_from, _amount, msg.sender);
    }

    // --- Mandatory Overrides ---

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return _interfaceId == type(IERC7802).interfaceId || _interfaceId == type(IERC20).interfaceId
            || _interfaceId == type(IERC165).interfaceId;
    }
}
