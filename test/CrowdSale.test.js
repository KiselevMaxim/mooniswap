// eslint-disable-next-line no-unused-vars
const { accounts, defaultSender } = require('@openzeppelin/test-environment');
const { assert } = require('chai');
const { contract } = require('./twrapper');
const { toNumber } = require('lodash');

const Referral = contract.fromArtifact('EmiReferral');
const UniswapV2Factory = contract.fromArtifact('UniswapV2Factory');
const UniswapV2Pair = contract.fromArtifact('UniswapV2Pair');
const ERC20 = contract.fromArtifact('ERC20PresetMinterPauser');
const MockUSDX = contract.fromArtifact('MockUSDX');
const MockUSDY = contract.fromArtifact('MockUSDY');
const MockUSDZ = contract.fromArtifact('MockUSDZ');
const ESD = contract.fromArtifact('ESD');
const ESW = contract.fromArtifact('ESW');
const EmiVault = contract.fromArtifact('EmiVault');
const CrowdSale = contract.fromArtifact('CrowdSale');

const { web3 } = ERC20;

ERC20.numberFormat = 'String';
ESW.numberFormat = 'String';
ESD.numberFormat = 'String';

// eslint-disable-next-line import/order
const { ether } = require('@galtproject/solidity-test-chest')(web3);

const { BN } = web3.utils;

let uniswapFactory;
let uniswapPair;
let usdx;
let usdy;
let usdz;

let esw;
let esd;
let vault;
let crowdSale;

