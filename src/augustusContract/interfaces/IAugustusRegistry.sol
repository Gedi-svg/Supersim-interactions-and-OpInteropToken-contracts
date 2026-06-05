// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
interface IAugustusRegistry {

    function isAugustusBanned(address augustus) external view returns (bool);

    function isValidAugustus(address augustus) external view returns (bool);

    function getAugustusCount() external view returns (uint256);

    function getLatestVersion() external view returns (string memory);

    function getLatestAugustus() external view returns (address);

    function getAugustusByVersion(string calldata version) external view returns (address);
}