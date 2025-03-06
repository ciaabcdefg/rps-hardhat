// SPDX-License-Identifier: GPL-3.0
// Originally by Austin Griffith (austintgriffith on GitHub), through https://github.com/austintgriffith/commit-reveal/tree/master
// Modified by Paruj Ratanaworabhan (parujr on GitHub), through https://github.com/parujr/RPS/blob/main/CommitReveal.sol
// Modified by Ittiwat Chuchoet (ciaabcdefg on GitHub)

pragma solidity >=0.8.2 <0.9.0;

contract CommitReveal {
  uint8 public max = 100;

  struct Commit {
    bytes32 commit;
    uint64 block;
    bool revealed;
  }

  mapping(address => Commit) public commits;

  // ciaabcdefg: Modified the reveal function to accept addr as well
  // addr is used instead of msg.sender (msg.sender refers to the contract address, not the player)
  function commit(address addr, bytes32 dataHash) public {
    commits[addr].commit = dataHash;
    commits[addr].block = uint64(block.number);
    commits[addr].revealed = false;
    emit CommitHash(addr, commits[addr].commit, commits[addr].block);
  }

  event CommitHash(address sender, bytes32 dataHash, uint64 block);

  // ciaabcdefg: Modified the reveal function to accept addr as well
  // addr is used instead of msg.sender (msg.sender refers to the contract address, not the player)
  // ciaabcdefg: Moved commits[addr].revealed = true; to the bottom to follow the Checks-Effects-Interactions pattern
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
    // set to revealed
    commits[addr].revealed = true;
    // get the hash of the block that happened after they committed
    bytes32 blockHash = blockhash(commits[addr].block);
    // hash that with their reveal that so miner shouldn't know and mod it with some max number you want
    uint random = uint(keccak256(abi.encodePacked(blockHash, revealHash))) %
      max;
    emit RevealHash(addr, revealHash, random);
  }

  event RevealHash(address sender, bytes32 revealHash, uint random);

  function getHash(bytes32 data) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(data));
  }
}
