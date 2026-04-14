<p align="center">
  <img
    src="https://github.com/user-attachments/assets/5e020b3c-6d4e-4a1c-a15d-1d627afcdb0f"
    alt="sknk-logo"
    width="200"
  />
</p>
<br />

# SKNK Foundry Example

This repo is for a Solidity / Foundry developer who wants to integrate a game contract with the SKNK protocol.

The main thing you should take from this repo is the contract integration pattern in [src/DemoGame.sol](src/DemoGame.sol) and [src/SLPConsumerBase.sol](src/SLPConsumerBase.sol). Everything else exists to make that pattern easy to inspect, test, and adapt.

## Start Here

Read these files in this order:

1. [src/DemoGame.sol](src/DemoGame.sol)
2. [src/SLPConsumerBase.sol](src/SLPConsumerBase.sol)
3. [src/interfaces/ISLPHub.sol](src/interfaces/ISLPHub.sol)
4. [test/DemoGame.t.sol](test/DemoGame.t.sol)

If you are evaluating how to wire your own game into SKNK, that is the whole path.

## What To Reuse

In most cases you should:

- inherit `SLPConsumerBase`
- copy the core `play`, `playWithETH`, and `withdraw` flow from `DemoGame`
- replace `DemoGame` with your own game-specific contract and events
- keep the hub-facing sequence the same unless your protocol assumptions differ

You do not need to keep the example role model, registry helper, or exact event names unless they fit your game.

## What This Repo Is Not

- not a frontend example
- not a monorepo starter kit
- not a production-ready game contract
- not an opinionated game framework

It is a narrow contract reference repo for consumers of the SLP protocol.

## Contract Integration Pattern

The expected flow for an SLP-integrated game contract is:

1. Inherit `SLPConsumerBase` and pass the hub address in your constructor.
2. When a user plays, check whether the hub already holds balance for that user with `_getUserSlpBalance(token, user)`.
3. If the hub balance is short, pull only the outstanding amount from the user into your game contract.
4. Approve the hub for the exact stake amount for that play.
5. Create the ticket with `_createTicket(...)` or `_createTicketWithETH(...)`.
6. Emit an event with the returned `consumerId`.
7. Query status later with `_getTicketStatus(consumerId)`.
8. When withdrawing, call `_withdrawUserSlpBalance(...)`, then forward funds to the user.

Important model details:

- `consumerId` is the game-level id returned by your contract
- the hub ticket id is separate and stored in `consumerIdToTicketId`
- hub balances are keyed by `(token, game contract, user)`
- wins are credited to hub balance first, not paid directly to the user

## ERC20 Play Flow

`DemoGame.play(pair, token, stake, chance)` shows the ERC20 path:

- read the user's existing hub balance
- pull only the shortfall from the wallet
- approve the hub for that play
- create the ticket
- emit `GamePlayed(..., consumerId)`

The important part is that the contract does not blindly pull the full stake if the hub already holds funds for that user.

## ETH Play Flow

`DemoGame.playWithETH(pair, stake, chance)` shows the ETH path:

- require `msg.value == stake`
- call `_createTicketWithETH(...)`
- emit the event using `hub.WETH_ADDRESS()` as the token address

The hub is responsible for wrapping ETH into WETH.

## Withdraw Flow

`DemoGame.withdraw(token, amount)` shows the expected withdrawal path:

1. withdraw the user balance from the hub into the game contract
2. transfer the withdrawn tokens to the user
3. emit a withdrawal event

The hub does not send funds directly to the player. Your game contract must forward them.

## Optional Registry Flow

If your game wants on-chain name registration:

- set the registry with `_setGamesRegistry(address)`
- set the name with `_setName(string)`
- read the name with `_name()`

This is optional. It is not required for the core SLP integration flow.

## Adapting `DemoGame` Into Your Contract

The normal customization path is:

- rename `DemoGame` to your own contract
- keep `SLPConsumerBase` as the integration layer
- replace the example events with your own game events
- add your own game state and result handling around `consumerId`
- keep withdrawals explicit and user-directed

If you change only one thing, change the game logic around ticket creation, not the hub interaction sequence itself.

## Repo Layout

- [src/DemoGame.sol](src/DemoGame.sol) - reference consumer contract
- [src/SLPConsumerBase.sol](src/SLPConsumerBase.sol) - reusable hub integration helpers
- [src/interfaces/ISLPHub.sol](src/interfaces/ISLPHub.sol) - expected hub interface
- [src/interfaces/IGamesRegistry.sol](src/interfaces/IGamesRegistry.sol) - optional registry interface
- [test/DemoGame.t.sol](test/DemoGame.t.sol) - behavior tests for the example contract
- [test/mocks/MockSLPFixtures.sol](test/mocks/MockSLPFixtures.sol) - mocks and harnesses used by the tests
- [script/Deploy.s.sol](script/Deploy.s.sol) - example deploy script

## Local Setup

Requirements:

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity `0.8.20`
- Soldeer via Foundry

Dependencies are not checked into git. Install them locally first:

```sh
forge soldeer install
```

Then run:

```sh
forge build
forge test
forge fmt --check
```

CI uses the same commands.


## Deploying The Example

The deploy script in [script/Deploy.s.sol](script/Deploy.s.sol) expects:

- `DEPLOYER_PRIVATE_KEY`
- `SLP_HUB_ADDRESS`
- `ADMIN_ADDRESS`

Set up local env values:

```sh
cp .env.example .env
set -a && source .env && set +a
```

Deploy:

```sh
forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast
```

## Production Notes

- this repo is a reference example, not an audited system
- use `SafeERC20` and keep approvals scoped tightly
- consider `nonReentrant` on play and withdraw paths in production
- validate cancel windows, error flows, and settlement assumptions against the actual hub you are integrating with
- emit consistent play, result, and withdrawal events so off-chain systems can reconstruct state
