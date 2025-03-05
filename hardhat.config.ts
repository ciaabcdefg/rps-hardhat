import type { HardhatUserConfig } from "hardhat/config";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-toolbox-viem/network-helpers";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
};

export default config;
