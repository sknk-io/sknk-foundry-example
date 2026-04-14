// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {SLPConsumerBase} from "./SLPConsumerBase.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/// @title DemoGame
/// @notice Reference SLP-integrated game demonstrating the hub ticket flow.
/// @dev Uses AccessControl for operator actions and SLPConsumerBase for hub interactions.
contract DemoGame is AccessControl, SLPConsumerBase {
    using SafeERC20 for IERC20;

    /// @notice Reverts when the ETH value does not match the stake.
    error InvalidEthAmount();

    /// @notice Emitted when a user plays and a ticket is created for a consumer id.
    event GamePlayed(
        address indexed user,
        address indexed pair,
        address indexed token,
        uint112 stake,
        uint16 chance,
        uint256 consumerId
    );
    /// @notice Emitted when a user withdraws their hub balance.
    event UserWithdrawn(address indexed user, address indexed token, uint256 amount);

    /// @notice Operator role for admin game actions.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @param _hub The SLP hub address.
    /// @param _admin The admin address granted default admin and operator roles.
    constructor(address _hub, address _admin) SLPConsumerBase(_hub) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
    }

    /// @notice Plays the game using an ERC20 stake and creates a hub ticket.
    /// @param _pair The hub pair address.
    /// @param _token The token used for the stake.
    /// @param _stake The stake amount.
    /// @param _chance The chance parameter for the ticket.
    function play(address _pair, address _token, uint112 _stake, uint16 _chance) public {
        // Check the user's existing hub balance and only pull any shortfall into this contract.
        uint256 balance = _getUserSlpBalance(_token, msg.sender);
        if (balance < _stake) {
            uint256 outstanding = _stake - balance;
            IERC20(_token).safeTransferFrom(msg.sender, address(this), outstanding);
        }

        // Scope the approval to this play so allowances do not accumulate across calls.
        IERC20(_token).forceApprove(address(hub), _stake);
        uint256 id = _createTicket(_pair, _token, _stake, _chance, msg.sender);
        IERC20(_token).forceApprove(address(hub), 0);

        emit GamePlayed(msg.sender, _pair, _token, _stake, _chance, id);
    }

    /// @notice Plays the game using ETH and creates a hub ticket.
    /// @dev Requires `msg.value == _stake`.
    /// @param _pair The hub pair address.
    /// @param _stake The stake amount.
    /// @param _chance The chance parameter for the ticket.
    function playWithETH(address _pair, uint112 _stake, uint16 _chance) public payable {
        if (msg.value != _stake) revert InvalidEthAmount();

        uint256 id = _createTicketWithETH(_pair, _stake, _chance, msg.sender);

        emit GamePlayed(msg.sender, _pair, hub.WETH_ADDRESS(), _stake, _chance, id);
    }

    /// @notice Returns the current ticket status and result for a consumer id.
    /// @param _id The game-level consumer id returned from `play` or `playWithETH`.
    /// @return status The ticket status as a uint8.
    /// @return isWin True if the ticket is a winning ticket.
    /// @return chance The chance value recorded on the ticket.
    /// @return result The result value recorded on the ticket.
    function getGameResult(uint256 _id) public view returns (uint8 status, bool isWin, uint16 chance, uint16 result) {
        return _getTicketStatus(_id);
    }

    /// @notice Withdraws a user's hub balance and forwards the tokens to the user.
    /// @param _token The token to withdraw.
    /// @param _amount The amount to withdraw.
    function withdraw(address _token, uint256 _amount) public {
        _withdrawUserSlpBalance(_token, _amount, msg.sender);
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit UserWithdrawn(msg.sender, _token, _amount);
    }

    /// @notice Sets the game registry address and registers the game name.
    /// @param _registry The game registry contract address.
    /// @param _name The name to register in the game registry.
    function setRegistryName(address _registry, string memory _name) public onlyRole(OPERATOR_ROLE) {
        _setGamesRegistry(_registry);
        _setName(_name);
    }

    /// @notice Returns the registered name from the game registry.
    /// @return The registered game name.
    function name() public view returns (string memory) {
        return _name();
    }
}
