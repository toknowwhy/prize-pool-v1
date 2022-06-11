import { cyan, green } from './colors'
import hre from 'hardhat'
import { Contract } from 'ethers'

export async function setTicket(yesTicketAddress: string, noTicketAddress: string, contract?: Contract) {
    if (!contract) {
        // @ts-ignore
        contract = await hre.ethers.getContract('PrizePool')
    }
    if (await contract.getTicket(true) != yesTicketAddress) {
        cyan('\nSetting tickets on prize pool...')
        const tx = await contract.setTicket(yesTicketAddress, noTicketAddress);
        await tx.wait(1)
        green(`Set ticket!`)
    }
}
