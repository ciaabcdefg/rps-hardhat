# Lab 5 (Rock, Paper, Scissors, Lizard and Spock)

This is Ittiwat Chuchoet's (อิทธิวัฒน์ ชูเชิด) submission for Centralized and Decentralized Finance class of 2024 (204496/219493), Department of Computer Engineering, Kasetsart University.

## Included in the Repo
### `/contracts`
From Paruj Ratanaworabhan's (`parujr`) [repository](https://github.com/parujr/RPS)
* `RPS.sol` - the contract containing the Rock, Paper, Scissors, Lizard, Spock game. Modified by me.
* `TimeUnit.sol` - the contract containing TimeUnit (records timestamps). Unmodified from source.
* `CommitReveal.sol` - the contract containing CommitReveal (used to prevent front-running). Probably from Austin Griffith's (`austintgriffith`) [`repository`](https://github.com/austintgriffith/commit-reveal), modified by me.

### `/test`
* `RPS.ts` — test file for `RPS.sol`, will not work unless player restriction logic in `addPlayer()` in `RPS.sol` is removed.
* For grading, you can ignore `/test` along with other files in the root directory.

## How It Works
`RPS.sol` depends on two contracts, namely `CommitReveal.sol` and `TimeUnit.sol`.
```solidity
// contracts/RPS.sol
import "contracts/CommitReveal.sol";
import "contracts/TimeUnit.sol";
```

The game has three states defined by this enum `GamePhase`. We define a variable `gamePhase` to help track the game's state. The detail of each state is shown in the accompanying comments.
```solidity
// contracts/RPS.sol
enum GamePhase {
    WAITING, // Waiting for players
    COMMIT, // Waiting for two players to commit
    REVEAL // Waiting for two players to reveal
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

We wil proceed to declare more variables, whose names should be self-explainatory or described by the accompanying comments.
```solidity
// contracts/RPS.sol
uint public reward = 0; // Stores reward in ETH

mapping(address => uint8) public playerChoices;
mapping(address => bool) public playerCommited;
mapping(address => bool) public playerRevealed;
mapping(address => bool) public playerInGame;

address public player0;
address public player1;
uint8 public numPlayers;

CommitReveal public commitReveal;
TimeUnit public timeUnit;
uint256 _commitTime; // Time in seconds after which players can withdraw after the commit phase begins
uint256 _revealTime; // Time in seconds after which players can withdraw after the reveal phase begins

uint8 public numCommits;
uint8 public numReveals;
```

Below this, there will be a lot of method declarations. We will walk through each of them one-by-one, including its dependencies.

### `constructor(uint256 commitTime, uint256 revealTime)`
This constructor method allows the deployer to specify how long the commit and reveal times are. After this duration is over, the players will be allowed to withdraw from the game with penalities in some cases.
This method sets the private variables `_commitTime` and `_revealTime` to the provided values `commitTime` and `revealTime`.
```solidity
// contracts/RPS.sol
// Provide the duration in seconds for the commit and reveal phases
constructor(uint256 commitTime, uint256 revealTime) {
    _commitTime = commitTime;
    _revealTime = revealTime;
    _startGame();
}
```

### `RPS::_startGame()`
This intializes the contract's state to their default values, providing a convenient way to reset a finished game.
```solidity
// contracts/RPS.sol
// Starts a new game
function _startGame() private {
    gamePhase = GamePhase.WAITING;
    
    reward = 0;
    playerChoices[player0] = 0;
    playerChoices[player1] = 0;
    
    delete playerCommited[player0];
    delete playerCommited[player1];
    delete playerInGame[player0];
    delete playerInGame[player1];
    delete playerRevealed[player0];
    delete playerRevealed[player1];
    
    player0 = address(0);
    player1 = address(0);
    numPlayers = 0;
    
    commitReveal = new CommitReveal();
    timeUnit = new TimeUnit();
    numCommits = 0;
    numReveals = 0;
}
```

### `RPS::addPlayer()`
The game starts in the `WAITING` state. During this state, players can call `addPlayer()` to join the game. `addPlayer()`, as shown below, is a payable function, meaning that it accepts ETH payment.
```solidity
// contracts/RPS.sol
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
// contracts/RPS.sol
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

