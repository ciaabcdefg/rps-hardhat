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
We will define an enum `GamePhase` and a state `gamePhase` to help track the game's state. The details are shown in the accompanying comments.
```solidity
enum GamePhase {
    WAITING, // Waiting for players
    COMMIT, // Waiting for two players to commit
    REVEAL, // Waiting for two players to reveal
    END // Game ended (probably unused)
  }

GamePhase public gamePhase;
```
Here is a basic representation of the game's states:
```
             2 players joined            2 players commited            2 players revealed
--> WAITING -----------------> COMMIT ---------------------> REVEAL -----------------------
       ^                         |  no players left            |  no players left         |
       |                         v                             v                          |
       ------------------------- o <-------------------------- o <-------------------------
```
The game starts in the `WAITING` state. During this state, players can call `addPlayer()` to join the game. `addPlayer()`, as shown below, is a payable function, meaning that it accepts ETH payment.
#### `addPlayer()`
```solidity
// Adds a player to the game
// Players must provide 1 ETH to join the game
// Only permitted players can join the game (refer to the 4-line require statement)
function addPlayer() public payable {
    require(!playerInGame[msg.sender], "Already joined");
    require(numPlayers < 2, "Too many players");
    require(
      gamePhase == GamePhase.WAITING,
      "Cannot join when the game has started"
    );
    // Only permitted players can join the game
    require(
      msg.sender == 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 ||
        msg.sender == 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 ||
        msg.sender == 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db ||
        msg.sender == 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
      "You are not allowed to play this game"
    );
    require(msg.value == 1 ether, "Provide 1 ETH to play the game");
    // ... more code ... //
}
```
Above is a series of `require()` statements. They are checking if:
* The sender is not in the game
* If there are less than 2 players
* If the game hasn't started
* If the sender is allowed to play the game 
* If the inbound payment is 1 ETH

All checks must succeed in order for a player to join a game.
Now, let's take at the code below it.

```solidity
function addPlayer() public payable {
    // ... more code ... //
    reward += msg.value;
    playerInGame[msg.sender] = true;

    if (player0 == address(0)) {
      player0 = msg.sender;
    } else if (player1 == address(0)) {
      player1 = msg.sender;
    }

    numPlayers++;

    // Start the commit phase after two players have joined
    if (numPlayers == 2) {
      gamePhase = GamePhase.COMMIT;
      timeUnit.setStartTime();
    }
}
```

If successful, `reward` will be incremented by the amount of ETH sent by the sender (1 ether), which will eventually be rewarded to the winner of the game by the end of the game.
Next, we set `playerInGame[msg.sender] = true;` to prevent the player from joining twice, thus preventing them from infinitely joining to increase the reward.

Then, the address of the sender will be assigned to either `player0` or `player1`, depending on which one is vacant (`address(0)`).
After that, we will increment the number of players by one.

Finally, if there are now two players in the game, the game transitions from a `WAITING` to a `COMMIT` state. As explained earlier, this is the state in which players can commit their choices.

#### HELLO

