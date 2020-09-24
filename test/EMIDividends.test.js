/* eslint-disable */

// eslint-disable-next-line import/order
const web3 = require('web3');

const { BN } = web3.utils;

const { accounts, defaultSender } = require('@openzeppelin/test-environment');
const { ether } = require('@openzeppelin/test-helpers');
const { contract } = require('./twrapper');
const { assert } = require('chai');
const BigNumber = require('bignumber.js')

const Decimals = new BN(10).pow(new BN(18));

const money = {
  ether,
  eth: ether,
  zero: ether('0'),
  oneWei: ether('0').addn(1),
  weth: ether,
  dai: ether,
  usdc: (value) => ether(value).divn(1e12),
};

// const EmiDAOToken = artifacts.require('EmiDAOToken');
// const EmiVault = artifacts.require('EmiVault');
// const EmiDividendToken = artifacts.require('EmiDividendToken');

const ESD = contract.fromArtifact('ESD');
const ESW = contract.fromArtifact('ESW');
const EmiVault = contract.fromArtifact('EmiVault');
const MooniFactory = contract.fromArtifact('MooniFactory');
const Mooniswap = contract.fromArtifact('Mooniswap');
const MockUSDX = contract.fromArtifact('MockUSDX');
const MockUSDY = contract.fromArtifact('MockUSDY');
const MockUSDZ = contract.fromArtifact('MockUSDZ');

let /* emiDAO */esw;
let emiVault;
let mooniswapFactory;
let usdx;
let esd;
let DecimalsESD;
let DecimalsUSDX;
let DecimalsETHY;
let DecimalsBTCZ;

