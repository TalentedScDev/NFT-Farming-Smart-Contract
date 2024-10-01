import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotEnv from "dotenv";
dotEnv.config({ path: `${__dirname}/.env` });

const config: HardhatUserConfig = {
  solidity: {
    settings: {
      optimizer: {
        enabled: true,
        runs: 100
      },
      viaIR: true,
    },
    compilers: [
      {
        version: "0.7.6", // Compatible with Uniswap V3 libraries
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          viaIR: true,
        }
      },
      {
        version: "0.8.27",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          viaIR: true,
        }
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  },
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {
      gas: "auto",
      allowUnlimitedContractSize: false,
      mining: {
        mempool: {
          order: "fifo"
        }
      }
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      chainId: 11155111,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      accounts: [process.env.PRIVATE_KEY as string],
    },
    mainnet: {
      url: "https://bsc-dataseed1.ninicoin.io",
      chainId: 56,
      accounts: [process.env.PRIVATE_KEY as string],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.EHTERSCAN_API_KEY as string,
      mainnet: process.env.EHTERSCAN_API_KEY as string,
    },
    customChains: [
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io"
        }
      }
    ]
  },
  sourcify: {
    enabled: true
  }
};

export default config;