Finally that, if there are now two players in the game, the game transitions from a `WAITING` to a `COMMIT` state. 
As explained earlier, this is the state in which players can commit their choices. Then, we will call `timeUnit.setStartTime()` to start the reveal deadline.

```solidity
// contracts/TimeUnit.sol
// setting the startTime variable
function setStartTime() public {
    startTime = block.timestamp;
}
```
This basically marks the current timestamp as the start time, which can be used to calculate elapsed time for our withdrawal mechanism which will be explained later.

### `RPS::commit(bytes32 dataHash)`
In the `COMMIT` state, the user can call `commit(dataHash)`, where `dataHash` is a 32-byte digest, hashed from a 32-byte value created using [this Python script](https://colab.research.google.com/drive/1cPqxOqzJ-brL05pd0WRAwwwK0Zzx-Rnl?usp=sharing). The script randomly generates a 31-byte-long string, which will be concatinated by the stringified choice encoding in hex (i.e. `Rock = 00`, `Paper = 01`, `Scissors = 02`, etc.). This represents the 32nd byte of the pre-hash choice value. Then, the value is then put through a `keccak256` hash function, which should be done externally (not within a blockchain).

```solidity
// contracts/RPS.sol
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

```solidity
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
Next, if the number of commits is equal to 2, we transition from `COMMIT` to `REVEAL`, the state in which players begin revealing their committed answers, which requires the use of `reveal(...)`. Next, we mark the current timestamp as the start time for elapsed time calculations by using `timeUnit.setStartTime()`.

### `RPS::reveal(bytes32 dataHash)`
Here we have `reveal(bytes32 revealHash)`. Despite its name, `revealHash` is not hashed, but rather the unhashed original choice value (see [here](#commitbytes32-datahash)). 
Below is a representation of the relationship between these two parameters.
```
revealHash ----> hash function ---> dataHash
```
We will use this method to reveal the committed answer by checking if the hash of the sender's choice that they claim to have committed matches with that of the stored commit. If it does, we accept that is actually the choice that they committed to. This way, we don't have to reverse the hash to find the recover the original choice (which is near impossible). Thus, we prevent front-running by not sacrificing the ability to recover the committed choice.

```solidity
// contracts/RPS.sol
// User reveals the choice they have committed to
// A choice is accepted if they the hash matches the committed hash
// revealHash is not hashed, but padded with 31 random bytes with the final one being the choice (1 byte)
function reveal(bytes32 revealHash) public {
    require(playerInGame[msg.sender] == true, "Must be in game to reveal");
    require(playerRevealed[msg.sender] == false, "Already revealed");
    require(numCommits == 2, "Requires two commits to reveal");
    // ... more code ... //
}
```
We start the method with a series of `require()` checks. They check if:
* The sender is a player in the game
* The player has not revealed their answer
* Require two commits to be made before revealing

All checks must pass in order to reveal the answer.

```solidity
// contracts/RPS.sol
function reveal(bytes32 revealHash) public {
    // ... more code ... //
    // Reverts if the hash does not match the committed hash
    commitReveal.reveal(msg.sender, revealHash);
    // ... more code ... //
}
```
If the checks succeed, we will proceed to call `commitReveal.reveal(msg.sender, revealHash)`, whose signature is `CommitReveal::reveal(address addr, bytes32 revealHash)`. `addr` is the sender's address (`msg.sender`).
Let's peek into `CommitReveal::reveal(...)` to see what it does.

```solidity
// contracts/CommitReveal.sol
// ciaabcdefg: Modified the reveal function to accept addr as well
// addr is used instead of msg.sender (msg.sender refers to the contract address, not the player)
function reveal(address addr, bytes32 revealHash) public {
    // make sure it hasn't been revealed yet
    require(
      commits[addr].revealed == false,
      "CommitReveal::reveal: Already revealed"
    );
    // require that they can produce the committed hash
    require(
      getHash(revealHash) == commits[addr].commit,
      "CommitReveal::reveal: Revealed hash does not match commit"
    );
    // require that the block number is greater than the original block
    require(
      uint64(block.number) > commits[addr].block,
      "CommitReveal::reveal: Reveal and commit happened on the same block"
    );
    // require that no more than 250 blocks have passed
    require(
      uint64(block.number) <= commits[addr].block + 250,
      "CommitReveal::reveal: Revealed too late"
    );
    // ... more code ... //
}
```
Above is a series of `require()` statements that check if:
* The commit hasn't been revealed
* The produced hash of `revealHash` is identical to the commit's
* Reveal and commit did not happen on the same block (cannot commit then reveal immediately)
* No more than 250 blocks have passed since the commit

Altogether, this prevents a player from withholding their choice for too long. Furthermore, enforcing reveals to happen in the future after commits to prevent them from exploiting instant commit-reveal mechanics.

```solidity
// contracts/CommitReveal.sol
function reveal(address addr, bytes32 revealHash) public {
    // ... more code ... // 
    // set to revealed    
    commits[addr].revealed = true;
    // get the hash of the block that happened after they committed
    bytes32 blockHash = blockhash(commits[addr].block);
    // hash that with their reveal that so miner shouldn't know and mod it with some max number you want
    uint random = uint(keccak256(abi.encodePacked(blockHash, revealHash))) %
      max;
    emit RevealHash(addr, revealHash, random);
}
```

If the checks pass, we will mark the commit as revealed to prevent it from being revealed again. Next, we will emit `RevealHash(addr, revealHash, random)` with `random` being the hash of the commit blockhash through a modulo of `max`. This part is irrelevant to the main game logic, but it introduces unpredictable randomness that prevents players from predicting outcomes.

Let's hop back to `reveal(...)` in `contracts/RPS.sol`.
```solidity
function reveal(address addr, bytes32 revealHash) public {
    // ... more code ... //
    uint8 choice = uint8(revealHash[31]);
    require(choice < 5, "Invalid choice");
    playerChoices[msg.sender] = choice;
    playerRevealed[msg.sender] = true;
    numReveals++;
    
    // Pays the winner, ends and restarts the game after both players have revealed their choices
    if (numReveals == 2) {
      _checkWinnerAndPay();
      _startGame();
    }
}
```
For us to get to this point, `commitReveal.reveal(...)` must not revert, that is the player's answer must be deemed acceptable before proceeding. Because we can trust the player's claims that they made this choice, we can extract the 32nd byte of `revealHash` to get the answer. We apply a type cast to the byte to transform it to a number from `0x00` (Rock) and `0x04` (Spock), then we record the choice in a mapping `playerChoice` at address `msg.sender`. Next, we will remember that this player has revealed their commit, and thus cannot reveal again. 

After two reveals, the game checks for the winner and pays them the reward accordingly by calling `_checkWinnerAndPay()`, which will be the next function we will get into. After that, [`_startGame()`](#_startgame) is called, which resets the game back to the default state.

### `RPS::_checkWinnerAndPay()`
```solidity
// contracts/RPS.sol
function _checkWinnerAndPay() private {
    uint8 p0Choice = playerChoices[player0];
    uint8 p1Choice = playerChoices[player1];
    address payable account0 = payable(player0);
    address payable account1 = payable(player1);
    
    ChoiceOutcomes result = _checkOutcome(p0Choice, p1Choice);
    // ... more code ... //
}
```

This method is called when the game finishes (after two reveals have been made). 
We simply extract the choice from the `playerChoices` mapping and run through a helper method named `_checkOutcome(p0Choice, p1Choice)`, whose signature is `RPS::_checkOutcome(uint8 moveA, uint8 moveB) returns (ChoiceOutcome)`. It returns a `ChoiceOutcome` enum, which can either be a win, a loss or a tie. The result is stored in a ChoiceOutcomes enum `result`.
`_checkOutcome(...)` is a pure function, meaning that it performs no state mutation. Here's what `_checkOutcome()` and `ChoiceOutcome` look like:

```solidity
// contracts/RPS.sol

// Outcomes of the Rock, Paper, Scissors, Lizard, Spock game
enum ChoiceOutcomes {
    WIN,
    LOSE,
    TIE
}

// Checks for the outcome of moveA against moveB
// Returns WIN if moveA wins, LOSE if moveA loses, and TIE if they tie
function _checkOutcome(
    uint8 moveA,
    uint8 moveB
    ) private pure returns (ChoiceOutcomes) {
    if (
      (moveA == 0 && (moveB == 2 || moveB == 3)) || // Rock beats Scissors & Lizard
      (moveA == 1 && (moveB == 0 || moveB == 4)) || // Paper beats Rock & Spock
      (moveA == 2 && (moveB == 1 || moveB == 3)) || // Scissors beats Paper & Lizard
      (moveA == 3 && (moveB == 1 || moveB == 4)) || // Lizard beats Paper & Spock
      (moveA == 4 && (moveB == 0 || moveB == 2)) // Spock beats Rock & Scissors
    ) {
      return ChoiceOutcomes.WIN;
    } else if (moveA == moveB) {
      return ChoiceOutcomes.TIE;
    } else {
      return ChoiceOutcomes.LOSE;
    }
}
```

I find it hard to implement Rock, Paper, Scissors, Lizard and Spock using modulo operations, so I opted in to using simple if-else statements instead. 
The code is as straightforward as it looks. For example, if moveA is Rock (0), and moveB is Scissors (2) or Lizard (3), moveA wins against moveB, etc. 
If moveA is equal to moveB, then it is a tie. Otherwise, moveA loses against moveB.

With the ins and outs of `_checkOutcome(...)` explained, we will be back to `_checkWinnerAndPay()`.

```solidity
function _checkWinnerAndPay() private {
    // ... more code ... //
    ChoiceOutcomes result = _checkOutcome(p0Choice, p1Choice);
    if (result == ChoiceOutcomes.WIN) {
      // Account 0 wins the reward
      account0.transfer(reward);
    } else if (result == ChoiceOutcomes.LOSE) {
      // Account 1 wins the reward
      account1.transfer(reward);
    } else {
      // Tie: split the reward in half
      account0.transfer(reward / 2);
      account1.transfer(reward / 2);
    }
}
```

Basically, `result` represents the outcome from `player0`'s perspective. 
Therefore, `result == ChoiceOutcomes.WIN` represents `player0`'s victory. If it is a loss, then it is `player1`'s. Otherwise, it is a tie.
In case of a decisive win or loss, the victor is rewarded 2 ETH, while the loser does not get their 1 ETH stake back. In case of a tie, each player is refunded 1 ETH.

### `RPS::withdraw()`
This is the final method in the contract, used by the players to withdraw after a certain time has passed. 
This prevents players from getting their funds locked in the game due to the other player's refusal to make a move, whether to commit or to reveal, thus deadlocking the game.

```solidity
// contracts/RPS.sol
// Allows players to withdraw mid-game, but under certain conditions
// Players can withdraw after the commit and reveal deadlines, with respect to the game phase in which they withdraw
// If a player withdraws after the other player has revealed their choice, the remaining player wins
function withdraw() public {
    require(
      playerInGame[msg.sender] == true,
      "Cannot withdraw if you are not in the game"
    );
    // ... more code ... //
}
```
The method starts with a single `require()` statement that checks if the sender is in the game. If they aren't, they cannot withdraw from the game, obviously.

```solidity
// contracts/RPS.sol
function withdraw() public {
    // ... more code ... //
    // Deadline check
    if (gamePhase == GamePhase.COMMIT) {
      require(
        timeUnit.elapsedSeconds() >= _commitTime,
        "Cannot withdraw before commit deadline"
      );
    } else if (gamePhase == GamePhase.REVEAL) {
      require(
        timeUnit.elapsedSeconds() >= _revealTime,
        "Cannot withdraw before reveal deadline"
      );
    }
    // ... more code ... //
}
```
We have an if-else statement that if depending on the state, contain `require()` a statement that checks if the elapsed time in seconds is greater or equal to the commit or reveal deadline times `_commitTime` and `_revealTime` respectively.
After this duration, the game will allow withdrawals.

```solidity
// contracts/RPS.sol
function withdraw() public {
    // ... more code ... //
    playerInGame[msg.sender] = false;
    playerChoices[msg.sender] = 0;
    numPlayers--;

    address remainingPlayer; // The other person who hasn't withdrawn

    // If the withdrawing player is player0, player1 is the remaining player and vice versa
    if (msg.sender == player0) {
      player0 = address(0);
      remainingPlayer = player1;
    } else if (msg.sender == player1) {
      player1 = address(0);
      remainingPlayer = player0;
    }
    // ... more code ... //
}
```
If withdrawal is permitted, the game loses a player. The player is marked to be out of the game, `numPlayer` is deducted by one and their choice is reset.
Next, we will declare a variable that stores the remaining player who hasn't withdrawn yet `remainingPlayer`, that is the player whose address is not equal to the sender's address `msg.sender`.
Then, an if-else statement will set the `remainingPlayer` using the aforementioned logic, and we also set `player0` or `player1` to the null address `address(0)` depending whose address is equal to the sender.

```solidity
// contracts/RPS.sol
function withdraw() public {
    // ... more code ... //
    if (playerCommited[msg.sender]) {
      playerCommited[msg.sender] = false;
      numCommits--;
    }

    if (playerRevealed[msg.sender]) {
      playerRevealed[msg.sender] = false;
      numReveals--;
    }
    // ... more code ... //
}
```
Following that, we will deduct the number of commits or reveals by one, depending on whether if they have made a commit or a reveal or not.

```solidity
// contracts/RPS.sol
function withdraw() public {
    // ... more code ... //
    if (gamePhase == GamePhase.REVEAL && numReveals == 1) {
      // If the player withdraws after the other player has revealed their answer,
      // they lose their share of the stake and the remaining player automatically wins
      address payable account = payable(remainingPlayer);
      account.transfer(reward); // The remaining player automatically wins 2 ETH (1 from the withdrawing player and 1 from themselves)
      _startGame(); // Reset the game!
      return;
    } else {
      // Otherwise, the withdrawing player gets their money back
      reward -= 1 ether;
      address payable account = payable(msg.sender);
      account.transfer(1 ether);
    }
    // ... more code ... //
}
```
However, in the reveal phase, if somebody has already revealed their choice, the other player might be able to see it via the transaction pool. 
If they see that the other's choice beats theirs, they can do nothing but accept their defeat as soon as they reveal theirs, as they cannot change their answer.
They can also try withholding their reveal forever, but they will also not get their stake back. 
Or, they can withdraw to get this over with, which will result in a tie (the other player is forced to withdraw as the game can never progress with only one player). 

To prevent this, we will make a rule so that if somebody has revealed their choice, a withdraw results in an immediate loss for the withdrawer.
The only player who has revealed their answer immediately wins a reward of 2 ETH.

This if-else statement makes sure that a withdraw cannot affect the future victor.

```solidity
// contracts/RPS.sol
function withdraw() public {
    // ... more code ... //
    // If there are no players left, the game is reset
    if (numPlayers == 0) {
      _startGame();
    }
}
```
Finally, if all players have withdrawn, the game is reset by calling `_startGame()`.
