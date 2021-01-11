import { Contract, Wallet } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import BSCXNTS from '../../build/BSCXNTS.json'

const overrides = {
  gasLimit: 9999999
}

interface NieuTSFixture {
  nieuTS: Contract
}

export async function nieuTSFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<NieuTSFixture> {
  const nieuTS = await deployContract(wallet, BSCXNTS, [wallet.address], overrides)

  return { nieuTS }
}
