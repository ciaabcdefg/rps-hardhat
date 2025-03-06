// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "contracts/CommitReveal.sol";
import "contracts/TimeUnit.sol";

contract RPS {
  enum GamePhase {
    WAITING,
    COMMIT,
    REVEAL,
    END
  }

  GamePhase public gamePhase;

  uint public reward = 0;
  mapping(address => uint8) public playerChoices;
  mapping(address => bool) public playerCommited;
  mapping(address => bool) public playerRevealed;
  mapping(address => bool) public playerInGame;

  address public player0;
  address public player1;
  uint8 public numPlayers;

  CommitReveal public commitReveal;

  TimeUnit public timeUnit;
  uint8 public numCommits;
  uint8 public numReveals;

  uint256 _commitTime;
  uint256 _revealTime;

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

  constructor(uint256 commitTime, uint256 revealTime) {
    _commitTime = commitTime;
    _revealTime = revealTime;
    _startGame();
  }

  function addPlayer() public payable {
    require(!playerInGame[msg.sender], "Already joined");
    require(numPlayers < 2, "Too many players");
    require(
      gamePhase == GamePhase.WAITING,
      "Cannot join when the game has started"
    );
    // require(
    //   msg.sender == 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 ||
    //     msg.sender == 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 ||
    //     msg.sender == 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db ||
    //     msg.sender == 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
    //   "You are not allowed to play this game"
    // );
    require(msg.value == 1 ether, "Provide 1 ETH to play the game");

    reward += msg.value;
    playerInGame[msg.sender] = true;

    if (player0 == address(0)) {
      player0 = msg.sender;
    } else if (player1 == address(0)) {
      player1 = msg.sender;
    }

    numPlayers++;

    if (numPlayers == 2) {
      gamePhase = GamePhase.COMMIT;
      timeUnit.setStartTime();
    }
  }

  function commit(bytes32 dataHash) public {
    require(playerInGame[msg.sender] == true, "Must be in game to commit");
    require(numPlayers == 2, "Requires at least two players in game to commit");
    require(playerCommited[msg.sender] == false, "Already commited");
    require(numCommits < 2, "Too many commits");

    commitReveal.commit(msg.sender, dataHash);
    numCommits++;
    playerCommited[msg.sender] = true;

    if (numCommits == 2) {
      gamePhase = GamePhase.REVEAL;
      timeUnit.setStartTime();
    }
  }

  function reveal(bytes32 revealHash) public {
    require(playerInGame[msg.sender] == true, "Must be in game to reveal");
    require(playerRevealed[msg.sender] == false, "Already revealed");
    require(numCommits == 2, "Requires two commits to reveal");

    commitReveal.reveal(msg.sender, revealHash);

    uint8 choice = uint8(revealHash[31]);
    require(choice < 5, "Invalid choice");
    playerChoices[msg.sender] = choice;
    playerRevealed[msg.sender] = true;
    numReveals++;

    if (numReveals == 2) {
      gamePhase = GamePhase.END;
      _checkWinnerAndPay();
      _startGame();
    }
  }

  function withdraw() public {
    require(
      playerInGame[msg.sender] == true,
      "Cannot withdraw if you are not in the game"
    );

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
    require(gamePhase != GamePhase.END, "Cannot withdraw after game ends");

    playerInGame[msg.sender] = false;
    playerChoices[msg.sender] = 0;
    numPlayers--;

    address remainingPlayer;

    if (msg.sender == player0) {
      player0 = address(0);
      remainingPlayer = player1;
    } else if (msg.sender == player1) {
      player1 = address(0);
      remainingPlayer = player0;
    }

    if (playerCommited[msg.sender]) {
      playerCommited[msg.sender] = false;
      numCommits--;
    }

    if (playerRevealed[msg.sender]) {
      playerRevealed[msg.sender] = false;
      numReveals--;
    }

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

    if (numPlayers == 0) {
      _startGame();
    }
  }

  enum GameResult {
    WIN,
    LOSE,
    TIE
  }

  function _checkWin(
    uint8 moveA,
    uint8 moveB
  ) private pure returns (GameResult) {
    if (
      (moveA == 0 && (moveB == 2 || moveB == 3)) || // Rock beats Scissors & Lizard
      (moveA == 1 && (moveB == 0 || moveB == 4)) || // Paper beats Rock & Spock
      (moveA == 2 && (moveB == 1 || moveB == 3)) || // Scissors beats Paper & Lizard
      (moveA == 3 && (moveB == 1 || moveB == 4)) || // Lizard beats Paper & Spock
      (moveA == 4 && (moveB == 0 || moveB == 2)) // Spock beats Rock & Scissors
    ) {
      return GameResult.WIN;
    } else if (moveA == moveB) {
      return GameResult.TIE;
    } else {
      return GameResult.LOSE;
    }
  }

  function _checkWinnerAndPay() private {
    uint8 p0Choice = playerChoices[player0];
    uint8 p1Choice = playerChoices[player1];
    address payable account0 = payable(player0);
    address payable account1 = payable(player1);

    GameResult result = _checkWin(p0Choice, p1Choice);
    if (result == GameResult.WIN) {
      account0.transfer(reward);
    } else if (result == GameResult.LOSE) {
      account1.transfer(reward);
    } else {
      account0.transfer(reward / 2);
      account1.transfer(reward / 2);
    }
  }
}
