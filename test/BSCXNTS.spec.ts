import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { MaxUint256 } from 'ethers/constants'
import { bigNumberify, BigNumber, hexlify, keccak256, defaultAbiCoder, toUtf8Bytes } from 'ethers/utils'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'
import { ecsign } from 'ethereumjs-util'

import { expandTo18Decimals, getApprovalDigest } from './shared/utilities'
import { nieuTSFixture } from './shared/fixtures'

chai.use(solidity)

const POOL1 = [
    '0xaC6A00ec0224cC582AFC6c9119fc80D4466238d3',
    '0x7d7f7BbC88239CC2463797632Faf94aa1088C7D2',
    5295000,
    80,
    1,
    75,
    10,
    20,
    1200,
    [10, 8, 6, 4, 2, 1],
    6295000,
    7295000
  ]

  const POOL2 = [
    '0xaC6A00ec0224cC582AFC6c9119fc80D4466238d3',
    '0x4a17EA9AEce6bac01ABB1396AB7473be78BEf38A',
    5296000,
    20,
    1,
    75,
    10,
    20,
    1200,
    [10, 8, 6, 4, 2, 1],
    6295000,
    7295000
  ]

  const POOL3 = [
    '0x8390ba50006860538936c96c1f283019fbe72bfd',
    '0x4a17EA9AEce6bac01ABB1396AB7473be78BEf38A',
    5296000,
    20,
    1,
    75,
    10,
    20,
    1200,
    [10, 8, 6, 4, 2, 1],
    6295000,
    7295000
  ]

describe('BSCXNTS', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader(provider, [wallet])

  let nieuTS: Contract
  beforeEach(async () => {
    const fixture = await loadFixture(nieuTSFixture)
    nieuTS = fixture.nieuTS
  })

  it('devaddr', async () => {
    expect(await nieuTS.devaddr()).to.eq(wallet.address)
  })

  const devaddr = '0xF6e888033ddc6b1C609fBc4130cB3e8B49964648'
  it('only current devaddr can set devaddr', async () => {
    await nieuTS.dev(devaddr)
    expect(await nieuTS.devaddr()).to.eq(devaddr)
  })

  async function addPool(pool: any) {
    await nieuTS.add(...pool)
  }

  it('add pool', async () => {
    await addPool(POOL1)

    expect(await nieuTS.poolLength()).to.eq(1)
    const poolInfo = await nieuTS.poolInfo(0)

    expect(poolInfo[0]).to.eq(POOL1[0])
    expect(poolInfo[1]).to.eq(POOL1[1])
  })

  it('add pool same lp token address', async () => {
    await addPool(POOL1)
    await expect(addPool(POOL2)).to.be.revertedWith('BSCXNTS::add: lp is already in pool')
  })

  it('total alloc point 1 pool', async () => {
    await addPool(POOL1)
    let totalAllocPoint = await nieuTS.totalAllocPoints(POOL1[1])
    totalAllocPoint = totalAllocPoint.toNumber()
    await expect(totalAllocPoint).to.eq(POOL1[3])
  })

  it('total alloc point 2 pool save token reward', async () => {
    await addPool(POOL1)
    await addPool(POOL3)
    let totalAllocPointPOOL1 = await nieuTS.totalAllocPoints(POOL1[1])
    let totalAllocPointPOOL2 = await nieuTS.totalAllocPoints(POOL3[1])
    totalAllocPointPOOL1 = totalAllocPointPOOL1.toNumber()
    totalAllocPointPOOL2 = totalAllocPointPOOL2.toNumber()
    await expect(totalAllocPointPOOL1 + totalAllocPointPOOL2).to.eq(100)
  })
})
