// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title IGamesRegistry
/// @notice Minimal interface for game contracts to self-register names.
interface IGamesRegistry {
    /// @notice Self-register a game name.
    /// @param _name The name to register (1-32 bytes).
    function registerName(string calldata _name) external;

    /// @notice Get registered name for caller.
    /// @return name Registered name.
    function getName() external view returns (string memory name);
}
