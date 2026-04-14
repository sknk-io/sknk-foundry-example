// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISLPHub {
    enum TicketStatus {
        NONE,
        PENDING,
        SETTLED,
        CANCELLED,
        ERROR
    }

    // A structure representing a ticket
    struct Ticket {
        uint112 stake;
        uint64 timestamp;
        uint32 nonce;
        uint16 chance;
        uint16 result;
        bool isWin;
        TicketStatus status;
        uint8 tokenIndex;
        address caller;
        uint112 hedge;
        address user;
        address pair;
        address token;
        uint256 baseSupply;
        uint256 mintSnapshot;
        uint256 requestId;
    }

    function WETH_ADDRESS() external view returns (address);

    function balances(address token, address caller, address delegate) external view returns (uint256);

    function withdrawBalance(address _token, uint256 _amount, address _user) external;

    function validatePair(address _pair, address _token) external view returns (uint8);

    function computeTokenOutput(uint112 _stake, uint16 _chance)
        external
        view
        returns (uint112 netOutput, uint112 edge, uint112 netProfit, uint112 profit, uint112 platformFee);

    function createTicket(address _pair, address _token, uint112 _amount, uint16 _chance, address _user)
        external
        returns (uint256);

    function createTicketWithETH(address _pair, uint112 _amount, uint16 _chance, address _user)
        external
        payable
        returns (uint256);

    function tickets(uint256 ticketId) external view returns (Ticket memory);

    function getTicketStatus(uint256 ticketId) external view returns (TicketStatus, bool, uint16, uint16);

    function refundErrorTicket(uint256 _ticketId) external;

    function cancelTicket(uint256 _ticketId) external;
}
