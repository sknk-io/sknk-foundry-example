// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IGamesRegistry} from "src/interfaces/IGamesRegistry.sol";
import {ISLPHub} from "src/interfaces/ISLPHub.sol";
import {SLPConsumerBase} from "src/SLPConsumerBase.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockSLPHub is ISLPHub {
    address public WETH_ADDRESS;

    uint256 public nextTicketId = 1;
    uint256 public lastObservedAllowance;
    mapping(address token => mapping(address caller => mapping(address delegate => uint256))) public balances;
    mapping(uint256 ticketId => Ticket) private storedTickets;
    mapping(uint256 ticketId => TicketStatus) public ticketStatus;
    mapping(uint256 ticketId => bool) public ticketWin;
    mapping(uint256 ticketId => uint16) public ticketChance;
    mapping(uint256 ticketId => uint16) public ticketResult;

    constructor(address weth) {
        WETH_ADDRESS = weth;
    }

    function setBalance(address token, address caller, address delegate, uint256 amount) external {
        balances[token][caller][delegate] = amount;
    }

    function setTicketStatus(uint256 ticketId, TicketStatus status, bool isWin, uint16 chance, uint16 result) external {
        ticketStatus[ticketId] = status;
        ticketWin[ticketId] = isWin;
        ticketChance[ticketId] = chance;
        ticketResult[ticketId] = result;
    }

    function withdrawBalance(address _token, uint256 _amount, address _user) external {
        uint256 current = balances[_token][msg.sender][_user];
        require(current >= _amount, "insufficient");
        balances[_token][msg.sender][_user] = current - _amount;
    }

    function validatePair(address, address) external pure returns (uint8) {
        return 1;
    }

    function computeTokenOutput(uint112, uint16)
        external
        pure
        returns (uint112 netOutput, uint112 edge, uint112 netProfit, uint112 profit, uint112 platformFee)
    {
        return (0, 0, 0, 0, 0);
    }

    function createTicket(address _pair, address _token, uint112 _amount, uint16 _chance, address _user)
        external
        returns (uint256)
    {
        lastObservedAllowance = IERC20(_token).allowance(msg.sender, address(this));

        uint256 ticketId = nextTicketId++;
        storedTickets[ticketId] = Ticket({
            stake: _amount,
            timestamp: uint64(block.timestamp),
            nonce: 0,
            chance: _chance,
            result: 0,
            isWin: false,
            status: TicketStatus.PENDING,
            tokenIndex: 0,
            caller: msg.sender,
            hedge: 0,
            user: _user,
            pair: _pair,
            token: _token,
            baseSupply: 0,
            mintSnapshot: 0,
            requestId: 0
        });
        ticketStatus[ticketId] = TicketStatus.PENDING;
        ticketChance[ticketId] = _chance;
        return ticketId;
    }

    function createTicketWithETH(address _pair, uint112 _amount, uint16 _chance, address _user)
        external
        payable
        returns (uint256)
    {
        require(msg.value == _amount, "bad value");
        uint256 ticketId = nextTicketId++;
        storedTickets[ticketId] = Ticket({
            stake: _amount,
            timestamp: uint64(block.timestamp),
            nonce: 0,
            chance: _chance,
            result: 0,
            isWin: false,
            status: TicketStatus.PENDING,
            tokenIndex: 0,
            caller: msg.sender,
            hedge: 0,
            user: _user,
            pair: _pair,
            token: WETH_ADDRESS,
            baseSupply: 0,
            mintSnapshot: 0,
            requestId: 0
        });
        ticketStatus[ticketId] = TicketStatus.PENDING;
        ticketChance[ticketId] = _chance;
        return ticketId;
    }

    function tickets(uint256 ticketId) external view returns (Ticket memory) {
        return storedTickets[ticketId];
    }

    function getTicketStatus(uint256 ticketId) external view returns (TicketStatus, bool, uint16, uint16) {
        return (ticketStatus[ticketId], ticketWin[ticketId], ticketChance[ticketId], ticketResult[ticketId]);
    }

    function refundErrorTicket(uint256) external {}

    function cancelTicket(uint256) external {}
}

contract MockGamesRegistry is IGamesRegistry {
    mapping(address caller => string name) private names;

    function registerName(string calldata _name) external {
        names[msg.sender] = _name;
    }

    function getName() external view returns (string memory name) {
        return names[msg.sender];
    }
}

contract SLPConsumerBaseHarness is SLPConsumerBase {
    constructor(address hub_) SLPConsumerBase(hub_) {}

    function registerTicket(uint256 ticketId) external returns (uint256) {
        return _registerTicket(ticketId);
    }

    function getTicketStatusHarness(uint256 consumerId) external view returns (uint8, bool, uint16, uint16) {
        return _getTicketStatus(consumerId);
    }

    function getTicketDetailsHarness(uint256 consumerId)
        external
        view
        returns (ISLPHub.TicketStatus status, address token, address user, uint112 stake)
    {
        return _getTicketDetails(consumerId);
    }
}
