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
  mapping(address => uint) public playerChoices;
  mapping(address => bool) public playerCommited;
  mapping(address => bool) public playerInGame;

  address public player0;
  address public player1;
  uint public numPlayers;

  CommitReveal public commitReveal;

  TimeUnit public timeUnit;
  uint public numCommits;
  uint public numReveals;

  uint256 _commitTime = 5;
  uint256 _revealTime = 5;

  function _startGame() private {
    gamePhase = GamePhase.WAITING;

    reward = 0;
    playerChoices[player0] = 0;
    playerChoices[player1] = 0;
    delete playerCommited[player0];
    delete playerCommited[player1];
    playerInGame[player0] = false;
    playerInGame[player1] = false;

    player0 = address(0);
    player1 = address(0);
    numPlayers = 0;

    commitReveal = new CommitReveal();
    timeUnit = new TimeUnit();
    numCommits = 0;
    numReveals = 0;
  }

  constructor() {
    _startGame();
  }

  function addPlayer() public payable {
    require(!playerInGame[msg.sender], "Already joined");
    require(numPlayers < 2, "Too many players");
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
    require(numCommits == 2, "Requires two commits to reveal");
    commitReveal.reveal(msg.sender, revealHash);
    playerChoices[msg.sender] = uint8(revealHash[31]);
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

    reward -= 1 ether;
    playerInGame[msg.sender] = false;
    playerChoices[msg.sender] = 0;
    numPlayers--;

    if (msg.sender == player0) {
      player0 = address(0);
    } else if (msg.sender == player1) {
      player1 = address(0);
    }

    if (playerCommited[msg.sender]) {
      playerCommited[msg.sender] = false;
      numCommits--;
    }

    address payable account = payable(msg.sender);
    account.transfer(1 ether);

    if (numPlayers == 0) {
      _startGame();
    }
  }

  function _checkWinnerAndPay() private {
    uint p0Choice = playerChoices[player0];
    uint p1Choice = playerChoices[player1];
    address payable account0 = payable(player0);
    address payable account1 = payable(player1);

    if ((p0Choice + 1) % 3 == p1Choice) {
      // to pay player[1]
      account1.transfer(reward);
    } else if ((p1Choice + 1) % 3 == p0Choice) {
      // to pay player[0]
      account0.transfer(reward);
    } else {
      // to split reward
      account0.transfer(reward / 2);
      account1.transfer(reward / 2);
    }
  }
}
