import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { CommitReveal, RPS } from "../typechain-types";
import { ethers } from "hardhat";
import { hexlify, keccak256, parseEther, toUtf8Bytes } from "ethers";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";

enum Choice {
  Rock,
  Paper,
  Scissors,
}

function choiceEnumToString(choice: Choice) {
  switch (choice) {
    case Choice.Rock:
      return "Rock";
    case Choice.Paper:
      return "Paper";
    case Choice.Scissors:
      return "Scissors";
  }
}

function hashData(data: string) {
  return keccak256(hexlify(data));
}

async function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

describe("RPS", function () {
  let rps: RPS;
  let commitReveal: CommitReveal;
  let owner: HardhatEthersSigner,
    player1: HardhatEthersSigner,
    player2: HardhatEthersSigner,
    decoyPlayer: HardhatEthersSigner;

  beforeEach(async function () {
    const RPSFactory = await ethers.getContractFactory("RPS");
    [owner, player1, player2, decoyPlayer] = await ethers.getSigners();
    rps = (await RPSFactory.deploy()) as RPS;

    await rps.waitForDeployment();

    const CommitRevealFactory = await ethers.getContractFactory("CommitReveal");
    commitReveal = CommitRevealFactory.attach(
      await rps.commitReveal()
    ) as CommitReveal;
  });

  async function play(
    choice1: Choice,
    choice2: Choice,
    silent: boolean = false
  ) {
    await rps.connect(player1).addPlayer({ value: parseEther("1") });
    await rps.connect(player2).addPlayer({ value: parseEther("1") });

    const player1InitialBalance = await ethers.provider.getBalance(player1);
    const player2InitialBalance = await ethers.provider.getBalance(player2);

    const player1Choice = choice1;
    const player2Choice = choice2;

    const player1Data = `0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c27${Number(
      player1Choice
    )
      .toString()
      .padStart(2, "0")}`;
    const player1Hash = hashData(player1Data);

    const player2Data = `0xeedd8270184578ef6b23157a021645e084d1373f6b795137fb6a2afc45eef7${Number(
      player2Choice
    )
      .toString()
      .padStart(2, "0")}`;
    const player2Hash = hashData(player2Data);

    await rps.connect(player1).commit(player1Hash);
    await rps.connect(player2).commit(player2Hash);

    // console.log(await commitReveal.commits(player1));
    // console.log(await commitReveal.commits(player2));

    const numCommits = await rps.numCommits();
    expect(numCommits).to.be.equal(2);

    await rps.connect(player1).reveal(player1Data);
    await rps.connect(player2).reveal(player2Data);

    const player1FinalBalance = await ethers.provider.getBalance(player1);
    const player2FinalBalance = await ethers.provider.getBalance(player2);

    if (!silent) {
      console.log();
      console.log("Choices:");
      console.log(
        "Player 1 =",
        choiceEnumToString(Number(await rps.playerChoices(player1)) as Choice)
      );
      console.log(
        "Player 2 =",
        choiceEnumToString(Number(await rps.playerChoices(player2)) as Choice)
      );
      console.log();
    }

    const player1BalanceDifference =
      player1FinalBalance - player1InitialBalance;
    const player2BalanceDifference =
      player2FinalBalance - player2InitialBalance;

    if (!silent) {
      console.log("Changes in Balance:");
      console.log(
        "Player 1 =",
        ethers.formatEther(player1FinalBalance - player1InitialBalance)
      );
      console.log(
        "Player 2 =",
        ethers.formatEther(player2FinalBalance - player2InitialBalance)
      );
      console.log();
    }

    return { player1BalanceDifference, player2BalanceDifference };
  }

  it("Should be equal", async function () {
    const data =
      "0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c2701";
    const hashedData = hashData(data);
    const hashedDataFromContract = await commitReveal.getHash(data);
    expect(hashedData).to.be.equal(hashedDataFromContract);
  });

  it("Should not fail", async function () {
    await play(Choice.Paper, Choice.Scissors);
  });

  async function playAndExpectWin(choice1: Choice, choice2: Choice) {
    const { player1BalanceDifference, player2BalanceDifference } = await play(
      choice1,
      choice2,
      true
    );

    expect(player1BalanceDifference).to.be.greaterThan(
      player2BalanceDifference
    );

    console.log(
      choiceEnumToString(choice1),
      "wins against",
      choiceEnumToString(choice2)
    );
  }

  async function playAndExpectLoss(choice1: Choice, choice2: Choice) {
    const { player1BalanceDifference, player2BalanceDifference } = await play(
      choice1,
      choice2,
      true
    );

    expect(player1BalanceDifference).to.be.lessThan(player2BalanceDifference);

    console.log(
      choiceEnumToString(choice1),
      "loses against",
      choiceEnumToString(choice2)
    );
  }

  it("Should not have side effects", async function () {
    console.log();
    await playAndExpectWin(Choice.Rock, Choice.Scissors);
    await playAndExpectWin(Choice.Scissors, Choice.Paper);
    await playAndExpectWin(Choice.Paper, Choice.Rock);
    await playAndExpectLoss(Choice.Rock, Choice.Paper);
    await playAndExpectLoss(Choice.Scissors, Choice.Rock);
    await playAndExpectLoss(Choice.Paper, Choice.Scissors);
    console.log();
  });

  it("Should fail because already joined", async function () {
    await rps.connect(player1).addPlayer({ value: parseEther("1") });
    await rps.connect(player2).addPlayer({ value: parseEther("1") });

    await expect(
      rps.connect(player1).addPlayer({ value: parseEther("1") })
    ).to.be.revertedWith("Already joined");
  });

  it("Should fail because too many players", async function () {
    await rps.connect(player1).addPlayer({ value: parseEther("1") });
    await rps.connect(player2).addPlayer({ value: parseEther("1") });

    await expect(
      rps.connect(decoyPlayer).addPlayer({ value: parseEther("1") })
    ).to.be.revertedWith("Too many players");
  });

  it("Commit should fail because not in game", async function () {
    await rps.connect(player1).addPlayer({ value: parseEther("1") });
    await rps.connect(player2).addPlayer({ value: parseEther("1") });

    const player1Data = `0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c27${Number(
      Choice.Paper
    )
      .toString()
      .padStart(2, "0")}`;
    const player1Hash = hashData(player1Data);

    const decoyData = `0xeedd8270184578ef6b23157a021645e084d1373f6b795137fb6a2afc45eef7${Number(
      Choice.Scissors
    )
      .toString()
      .padStart(2, "0")}`;
    const decoyHash = hashData(decoyData);

    await rps.connect(player1).commit(player1Hash);
    await expect(rps.connect(decoyPlayer).commit(decoyHash)).to.be.revertedWith(
      "Must be in game to commit"
    );
  });

  it("Reveal fail because not in game", async function () {
    await rps.connect(player1).addPlayer({ value: parseEther("1") });
    await rps.connect(player2).addPlayer({ value: parseEther("1") });

    const player1Data = `0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c27${Number(
      Choice.Paper
    )
      .toString()
      .padStart(2, "0")}`;
    const player1Hash = hashData(player1Data);

    const player2Data = `0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c27${Number(
      Choice.Rock
    )
      .toString()
      .padStart(2, "0")}`;
    const player2Hash = hashData(player2Data);

    const decoyData = `0xeedd8270184578ef6b23157a021645e084d1373f6b795137fb6a2afc45eef7${Number(
      Choice.Scissors
    )
      .toString()
      .padStart(2, "0")}`;

    const decoyHash = hashData(decoyData);

    await rps.connect(player1).commit(player1Hash);
    await rps.connect(player2).commit(player2Hash);

    await rps.connect(player1).reveal(player1Data);
    await rps.connect(player2).reveal(player2Data);
    await expect(rps.connect(decoyPlayer).reveal(decoyData)).to.be.revertedWith(
      "Must be in game to reveal"
    );
  });

  async function withdrawDeadlineSetup() {
    await rps.connect(player1).addPlayer({ value: parseEther("1") });
    await rps.connect(player2).addPlayer({ value: parseEther("1") });

    const player1Data = `0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c27${Number(
      Choice.Paper
    )
      .toString()
      .padStart(2, "0")}`;
    const player1Hash = hashData(player1Data);

    const player2Data = `0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c27${Number(
      Choice.Rock
    )
      .toString()
      .padStart(2, "0")}`;
    const player2Hash = hashData(player2Data);

    return { player1Hash, player2Hash };
  }

  // it("Should not let us withdraw before commit deadline", async function () {
  //   await withdrawDeadlineSetup();

  //   await expect(rps.connect(player1).withdraw()).to.be.revertedWith(
  //     "Cannot withdraw before commit deadline"
  //   );
  // });

  // it("Should let us withdraw after commit deadline", async function () {
  //   await withdrawDeadlineSetup();
  //   await sleep(2500);
  //   await rps.connect(player1).withdraw();
  // });

  // it("Should not let us withdraw before reveal deadline", async function () {
  //   const { player1Hash, player2Hash } = await withdrawDeadlineSetup();

  //   await rps.connect(player1).commit(player1Hash);
  //   await rps.connect(player2).commit(player2Hash);

  //   await expect(rps.connect(player1).withdraw()).to.be.revertedWith(
  //     "Cannot withdraw before reveal deadline"
  //   );
  // });

  // it("Should let us withdraw after reveal deadline", async function () {
  //   const { player1Hash, player2Hash } = await withdrawDeadlineSetup();

  //   await rps.connect(player1).commit(player1Hash);
  //   await rps.connect(player2).commit(player2Hash);

  //   await sleep(2500);

  //   await rps.connect(player1).withdraw();
  // });
});
