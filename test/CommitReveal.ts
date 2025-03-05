// import { describe } from "mocha";

// import hre from "hardhat";
// import { ethers } from "hardhat";
// import { CommitReveal } from "../typechain-types";
// import { expect } from "chai";
// import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

// describe("CommitReveal", function () {
//   let commitReveal: CommitReveal;
//   let owner: HardhatEthersSigner, player: HardhatEthersSigner;

//   beforeEach(async function () {
//     const CommitRevealFactory = await ethers.getContractFactory("CommitReveal");
//     [owner, player] = await ethers.getSigners();
//     commitReveal = (await CommitRevealFactory.deploy()) as CommitReveal;
//     await commitReveal.waitForDeployment();
//   });

//   it("Should allow a player to commit a hash", async function () {
//     const data =
//       "0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c2701";
//     const dataHash = await commitReveal.getHash(data);

//     await commitReveal.commit(dataHash);

//     const commit = await commitReveal.commits(owner.address);
//     expect(commit.commit).to.equal(dataHash);
//     expect(commit.revealed).to.be.false;
//   });

//   it("Should allow a player to reveal a commit", async function () {
//     const data =
//       "0x4f84774697be7f748efe66f5d394739aa6a3a24a178e0b059a7245a17b6c2701";
//     const dataHash = await commitReveal.getHash(data);

//     await commitReveal.commit(dataHash);
//     await commitReveal.reveal(data);

//     const commit = await commitReveal.commits(owner.address);
//     expect(commit.commit).to.equal(dataHash);
//     expect(commit.revealed).to.be.true;
//   });
// });