describe('CrowdSale Test', function () {
  const [factoryOwner, alice, bob, clarc, dave, eve] = accounts;

  beforeEach(async function () {
    esw = await ESW.new();
    esd = await ESD.new();
    vault = await EmiVault.new();
    usdx = await MockUSDX.new();
    usdy = await MockUSDY.new();
    usdz = await MockUSDZ.new();
    ref = await Referral.new();

    uniswapFactory = await UniswapV2Factory.new(factoryOwner);

    crowdSale = await CrowdSale.new(esw.address, uniswapFactory.address, ref.address);

    await uniswapFactory.createPair(usdx.address, usdy.address);
    const pairAddress = await uniswapFactory.getPair(usdx.address, usdy.address);
    uniswapPair = await UniswapV2Pair.at(pairAddress);

    await esw.initialize();
    await esd.initialize(esw.address, vault.address, usdx.address, uniswapFactory.address);
    await esw.setMintLimit(crowdSale.address, ether(1000));
    await esw.setDividendToken(esd.address);
    await vault.setDividendToken(esd.address);

    await usdx.transfer(bob, 100000);
    await usdx.transfer(uniswapPair.address, 1000000);
    await usdy.transfer(uniswapPair.address, 100000);
    
    await uniswapPair.mint(alice);

    // Make crowdsale know about token
    await crowdSale.fetchCoin(usdx.address);
    await crowdSale.fetchCoin(usdy.address);
    await crowdSale.fetchCoin(usdz.address);
  });

  describe('Buy with ETH', () => {
    beforeEach(async function () {
      const Decimals = new BN(10).pow(new BN(await esw.decimals()))
      this.BuyWithETHTest = {WEIValue : 100000, Decimals : Decimals}
    })
    it('should mit an equal value of esw both to a buyer and owner', async function () {
      await crowdSale.sendTransaction({ from: bob, value: this.BuyWithETHTest.WEIValue })
    })
    it('should mit an equal value of esw both to a buyer and owner with 1-lv referral', async function () {
      await ref.addReferral(bob, clarc);
      await crowdSale.sendTransaction({ from: bob, value: this.BuyWithETHTest.WEIValue });
      let BuyerBalance = await esw.balanceOf(bob)
      let Ref1Balance = await esw.balanceOf(clarc)
      console.log('Clarc as 1 level referral received 5%', Ref1Balance / this.BuyWithETHTest.Decimals, 'ESW')
      assert.equal(BuyerBalance * 0.05, Ref1Balance, "1-lv referral must be 0.05% of buyer's")
    })
    it('should mit an equal value of esw both to a buyer and owner with 2-lv referral', async function () {
      await ref.addReferral(bob, clarc);
      await ref.addReferral(clarc, dave);
      await crowdSale.sendTransaction({ from: bob, value: this.BuyWithETHTest.WEIValue });
      let BuyerBalance = await esw.balanceOf(bob)
      let Ref1Balance = await esw.balanceOf(clarc)
      let Ref2Balance = await esw.balanceOf(dave)
      console.log('Clarc as 1 level referral received 5%', Ref1Balance / this.BuyWithETHTest.Decimals, 'ESW')
      assert.equal(BuyerBalance * 0.05, Ref1Balance, "1-lv referral must be 0.05% of buyer's")
      console.log('Dave  as 2 level referral received 3%', Ref2Balance / this.BuyWithETHTest.Decimals, 'ESW')
      assert.equal(BuyerBalance * 0.03, Ref2Balance, "2-lv referral must be 0.03% of buyer's")
    })
    it('should mit an equal value of esw both to a buyer and owner with 3-lv referral', async function () {
      await ref.addReferral(bob, clarc);
      await ref.addReferral(clarc, dave);
      await ref.addReferral(dave, eve);
      await crowdSale.sendTransaction({ from: bob, value: this.BuyWithETHTest.WEIValue });
      let BuyerBalance = await esw.balanceOf(bob)
      let Ref1Balance = await esw.balanceOf(clarc)
      let Ref2Balance = await esw.balanceOf(dave)
      let Ref3Balance = await esw.balanceOf(eve)
      console.log('Clarc as 1 level referral received 5%  ', Ref1Balance / this.BuyWithETHTest.Decimals, 'ESW')
      assert.equal(BuyerBalance * 0.05, Ref1Balance, "1-lv referral must be 0.05% of buyer's")
      console.log('Dave  as 2 level referral received 3%  ', Ref2Balance / this.BuyWithETHTest.Decimals, 'ESW')
      assert.equal(BuyerBalance * 0.03, Ref2Balance, "2-lv referral must be 0.03% of buyer's")
      console.log('Eve   as 3 level referral received 1.5%', Ref3Balance / this.BuyWithETHTest.Decimals, 'ESW')
      assert.equal(BuyerBalance * 0.015, Ref3Balance, "3-lv referral must be 0.015% of buyer's")
    })
    afterEach(async function () {
      const balance0 = await esw.balanceOf(defaultSender);
      const balance2 = await esw.balanceOf(bob);
  
      console.log('Bob bought ESW tokens for', web3.utils.fromWei(this.BuyWithETHTest.WEIValue.toString(), 'ether'), 'ETH and received', balance2 / this.BuyWithETHTest.Decimals, 'ESW tokens')
      assert.equal(balance0, balance2);
    })
  });

  describe('Buy with USDX', () => {
    beforeEach(async function () {
      const USDXValue = 100000;
      const USDXdec = await usdx.decimals();
      const ESWdec = await esw.decimals();
      const Decimals = new BN(10).pow(new BN(await esw.decimals()))
      await usdx.approve(crowdSale.address, USDXValue, { from: alice });
      this.BuyWithUSDXTest = {USDXValue : USDXValue, USDXdec : USDXdec, ESWdec : ESWdec, Decimals : Decimals}
    })
    it('should mit an equal value of esw both to a buyer and owner', async function () {
      await crowdSale.buy(usdx.address, 0, '0x0000000000000000000000000000000000000000', { from: alice });
    })
    it('should mit an equal value of esw both to a buyer and owner with 1-lv referral', async function () {

      //await ref.addReferral(alice, clarc);
      await crowdSale.buy(usdx.address, 0, clarc, { from: alice });
      
      let BuyerBalance = await esw.balanceOf(alice)
      let Ref1Balance = await esw.balanceOf(clarc)
      console.log('Clarc as 1 level referral received 5%', (Ref1Balance / this.BuyWithUSDXTest.Decimals).toString(), 'ESW')
      assert.equal(BuyerBalance * 0.05, Ref1Balance, "1-lv referral must be 0.05% of buyer's")

    })
    it('should mit an equal value of esw both to a buyer and owner with 2-lv referral', async function () {
      
      //await ref.addReferral(alice, clarc);
      await ref.addReferral(clarc, dave);
      await crowdSale.buy(usdx.address, 0, clarc, { from: alice });
      
      let BuyerBalance = await esw.balanceOf(alice)
      let Ref1Balance = await esw.balanceOf(clarc)
      let Ref2Balance = await esw.balanceOf(dave)

      console.log('Clarc as 1 level referral received 5%', (Ref1Balance / this.BuyWithUSDXTest.Decimals).toString(), 'ESW')
      assert.equal(BuyerBalance * 0.05, Ref1Balance, "1-lv referral must be 0.05% of buyer's")
      console.log('Dave  as 2 level referral received 3%', (Ref2Balance / this.BuyWithUSDXTest.Decimals).toString(), 'ESW')
      assert.equal(BuyerBalance * 0.03, Ref2Balance, "2-lv referral must be 0.03% of buyer's")

    })
    it('should mit an equal value of esw both to a buyer and owner with 3-lv referral', async function () {
      
      //await ref.addReferral(alice, clarc);
      await ref.addReferral(clarc, dave);
      await ref.addReferral(dave, eve);
      await crowdSale.buy(usdx.address, 0, clarc, { from: alice });
      
      let BuyerBalance = await esw.balanceOf(alice)
      let Ref1Balance = await esw.balanceOf(clarc)
      let Ref2Balance = await esw.balanceOf(dave)
      let Ref3Balance = await esw.balanceOf(eve)      

      console.log('Clarc as 1 level referral received   5%', (Ref1Balance / this.BuyWithUSDXTest.Decimals).toString(), 'ESW')
      assert.equal(BuyerBalance * 0.05, Ref1Balance, "1-lv referral must be 0.05% of buyer's")
      console.log('Dave  as 2 level referral received   3%', (Ref2Balance / this.BuyWithUSDXTest.Decimals).toString(), 'ESW')
      assert.equal(BuyerBalance * 0.03, Ref2Balance, "2-lv referral must be 0.03% of buyer's")
      console.log('Eve   as 3 level referral received 1.5%', (Ref3Balance / this.BuyWithUSDXTest.Decimals).toString(), 'ESW')
      assert.equal(BuyerBalance * 0.015, Ref3Balance, "3-lv referral must be 0.015% of buyer's")

    })
    afterEach(async function () {

      const balance0 = await esw.balanceOf(defaultSender);
      const balance2 = await esw.balanceOf(alice);
  
      console.log('Alice bought ESW tokens for', this.BuyWithUSDXTest.USDXValue / 10**this.BuyWithUSDXTest.USDXdec, 
        'USDX and received', balance2 / 10**this.BuyWithUSDXTest.ESWdec, 'ESW tokens')
  
      assert.equal(balance0, balance2);
    })
  });
});
