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

const bscx = '0x5Ac52EE5b2a633895292Ff6d8A89bB9190451587'
const stakeLPLv1 = 100
const stakeLPLv2 = 300
const percentForReferLv1 = 5
const percentForReferLv2 = 3

export async function nieuTSFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<NieuTSFixture> {
  const nieuTS = await deployContract(wallet, BSCXNTS, [wallet.address, stakeLPLv1, stakeLPLv2, percentForReferLv1, percentForReferLv2], overrides)

  return { nieuTS }
}
