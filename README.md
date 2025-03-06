# Lab 5 (Rock, Paper, Scissors, Lizard and Spock)

This is my submission for Centralized and Decentralized Finance class of 2024 (204496/219493), Department of Computer Engineering, Kasetsart University.

## Included in the Repo
### `/contracts`
* `RPS.sol` - the contract containing the Rock, Paper, Scissors, Lizard, Spock game
* `TimeUnit.sol` - the contract containing TimeUnit (records timestamps)
* `CommitReveal.sol` - the contract containing CommitReveal (used to prevent front-running)
### `/test`
* `RPS.ts` — test file for `RPS.sol`, will not work unless player restriction logic in `addPlayer()` in `RPS.sol` is removed.
* For grading, you can ignore `/test` along with other files in the root directory.

## How It Works
### `RPS.sol`
