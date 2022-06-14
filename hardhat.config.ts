import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import 'hardhat-deploy';
import "hardhat-gas-reporter";
import "solidity-coverage";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const alchemyUrl = process.env.ALCHEMY_URL;
const infuraApiKey = process.env.INFURA_API_KEY;
const mnemonic = process.env.HDWALLET_MNEMONIC;
const avalanche = process.env.AVALANCHE_ENABLED;

const config: HardhatUserConfig = {
  solidity: "0.8.4",
  networks: {
    rinkeby: {
      chainId: 4,
      url: `https://rinkeby.infura.io/v3/${infuraApiKey}`,
      gas: 13450000,
      blockGasLimit: 13450000,
      accounts: {
        mnemonic,
      },
    },
    mumbai: {
        chainId: 80001,
        url: 'https://rpc-mumbai.maticvigil.com',
        accounts: {
            mnemonic,
        },
    },
    fuji: {
        chainId: 43113,
        url: 'https://api.avax-test.network/ext/bc/C/rpc',
        accounts: {
            mnemonic,
        },
    }
  },
  namedAccounts: {
    deployer: {
      default: 0,
      rinkeby: '0x5DC27a3BB1501eA928137b10558DC8B42feA04f1',
      mumbai: '0x5DC27a3BB1501eA928137b10558DC8B42feA04f1',
      fuji: '0x5DC27a3BB1501eA928137b10558DC8B42feA04f1', 
    },
    defenderRelayer: {
      default: 0,
      rinkeby: '0xc40a27ea8facfbf2be191734a0e9fe90011d1c6e', // Ethereum (Rinkeby) Defender Relayer
      mumbai: '0x7a7aef651c161412ca89d45d9aa038a2f625d30f', // Polygon (Mumbai) Defender Relayer
      fuji: '0x2e5901a29eebc67f7ebdc6e48921a306389ff21e', // Avalanche (Fuji) Defender Relayer
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
