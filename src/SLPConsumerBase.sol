// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISLPHub} from "./interfaces/ISLPHub.sol";
import {IGamesRegistry} from "./interfaces/IGamesRegistry.sol";

/// @title SLPConsumerBase
/// @notice Base contract for integrating with the SLP hub ticketing flow.
/// @dev Inherit to create tickets, query status, and withdraw user balances.
contract SLPConsumerBase {
    using SafeERC20 for IERC20;

    /// @notice Reverts when a provided address is the zero address.
    error InvalidAddress();
    /// @notice Reverts when no ticket is registered for a consumer id.
    /// @param consumerId The consumer id with no ticket mapping.
    error NoTicketFound(uint256 consumerId);
    /// @notice Reverts when the user's SLP balance is insufficient.
    /// @param available The available balance in the hub.
    /// @param required The required amount to withdraw.
    error InsufficientBalance(uint256 available, uint256 required);
    /// @notice Reverts when the game registry address is not set.
    error GamesRegistryNotSet();

    /// @notice Address of the SLP hub contract.
    ISLPHub public hub;

    /// @notice Address of games registry contract (optional)
    IGamesRegistry internal gamesRegistry;

    /// @notice Monotonic counter for consumer ids.
    uint256 public lastConsumerId;
    /// @notice Maps consumer ids to hub ticket ids.
    mapping(uint256 => uint256) public consumerIdToTicketId;

    /// @param _hub The address of the SLP hub contract.
    constructor(address _hub) {
        if (_hub == address(0)) {
            revert InvalidAddress();
        }

        hub = ISLPHub(_hub);
    }

    /// @notice Updates the hub address.
    /// @param _hub The address of the new SLP hub contract.
    function _setHub(address _hub) internal {
        if (_hub == address(0)) {
            revert InvalidAddress();
        }

        hub = ISLPHub(_hub);
    }

    /// @notice Updates the game registry address.
    /// @dev Optional, only if using game registry.
    /// @param _registry The address of the new SLP game registry contract.
    function _setGamesRegistry(address _registry) internal {
        if (_registry == address(0)) {
            revert InvalidAddress();
        }

        gamesRegistry = IGamesRegistry(_registry);
    }

    /// @notice Returns the user's SLP balance for a token in the hub.
    /// @param _token The SLP token address.
    /// @param _user The user whose balance is queried.
    /// @return balance The user's SLP balance in the hub.
    function _getUserSlpBalance(address _token, address _user) internal view returns (uint256) {
        return hub.balances(_token, address(this), _user);
    }

    /// @notice Creates a new ticket in the hub and registers it to a new consumer id.
    /// @dev Contract must hold token balance and have approved hub to spend.
    /// @param _pair The pair address used by the hub.
    /// @param _token The token used for the ticket.
    /// @param _stake The stake amount for the ticket.
    /// @param _chance The chance parameter for the ticket.
    /// @param _user The user on whose behalf the ticket is created.
    /// @return consumerId The consumer id linked to the ticket.
    function _createTicket(address _pair, address _token, uint112 _stake, uint16 _chance, address _user)
        internal
        returns (uint256)
    {
        uint256 ticketId = hub.createTicket(_pair, _token, _stake, _chance, _user);
        return _registerTicket(ticketId);
    }

    /// @notice Creates a new ticket in the hub using ETH and registers it to a new consumer id.
    /// @dev msg.value must equal stake amount.
    /// @param _pair The pair address used by the hub.
    /// @param _stake The stake amount for the ticket.
    /// @param _chance The chance parameter for the ticket.
    /// @param _user The user on whose behalf the ticket is created.
    /// @return consumerId The consumer id linked to the ticket.
    function _createTicketWithETH(address _pair, uint112 _stake, uint16 _chance, address _user)
        internal
        returns (uint256)
    {
        uint256 ticketId = hub.createTicketWithETH{value: msg.value}(_pair, _stake, _chance, _user);
        return _registerTicket(ticketId);
    }

    /// @notice Registers a hub ticket id to a new consumer id.
    /// @param _ticketId The hub ticket id.
    /// @return consumerId The consumer id linked to the ticket.
    function _registerTicket(uint256 _ticketId) internal returns (uint256) {
        uint256 consumerId = ++lastConsumerId;
        consumerIdToTicketId[consumerId] = _ticketId;
        return consumerId;
    }

    /// @notice Computes the expected token output for a stake and chance.
    /// @param _stake The stake amount.
    /// @param _chance The chance parameter.
    /// @return netOutput The output returned to the user upon a win.
    function _computeTokenOutput(uint112 _stake, uint16 _chance) internal view returns (uint112) {
        (uint112 netOutput,,,,) = hub.computeTokenOutput(_stake, _chance);
        return netOutput;
    }

    /// @notice Gets the current status for a consumer's ticket.
    /// @param _consumerId The consumer id.
    /// @return status The ticket status as a uint8.
    /// @return isWin True if the ticket is a winning ticket.
    /// @return chance The chance value recorded on the ticket.
    /// @return result The result value recorded on the ticket.
    function _getTicketStatus(uint256 _consumerId) internal view returns (uint8, bool, uint16, uint16) {
        uint256 ticketId = consumerIdToTicketId[_consumerId];
        if (ticketId == 0) {
            revert NoTicketFound(_consumerId);
        }

        (ISLPHub.TicketStatus status, bool isWin, uint16 chance, uint16 result) = hub.getTicketStatus(ticketId);

        // Case enum to uint8 to avoid requirement for importing ISLPHub in child contracts
        return (uint8(status), isWin, chance, result);
    }

    /// @notice Returns stored ticket details for a consumer.
    /// @param _consumerId The consumer id.
    /// @return status The ticket status enum.
    /// @return token The token used for the ticket.
    /// @return user The user that owns the ticket.
    /// @return stake The stake amount for the ticket.
    function _getTicketDetails(uint256 _consumerId)
        internal
        view
        returns (ISLPHub.TicketStatus status, address token, address user, uint112 stake)
    {
        uint256 ticketId = consumerIdToTicketId[_consumerId];
        if (ticketId == 0) {
            revert NoTicketFound(_consumerId);
        }

        ISLPHub.Ticket memory ticket = hub.tickets(ticketId);
        return (ticket.status, ticket.token, ticket.user, ticket.stake);
    }

    /// @notice Withdraws a user's SLP balance for a token.
    /// @dev Withdraws to this contract, must forward to user if required.
    /// @param _token The token to withdraw.
    /// @param _amount The amount to withdraw.
    /// @param _user The user whose balance is withdrawn.
    function _withdrawUserSlpBalance(address _token, uint256 _amount, address _user) internal {
        uint256 balance = _getUserSlpBalance(_token, _user);
        if (balance < _amount) {
            revert InsufficientBalance(balance, _amount);
        }

        // transfer asserted on hub
        hub.withdrawBalance(_token, _amount, _user);
    }

    /// @notice Cancels a consumer's ticket in the hub.
    /// @dev Only tickets in PENDING status can be cancelled.
    /// @dev Cancel period must have elapsed on the hub.
    /// @param _consumerId The consumer id.
    function _cancelTicket(uint256 _consumerId) internal {
        uint256 ticketId = consumerIdToTicketId[_consumerId];
        if (ticketId == 0) {
            revert NoTicketFound(_consumerId);
        }

        hub.cancelTicket(ticketId);
    }

    /// @notice Sets the name in the game registry.
    /// @dev Requires game registry to be set.
    /// @param _newName The name to set.
    function _setName(string memory _newName) internal {
        if (address(gamesRegistry) == address(0)) {
            revert GamesRegistryNotSet();
        }

        gamesRegistry.registerName(_newName);
    }

    /// @notice Get name in the game registry.
    /// @dev Requires game registry to be set.
    /// @return name The registered name.
    function _name() internal view returns (string memory) {
        if (address(gamesRegistry) == address(0)) {
            revert GamesRegistryNotSet();
        }

        return gamesRegistry.getName();
    }
}