// part 1 rework
// temporary skip
describe('EMI', function () {
  const [factoryOwner, alice, bob] = accounts;
  beforeEach(async function () {
    esw = await ESW.new();
    emiVault = await EmiVault.new();
    mooniswapFactory = await MooniFactory.new(factoryOwner);
    usdx = await MockUSDX.new();
    ethy = await MockUSDY.new();
    btcz = await MockUSDZ.new();
    esd = await ESD.new();
    DecimalsESD  = new BN(10).pow(new BN(18));
    DecimalsUSDX = new BN(10).pow(new BN(await usdx.decimals()));
    DecimalsETHY = new BN(10).pow(new BN(await ethy.decimals()));
    DecimalsBTCZ = new BN(10).pow(new BN(await btcz.decimals()));

    // XY pair usdx - ethy, 400 : 1
    await mooniswapFactory.deploy(usdx.address, ethy.address);
    await mooniswapFactory.deploy(usdx.address, btcz.address);
    await mooniswapFactory.deploy(ethy.address, btcz.address);

    const pairXYAddressMooni = await Mooniswap.at(await mooniswapFactory.pools(usdx.address, ethy.address));
    const pairXZAddressMooni = await Mooniswap.at(await mooniswapFactory.pools(usdx.address, btcz.address));
    const pairYZAddressMooni = await Mooniswap.at(await mooniswapFactory.pools(ethy.address, btcz.address));
        
    let USDX8000 = new BN(8000).mul(DecimalsUSDX).toString();
    let ETHY20 = new BN(20).mul(DecimalsETHY).toString();
    await usdx.approve(pairXYAddressMooni.address, USDX8000, { from: defaultSender });
    await usdx.approve(pairXYAddressMooni.address, USDX8000, { from: defaultSender });
    await ethy.approve(pairXYAddressMooni.address, ETHY20, { from: defaultSender });
    await ethy.approve(pairXYAddressMooni.address, ETHY20, { from: defaultSender });
    
    console.log("usdx.balanceOf(defaultSender)", new BN(await usdx.balanceOf(defaultSender)).toString())
    console.log("ethy.balanceOf(defaultSender)", new BN(await ethy.balanceOf(defaultSender)).toString())
    console.log("USDX8000", USDX8000, "ETHY20", ETHY20)
    await pairXYAddressMooni.deposit((usdx.address > ethy.address ? [ETHY20, USDX8000] : [USDX8000, ETHY20]), [money.zero, money.zero], { from: defaultSender });
    
    // XZ pair usdx - btcz, 9000 : 1
    let USDX9000 = new BN(9000).mul(DecimalsUSDX).toString();
    let BTCZ1 = new BN(1).mul(DecimalsBTCZ).toString();
    await usdx.approve(pairXZAddressMooni.address, USDX9000, { from: defaultSender });
    await btcz.approve(pairXZAddressMooni.address, BTCZ1, { from: defaultSender });
    /* await usdx.transfer(pairXZAddressMooni.address, USDX9000);
    await btcz.transfer(pairXZAddressMooni.address, BTCZ1); */    
    await pairXZAddressMooni.deposit((usdx.address > btcz.address ? [BTCZ1, USDX9000] : [USDX9000, BTCZ1]), [money.zero, money.zero], { from: defaultSender });

    // YZ pair ethy - btcz, 22 : 1
    let ETHY22 = new BN(22).mul(DecimalsETHY).toString();    
    await ethy.approve(pairYZAddressMooni.address, ETHY22, { from: defaultSender });
    await btcz.approve(pairYZAddressMooni.address, BTCZ1, { from: defaultSender });
    await pairYZAddressMooni.deposit((ethy.address < btcz.address ? [ETHY22, BTCZ1] : [BTCZ1, ETHY22]), [money.zero, money.zero], { from: defaultSender });
    
    await esw.initialize();
    await esd.initialize(esw.address/*daoToken*/, emiVault.address/*vault*/, usdx.address /*basicToken*/, mooniswapFactory.address /*swapFactory*/);
    await emiVault.setDividendToken(esd.address);

    // Mint 1000000 ESW tokens to factoryOwner wallet
    await esw.setMintLimit(defaultSender, 1000000000, { from: defaultSender })
    let txMintData = await esw.mint(alice,    99999000, { from: defaultSender }) 
    //console.log('txMintData =', txMintData) transaction details (gas)
    await esw.mint(factoryOwner, 1000, { from: defaultSender }) 
    console.log('Mint 10,000 ESW to factoryOwner')

    // Mint 1000 USDX tokens to factoryOwner wallet
    let restxUSDX = await usdx.transfer(factoryOwner, 1000, { from: defaultSender }) 
    //console.log('Sent 1,000 USDX to factoryOwner. Transfer TX=', restxUSDX) // 51151 gas
  })

  it.skip('should put 1,000,000 ESW in the first account', async function () {
    const balance = await esw.balanceOf.call( factoryOwner )
    assert.equal(balance.toString(), new BN(1000000).toString(), "ESW balance " + balance.toNumber() + " not equal 1000000 MetaCoin")
  });

  it('should put 1,000 USDX in the first account', async function () {
    const balance = await usdx.balanceOf.call( factoryOwner )
    assert.equal(balance.toString(), new BN(1000).toString(), "USDX balance " + balance.toNumber() + " not equal 1000 USDX")
  });
  it('should send coin correctly', async function () {
    // rework

    // Need to add all tokens operating in ESD to "portfolio" list
    await esd.setPortfolioTokenStatus(usdx.address, 1)
    await esd.setPortfolioTokenStatus(ethy.address, 1)
    await esd.setPortfolioTokenStatus(btcz.address, 1)
    
    // send 1 ETHY to emiVault address
    await usdx.approve(emiVault.address, new BN(1).mul(DecimalsUSDX).toString(), {from: defaultSender})
    await usdx.transfer(emiVault.address, new BN(1).mul(DecimalsUSDX).toString(), {from: defaultSender})
    await btcz.approve(emiVault.address, new BN(1).mul(DecimalsBTCZ).toString(), {from: defaultSender})
    await btcz.transfer(emiVault.address, new BN(1).mul(DecimalsBTCZ).toString(), {from: defaultSender})


    await ethy.approve(emiVault.address, new BN(1).mul(DecimalsETHY).toString(), {from: defaultSender})
    await ethy.transfer(emiVault.address, new BN(1).mul(DecimalsETHY).toString(), {from: defaultSender})
    let emiVaultETHYbalance = (await ethy.balanceOf(emiVault.address)).div(DecimalsETHY).toString()
    let emiVaultETHYbalance_nature = (await ethy.balanceOf(emiVault.address)).toString()
    assert.equal(emiVaultETHYbalance, '1', "must be 1 ETHY at emiVault ETHY balance")
            
    // call emiVault.deposit for 1 ETHY
    await emiVault.deposit(ethy.address, new BN(1).mul(DecimalsETHY));
    console.log('emiVault.deposit 1 , emiVault balance of ethy was =', emiVaultETHYbalance, ' after deposit tokens go to esd')

    console.log('emiVaultETHYbalance_nature=', emiVaultETHYbalance_nature)
    let basicCoinAmount = await esd._getBasicAssetAmount(ethy.address, emiVaultETHYbalance_nature);
    console.log('basicCoinAmount=', new BigNumber(basicCoinAmount).toString())
    
    const available = await esd.balanceOf.call( factoryOwner );
    console.log('factoryOwner available dividends',  new BigNumber(available)/* .div(new BigNumber(10**18)) */.toString(), 'ESD')
    let ESWfactoryOwner = new BigNumber(await esw.balanceOf(factoryOwner)).toNumber()
    let ESWTotalSupply = new BigNumber(await esw.totalSupply()).toNumber()
    let resESWTransfer = await esw.transfer(bob, 1, {from: alice})
    //console.log('resESWTransfer=', resESWTransfer) // 130764 gas

    console.log('factoryOwner owe', ESWfactoryOwner, 'ESW of total ESW')
    console.log('ESW.totalSupply=', ESWTotalSupply, 'ESW | owe', new BigNumber(available).toNumber(), 'ESD and ')
    console.log('_totalDividends =', new BigNumber(await esd._totalDividends()).toNumber())

    let _amount = await esd._getAvailable( factoryOwner );
    console.log('_amount         =', new BigNumber(_amount).toNumber())
    let dividendRecords = await esd.dividendRecords( factoryOwner );
    console.log('dividendRecords =', new BigNumber(dividendRecords.rate).toNumber(), new BigNumber(dividendRecords.available).toNumber())
    let _rate = await esd._rate();
    console.log('_rate           =', new BigNumber(_rate).toNumber())
    let rateFUNC = await esd.rate(ESWfactoryOwner, new BigNumber(dividendRecords.available).toNumber())
    console.log('rateFUNC        =', new BigNumber(rateFUNC).toNumber())

    //console.log(await esd.withdraw( factoryOwner ), '-')
    console.log('ESD owns', new BigNumber(await ethy.balanceOf(esd.address)).div(DecimalsETHY).toNumber(), 'ETHY')
    console.log('ESD owns', new BigNumber(await usdx.balanceOf(esd.address)).div(DecimalsUSDX).toNumber(), 'USDX')
    console.log('ESD owns', new BigNumber(await btcz.balanceOf(esd.address)).div(DecimalsBTCZ).toNumber(), 'BTCZ')
    await esd.withdraw( factoryOwner, {from: factoryOwner} )

    let ethyNewBalance = new BigNumber(await ethy.balanceOf(factoryOwner)).div(DecimalsETHY).toNumber()    

    console.log('Successfully received witdrawn', /* await ethy.balanceOf(factoryOwner) */ethyNewBalance, 'ETHY')

    console.log('ESD owns', new BigNumber(await ethy.balanceOf(esd.address)).div(DecimalsETHY).toNumber(), 'ETHY')
    console.log('ESD owns', new BigNumber(await usdx.balanceOf(esd.address)).div(DecimalsUSDX).toNumber(), 'USDX')
    console.log('ESD owns', new BigNumber(await btcz.balanceOf(esd.address)).div(DecimalsBTCZ).toNumber(), 'BTCZ')

    // ==========================================================================================================================================
    
  });
});