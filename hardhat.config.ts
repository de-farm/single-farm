import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-ethers";
import "hardhat-abi-exporter";
import "@typechain/hardhat";

dotenv.config();

const config: HardhatUserConfig = {
  networks: {
    localhost: {
      chainId: 31337,
      url: "http://127.0.0.1:8545",
      timeout: 600000,
    },
    optimisticGoerli : {
      chainId: 420,
      url: process.env.GOERLI_OPT_URL || "https://goerli.optimism.io/",
      accounts: process.env.OWNER_PRIVATE_KEY &&
        process.env.ADMIN_PRIVATE_KEY &&
        process.env.TREASURY_PRIVATE_KEY &&
        process.env.MANAGER_PRIVATE_KEY &&
        process.env.USER_PRIVATE_KEY
        ?[
          process.env.OWNER_PRIVATE_KEY,
          process.env.ADMIN_PRIVATE_KEY,
          process.env.TREASURY_PRIVATE_KEY,
          process.env.MANAGER_PRIVATE_KEY,
          process.env.USER_PRIVATE_KEY
        ]:[],
    },
  },
  etherscan: {
    apiKey: {
      optimisticGoerli : process.env.ETHERSCAN_API_KEY || "",
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.18",
        settings: {
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
          optimizer: {
            enabled: true,
            runs: 20,
          },
        },
      },
    ],
  },
  typechain: {
    outDir: "./types",
    target: "ethers-v5",
  },
  abiExporter: {
    path: "./abi",
    clear: true,
    flat: true,
    only: [
      "DfVault",
      "Df",
      "Reader",
    ],
    spacing: 2,
  },
  mocha: {
    timeout: 100000000
  },
};

export default config;
