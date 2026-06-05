// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IWETH } from "../../universal/interfaces/IWETH.sol";
import { ICrosschainERC20 } from "./ICrosschainERC20.sol";
import { ISemver } from "../../universal/interfaces/ISemver.sol";

interface ISuperchainWETH is IWETH, ICrosschainERC20, ISemver {
    error Unauthorized();
    error NotCustomGasToken();

    function __constructor__() external;
}
