import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// import * as dotenv from "dotenv";  if you intend using dotenv
// dotenv.config();

const ACCOUNT_PRIVATE_KEY = vars.get("ACCOUNT_PRIVATE_KEY");
const LISK_RPC_URL = vars.get("LISK_RPC_URL");
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    // settings: {
    //   optimizer: {
    //     enabled: true,
    //     runs: 200, // Try adjusting the number of runs
    //   },
    //   viaIR: true, // Enable IR-based compilation
    // },
  },
  networks: {
    // for testnet
    "lisk-sepolia": {
      url: `${LISK_RPC_URL}`!,
      accounts: [`${ACCOUNT_PRIVATE_KEY}`],
      gasPrice: 1000000000,
    },
  },
  etherscan: {
    // Use "123" as a placeholder, because Blockscout doesn't need a real API key, and Hardhat will complain if this property isn't set.
    apiKey: {
      "lisk-sepolia": "123",
    },
    customChains: [
      {
        network: "lisk-sepolia",
        chainId: 4202,
        urls: {
          apiURL: "https://sepolia-blockscout.lisk.com/api",
          browserURL: "https://sepolia-blockscout.lisk.com/",
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
};

export default config;
