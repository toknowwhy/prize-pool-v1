import { dim } from 'chalk';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { deployAndLog } from '../scripts/deployAndLog';
import { setTicket } from '../scripts/setTicket';

export default async function deployToRinkeby(hardhat: HardhatRuntimeEnvironment) {

  const { getNamedAccounts, ethers } = hardhat;
  const { deployer, defenderRelayer } = await getNamedAccounts();

  // New Draw Every 13 days
  const calculatedBeaconPeriodSeconds = 86400 * 13;
  const tokenDecimals = 18;

  dim(`Deploying on Fuji...`);

  const prizePoolResult = await deployAndLog('PrizePool', {
    from: deployer,
    args: [
      defenderRelayer,
      1,
      'fantom',
      1654905600,
      calculatedBeaconPeriodSeconds,
    ],
    skipIfAlreadyDeployed: true,
  });

  const yesTicketResult = await deployAndLog('YesTicket', {
    from: deployer,
    contract: "Ticket",
    args: ['yesUnitV1', 'yUNIT', tokenDecimals, prizePoolResult.address],
    skipIfAlreadyDeployed: true,
  });

  const noTicketResult = await deployAndLog('NoTicket', {
    from: deployer,
    contract: "Ticket",
    args: ['noUnitV1', 'nUNIT', tokenDecimals, prizePoolResult.address],
    skipIfAlreadyDeployed: false,
  });

  await setTicket(yesTicketResult.address, noTicketResult.address);
}
