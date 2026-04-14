// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {DemoGame} from "src/DemoGame.sol";
import {ISLPHub} from "src/interfaces/ISLPHub.sol";
import {SLPConsumerBase} from "src/SLPConsumerBase.sol";

import {MockERC20, MockGamesRegistry, MockSLPHub, SLPConsumerBaseHarness} from "test/mocks/MockSLPFixtures.sol";

contract DemoGameTest is Test {
    event GamePlayed(
        address indexed user,
        address indexed pair,
        address indexed token,
        uint112 stake,
        uint16 chance,
        uint256 consumerId
    );

    event UserWithdrawn(address indexed user, address indexed token, uint256 amount);

    DemoGame private game;
    MockSLPHub private hub;
    MockERC20 private token;
    MockGamesRegistry private registry;
    SLPConsumerBaseHarness private harness;

    address private admin = address(0xA11CE);
    address private user = address(0xBEEF);
    address private pair = address(0xCAFE);
    address private weth = address(0x0000000000000000000000000000000000009999);

    function setUp() public {
        token = new MockERC20("Mock", "MOCK");
        hub = new MockSLPHub(weth);
        game = new DemoGame(address(hub), admin);
        registry = new MockGamesRegistry();
        harness = new SLPConsumerBaseHarness(address(hub));

        token.mint(user, 1_000 ether);
    }

    function testPlayPullsOutstandingAndCreatesTicket() public {
        uint112 stake = 100 ether;
        hub.setBalance(address(token), address(game), user, 40 ether);

        vm.startPrank(user);
        token.approve(address(game), stake);
        vm.expectEmit(true, true, true, true);
        emit GamePlayed(user, pair, address(token), stake, 500, 1);
        game.play(pair, address(token), stake, 500);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 1_000 ether - 60 ether);
        assertEq(token.balanceOf(address(game)), 60 ether);
        assertEq(token.allowance(address(game), address(hub)), 0);
        assertEq(hub.lastObservedAllowance(), stake);
        assertEq(game.lastConsumerId(), 1);
        assertEq(game.consumerIdToTicketId(1), 1);

        ISLPHub.Ticket memory ticket = hub.tickets(1);
        assertEq(ticket.stake, stake);
        assertEq(ticket.user, user);
        assertEq(ticket.token, address(token));
    }

    function testPlayDoesNotPullWhenHubBalanceAlreadyCoversStake() public {
        uint112 stake = 100 ether;
        hub.setBalance(address(token), address(game), user, 200 ether);

        vm.prank(user);
        game.play(pair, address(token), stake, 500);

        assertEq(token.balanceOf(user), 1_000 ether);
        assertEq(token.balanceOf(address(game)), 0);
        assertEq(token.allowance(address(game), address(hub)), 0);
        assertEq(hub.lastObservedAllowance(), stake);
    }

    function testPlayUsesExactAllowancePerCall() public {
        uint112 firstStake = 25 ether;
        uint112 secondStake = 75 ether;

        hub.setBalance(address(token), address(game), user, 1_000 ether);

        vm.prank(user);
        game.play(pair, address(token), firstStake, 111);
        assertEq(hub.lastObservedAllowance(), firstStake);
        assertEq(token.allowance(address(game), address(hub)), 0);

        vm.prank(user);
        game.play(pair, address(token), secondStake, 222);
        assertEq(hub.lastObservedAllowance(), secondStake);
        assertEq(token.allowance(address(game), address(hub)), 0);
    }

    function testPlayWithETHRevertsOnWrongAmount() public {
        vm.expectRevert(DemoGame.InvalidEthAmount.selector);
        game.playWithETH(pair, 1 ether, 500);
    }

    function testPlayWithETHCreatesTicketAndEmitsWrappedTokenAddress() public {
        uint112 stake = 2 ether;
        vm.deal(user, 10 ether);

        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit GamePlayed(user, pair, weth, stake, 1234, 1);
        game.playWithETH{value: stake}(pair, stake, 1234);
        vm.stopPrank();

        assertEq(game.lastConsumerId(), 1);
        assertEq(game.consumerIdToTicketId(1), 1);
        assertEq(address(hub).balance, stake);

        ISLPHub.Ticket memory ticket = hub.tickets(1);
        assertEq(ticket.stake, stake);
        assertEq(ticket.user, user);
        assertEq(ticket.token, weth);
    }

    function testGetGameResultReturnsHubStatus() public {
        uint112 stake = 5 ether;
        vm.deal(user, 10 ether);

        vm.prank(user);
        game.playWithETH{value: stake}(pair, stake, 777);

        hub.setTicketStatus(1, ISLPHub.TicketStatus.SETTLED, true, 777, 321);

        (uint8 status, bool isWin, uint16 chance, uint16 result) = game.getGameResult(1);
        assertEq(status, uint8(ISLPHub.TicketStatus.SETTLED));
        assertTrue(isWin);
        assertEq(chance, 777);
        assertEq(result, 321);
    }

    function testGetGameResultRevertsWhenConsumerIdMissing() public {
        vm.expectRevert(abi.encodeWithSelector(SLPConsumerBase.NoTicketFound.selector, 999));
        game.getGameResult(999);
    }

    function testGetTicketDetailsRevertsWhenConsumerIdMissing() public {
        vm.expectRevert(abi.encodeWithSelector(SLPConsumerBase.NoTicketFound.selector, 999));
        harness.getTicketDetailsHarness(999);
    }

    function testWithdrawTransfersTokensAndEmitsEvent() public {
        uint256 amount = 50 ether;
        token.mint(address(game), amount);
        hub.setBalance(address(token), address(game), user, amount);

        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit UserWithdrawn(user, address(token), amount);
        game.withdraw(address(token), amount);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 1_000 ether + amount);
        assertEq(hub.balances(address(token), address(game), user), 0);
    }

    function testSetNameRegistersInRegistry() public {
        vm.prank(admin);
        game.setRegistryName(address(registry), "Demo Game");

        assertEq(game.name(), "Demo Game");
    }

    function testSetNameRevertsForNonOperator() public {
        vm.prank(user);
        vm.expectRevert();
        game.setRegistryName(address(registry), "Demo Game");
    }

    function testNameRevertsWhenRegistryNotSet() public {
        vm.expectRevert(SLPConsumerBase.GamesRegistryNotSet.selector);
        game.name();
    }
}
