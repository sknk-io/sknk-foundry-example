# AGENTS.md

## Repo goal
This repo is a compact Foundry reference example for a game that integrates with the SLP protocol. Contracts should follow the same integration pattern as `src/DemoGame.sol` built on `src/SLPConsumerBase.sol`.

## Repo setup
- Dependencies are managed with Soldeer. Keep `soldeer.lock` checked in and use Soldeer to install/update Solidity packages.
- Run `forge soldeer install` if `/dependencies` folder is empty. If this fails, consider it fatal and do not continue. Prompt user to fix.
- Build and tests use Foundry. Run `forge build` for compilation and `forge test` for the test suite.
- Foundry configuration lives in `foundry.toml`; update remappings via Soldeer rather than manual edits.

## Core integration flow (required)
1. Inherit `SLPConsumerBase` and pass the hub address in the constructor.
2. When a user plays, use `_getUserSlpBalance(token, user)` to see if the hub already holds funds for that user.
3. If balance is short, pull only the outstanding amount from the user into the game contract.
4. Approve the hub for exactly the stake amount you will send.
5. Create the ticket via `_createTicket(pair, token, stake, chance, user)` or `_createTicketWithETH(pair, stake, chance, user)`.
6. Emit a game event with the returned `consumerId` so off-chain can track the play.

## ETH flow (required)
- Require `msg.value == stake` before calling `_createTicketWithETH`.
- The hub wraps ETH into WETH; the token address for the ticket is `hub.WETH_ADDRESS()`.

## Game registry integration (optional)
1. Set the registry once via `_setGamesRegistry(address)` (for example, in your constructor). Zero address reverts.
2. To register the game name, call `_setName(string)`; it reverts if the registry is not set.
3. To read the registered name, call `_name()`; it also reverts if the registry is not set.
4. Use this only when you intend to integrate with the on-chain game registry.

## Ticket tracking and result queries
- The `consumerId` returned by `_createTicket` is a game-level id that maps to the hub ticket id.
- Use `_getTicketStatus(consumerId)` for the current status and result.
- If you need raw ticket fields (token, user, stake), use `_getTicketDetails(consumerId)`.

## Withdrawals (required)
1. Call `_withdrawUserSlpBalance(token, amount, user)` which pulls funds from the hub to the game contract.
2. Transfer the withdrawn tokens to the user.
3. Emit a withdrawal event.

## Cancellation and error handling
- `_cancelTicket(consumerId)` can be used for tickets that are still `PENDING` and past the hub cancel period.
- Hub tickets can move to `ERROR` on VRF or pair failures. Consider adding a game-level refund path if you expose error recovery.

## Expected contract behaviors
- The game contract is the hub “caller,” so hub balances are keyed by `(token, game contract, user)`.
- Wins are credited to the hub balance; they are not paid out directly to the user.
- The game contract must forward withdrawals to the user; the hub only transfers to the game contract.

## Security and UX notes
- Use `SafeERC20` for token transfers.
- Minimize approvals: approve only the stake amount per play.
- Consider `nonReentrant` on play and withdraw in production games.
- Emit consistent events for `play`, `result`, and `withdraw` so indexers can reconstruct state.

## Reference files
- `src/DemoGame.sol`
- `src/SLPConsumerBase.sol`
- `src/interfaces/ISLPHub.sol`
- `src/interfaces/IGamesRegistry.sol`
