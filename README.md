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
#### `addPlayer()`
The game starts in the `WAITING` state. During this state, players can call `addPlayer()` to join the game. `addPlayer()`, as shown below, is a payable function, meaning that it accepts ETH payment.
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

#### `commit(bytes32 dataHash)`
In the `COMMIT` state, the user can call `commit(dataHash)`, where `dataHash` is a 32-byte digest, hashed from a 32-byte value created using [this Python script](https://colab.research.google.com/drive/1cPqxOqzJ-brL05pd0WRAwwwK0Zzx-Rnl?usp=sharing). The script randomly generates a 31-byte-long string, which will be concatinated by the stringified choice encoding in hex (i.e. `Rock = 00`, `Paper = 01`, `Scissors = 02`, etc.). This represents the 32nd byte of the pre-hash choice value. Then, the value is then put through a `keccak256` hash function, which should be done externally (not within a blockchain).

```solidity
// User commits a choice (rock, paper, scissors, lizard, or spock, in integer form)
// The choice is hashed inside commitReveal to prevent front-running
// dataHash must be hashed externally (using kekcak256) before being fed to commit()
function commit(bytes32 dataHash) public {
    require(playerInGame[msg.sender] == true, "Must be in game to commit");
    require(numPlayers == 2, "Requires at least two players in game to commit");
    require(playerCommited[msg.sender] == false, "Already commited");
    require(numCommits < 2, "Too many commits");
    
    // Can almost never revert
    commitReveal.commit(msg.sender, dataHash);
    
    // ... more code ... //
}
```

At the top of the method body, we can see multiple `require()` statements. These check if:
* The sender is a player in the game
* Two players are in the game
* If the sender hasn't committed yet
* If the commits are less than 2

All checks must succeed in order to successfully commit.

Next, we will call `commitReveal.commit(msg.sender, dataHash)`, which has the signature `CommitReveal::commit(address addr, bytes32 dataHash)`, with `addr` as the sender's address (`msg.sender`). The `commitReveal` contract will store the commit struct in a mapping at index `addr` as demonstrated by the code below. Additionally, it also emits the event `CommitHash`, but this, along with other events, will not be used.
```solidity
// contracts/CommitReveal.sol
function commit(address addr, bytes32 dataHash) public {
    commits[addr].commit = dataHash;
    commits[addr].block = uint64(block.number);
    commits[addr].revealed = false;
    emit CommitHash(addr, commits[addr].commit, commits[addr].block);
}
```

By storing the digest and not the raw choice, we effectively prevent cheaters from looking up their opponent's answer as the digest completely conceals the information, thus preventing **front-running**. 
However, this raises a question: how can we recover the choice if it's concealed? We will answer this in the next section. For now, we will describe the rest of the `commit()` method first.

```
function commit(bytes32 dataHash) public {
    // ... more code ... //
    numCommits++;
    playerCommited[msg.sender] = true;
    
    // Start the reveal phase after two players have committed
    if (numCommits == 2) {
      gamePhase = GamePhase.REVEAL;
      timeUnit.setStartTime();
    }
}
```

After a successful commit, we will increment the current number of commits `commit` by one and remember that the player has committed by setting `playerCommitted[msg.sender]` to `true`. This prevents them from committing again.
Next, if the number of commits is equal to 2, we transition from `COMMIT` to `REVEAL`, the state in which players begin revealing their committed answers, which requires the use of `reveal(...)`.

#### `reveal(bytes32 dataHash)`
```solidity
// contracts/RPS.sol

// User reveals the choice they have committed to
// A choice is accepted if they the hash matches the committed hash
// revealHash is not hashed, but padded with 31 random bytes with the final one being the choice (1 byte)
function reveal(bytes32 revealHash) public {
    require(playerInGame[msg.sender] == true, "Must be in game to reveal");
    require(playerRevealed[msg.sender] == false, "Already revealed");
    require(numCommits == 2, "Requires two commits to reveal");
    
    // Reverts if the hash does not match the committed hash
    commitReveal.reveal(msg.sender, revealHash);
    
    uint8 choice = uint8(revealHash[31]);
    require(choice < 5, "Invalid choice");
    playerChoices[msg.sender] = choice;
    playerRevealed[msg.sender] = true;
    numReveals++;
    
    // Pays the winner, ends and restarts the game after both players have revealed their choices
    if (numReveals == 2) {
      gamePhase = GamePhase.END;
      _checkWinnerAndPay();
      _startGame();
    }
}
```




