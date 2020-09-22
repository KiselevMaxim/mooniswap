// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IERC20Detailed.sol";
import "./interfaces/IEmiReferral.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";

contract CrowdSale {
  using SafeMath for uint256;
  using SafeMath for uint32;
  using SafeERC20 for IERC20;

  event Buy(address account, uint256 amount, uint32 coinId, uint256 coinAmount);
  event Sell(
    address account,
    uint256 amount,
    uint32 coinId,
    uint256 coinAmount
  );

  struct Coin {
    address token;
    string name;
    string symbol;
    uint8 decimals;
    uint32 rate;
    uint8 status;
  }

  uint32 internal _ratePrecision = 10000;

  mapping(uint16 => Coin) internal _coins;
  mapping(address => uint16) public coinIndex;
  uint16 internal _coinCounter = 1;
  address internal _token;
  address internal _uniswapFactory;
  address payable internal _owner;
  address public referralStore;

  modifier onlyOwner() {
    require(_owner == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  constructor(address token, address uniswapFactory, address referralStoreInput) public {
    _owner = msg.sender;
    _token = token;
    _uniswapFactory = uniswapFactory;
    referralStore = referralStoreInput;
  }

  function coinCounter() public view returns (uint16) {
    return _coinCounter;
  }

  function coin(uint16 index)
    public
    view
    returns (
      string memory name,
      string memory symbol,
      uint8 decimals
    )
  {
    return (_coins[index].name, _coins[index].symbol, _coins[index].decimals);
  }

  function coinRate(uint16 index) public view returns (uint32 rate) {
    return (_coins[index].rate);
  }

  function coinGetRate(uint16 index) public view returns (uint32) {
    return _coins[index].rate;
  }

  function coinGetStatus(uint16 index) public view returns (uint8) {
    return _coins[index].status;
  }

  function coinData(uint16 index)
    public
    view
    returns (address coinAddress, uint8 status)
  {
    return (_coins[index].token, _coins[index].status);
  }

  function _normalizeCoinAmount(uint256 amount, uint8 coinDecimals)
    internal
    pure
    returns (uint256)
  {
    if (coinDecimals > 18) {
      return amount.div(uint256(10)**(coinDecimals - 18));
    }
    return amount.mul(uint256(10)**(18 - coinDecimals));
  }

  function _normalizeTokenAmount(uint256 amount, uint8 coinDecimals)
    internal
    pure
    returns (uint256)
  {
    if (coinDecimals >= 18) {
      return amount.mul(uint256(10)**(coinDecimals - 18));
    }
    return amount.div(uint256(10)**(18 - coinDecimals));
  }

  function getSellTokenAmountByID(uint16 coinId, uint256 amount)
    public
    view
    returns (uint256)
  {
    return
      _normalizeTokenAmount(
        amount.div(_coins[coinId].rate).mul(_ratePrecision),
        _coins[coinId].decimals
      );
  }

  function getBuyTokenAmountByID(uint16 coinId, uint256 amount)
    public
    view
    returns (uint256)
  {
    return
      _normalizeTokenAmount(
        amount.div(_coins[coinId].rate).mul(_ratePrecision),
        _coins[coinId].decimals
      );
  }

  function getSellCoinAmountByID(uint16 coinId, uint256 amount)
    public
    view
    returns (uint256)
  {
    return
      _normalizeCoinAmount(
        amount.mul(_coins[coinId].rate).div(_ratePrecision),
        _coins[coinId].decimals
      );
  }

  function getBuyCoinAmountByID(uint16 coinId, uint256 amount)
    public
    view
    returns (uint256)
  {
    return
      _normalizeCoinAmount(
        amount.mul(_coins[coinId].rate).div(_ratePrecision),
        _coins[coinId].decimals
      );
  }

  function getBuyTokenAmount(address coinAddress, uint256 amount)
    public
    view
    returns (uint256)
  {
    return getBuyTokenAmountByID(coinIndex[coinAddress], amount);
  }

  function getSellTokenAmount(address coinAddress, uint256 amount)
    public
    view
    returns (uint256)
  {
    return getSellTokenAmountByID(coinIndex[coinAddress], amount);
  }

  function getBuyCoinAmount(address coinAddress, uint256 amount)
    public
    view
    returns (uint256)
  {
    return getBuyCoinAmountByID(coinIndex[coinAddress], amount);
  }

  function getSellCoinAmount(address coinAddress, uint256 amount)
    public
    view
    returns (uint256)
  {
    return getSellCoinAmountByID(coinIndex[coinAddress], amount);
  }

  function fetchCoin(address coinAddress) public onlyOwner returns (bool) {
    require(coinIndex[coinAddress] == 0, "Already loaded");
    string memory _name = IERC20Detailed(coinAddress).name();
    string memory _symbol = IERC20Detailed(coinAddress).symbol();
    uint8 _decimals = IERC20Detailed(coinAddress).decimals();

    _coins[_coinCounter] = Coin(
      coinAddress,
      _name,
      _symbol,
      _decimals,
      1 * _ratePrecision,
      1
    );
    coinIndex[coinAddress] = _coinCounter;
    _coinCounter += 1;
  }

  function setStatusByID(uint16 coinId, uint8 status)
    public
    onlyOwner
    returns (bool)
  {
    _coins[coinId].status = status;
    return true;
  }

  function setRateByID(uint16 coinId, uint32 rate)
    public
    onlyOwner
    returns (bool)
  {
    _coins[coinId].rate = rate;
    return true;
  }

  function buy(address coinAddress, uint256 amount, address referralInput) public returns (bool) {
    uint16 coinId = coinIndex[coinAddress];
    require(_coins[coinId].status != 0, "Coin in not active");
    uint256 coinAmount = amount;
    if (amount == 0) {
      coinAmount = IERC20(_coins[coinId].token).allowance(
        msg.sender,
        address(this)
      );
    }
    require(coinAmount > 0, "No funds avaialble");
    uint256 currentTokenAmount = 0;
    if (_coins[coinId].status == 1) {
      currentTokenAmount = getBuyCoinAmountByID(coinId, coinAmount);
    } else {
      // get pair pool
      /* address pairContract = MooniFactory(_uniswapFactory).pools[_coins[_coins[coinId].status].token][_coins[2].token]; */
      address pairContract = IUniswapV2Factory(_uniswapFactory).getPair(
        _coins[_coins[coinId].status].token,
        _coins[2].token
      );
      require(pairContract != address(0), "Pair not found");
      // get pool reserves
      /* uint112 reserve0 = Mooniswap(pairContract).getBalanceForAddition(_coins[1].token);
      uint112 reserve1 = Mooniswap(pairContract).getBalanceForRemoval(_coins[2].token);
      coinAmount = _getAmountOut(amount, reserve0, reserve1); */
      (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairContract)
        .getReserves();
      if (IUniswapV2Pair(pairContract).token0() == _coins[1].token) {
        coinAmount = _getAmountOut(amount, reserve0, reserve1);
      } else {
        coinAmount = _getAmountOut(amount, reserve1, reserve0);
      }
      currentTokenAmount = getBuyCoinAmountByID(
        _coins[coinId].status,
        coinAmount
      );
    }

    IERC20(_coins[coinId].token).safeTransferFrom(msg.sender, _owner, amount);
    IERC20Detailed(_token).mint(msg.sender, currentTokenAmount);
    IERC20Detailed(_token).mint(_owner, currentTokenAmount);

    // if passed refferal and have no referral, set it
    address[] memory referrals = IEmiReferral(referralStore).getReferralChain(msg.sender);
    if ((referrals.length == 0) && (address(referralInput) != address(0x0))) {
      IEmiReferral(referralStore).addReferral(msg.sender, referralInput);
    }

    // Get referrals
    referrals = IEmiReferral(referralStore).getReferralChain(msg.sender);
    uint256 _l1ReferralShare = IEmiReferral(referralStore).l1ReferralShare();
    uint256 _l2ReferralShare = IEmiReferral(referralStore).l2ReferralShare();
    uint256 _l3ReferralShare = IEmiReferral(referralStore).l3ReferralShare(); // TODO: make one request to get all ref data
    
    if (referrals.length > 0) {
      if (referrals.length == 3) {
        //token1.transfer(referrals[2], _amount * L3_REFERRAL_SHARE / 100 ether);
        IERC20Detailed(_token).mint(referrals[2], currentTokenAmount * _l3ReferralShare / 1000);
      }

      if (referrals.length >= 2) {
        //token1.transfer(referrals[1], _amount * L2_REFERRAL_SHARE / 100 ether);
        IERC20Detailed(_token).mint(referrals[1], currentTokenAmount * _l2ReferralShare / 1000);
      }

      //token1.transfer(referrals[0], _amount * L1_REFERRAL_SHARE / 100 ether);
      IERC20Detailed(_token).mint(referrals[0], currentTokenAmount * _l1ReferralShare / 1000);
    }

    emit Buy(msg.sender, currentTokenAmount, coinId, coinAmount);
    return true;
  }

  function _getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) internal pure returns (uint256 amountOut) {
    require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
    require(
      reserveIn > 0 && reserveOut > 0,
      "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
    );
    amountOut = amountIn.mul(reserveOut).div(reserveIn);
  }

  function buyWithETH(address referralInput) public payable {
    address pairContract = IUniswapV2Factory(_uniswapFactory).getPair(
      _coins[2].token,
      _coins[1].token
    );
    require(pairContract != address(0), "Pair not found");
    (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairContract)
      .getReserves();
    _owner.transfer(msg.value);
    uint256 coinAmount = 0;
    if (IUniswapV2Pair(pairContract).token0() == _coins[2].token) {
      coinAmount = _getAmountOut(msg.value, reserve0, reserve1);
    } else {
      coinAmount = _getAmountOut(msg.value, reserve1, reserve0);
    }
    uint256 currentTokenAmount = getBuyCoinAmountByID(1, coinAmount);

    // Get referrals    
    address[] memory referrals = IEmiReferral(referralStore).getReferralChain(msg.sender);
    
    // if passed refferal and have no referral, set it
    if ( (referrals.length == 0) && (address(referralInput) != address(0x0)) ) {
      IEmiReferral(referralStore).addReferral(msg.sender, referralInput);
    }

    referrals = IEmiReferral(referralStore).getReferralChain(msg.sender);    
    uint256 _l1ReferralShare = IEmiReferral(referralStore).l1ReferralShare();
    uint256 _l2ReferralShare = IEmiReferral(referralStore).l2ReferralShare();
    uint256 _l3ReferralShare = IEmiReferral(referralStore).l3ReferralShare(); // TODO: make one request to get all ref data
    if (referrals.length > 0) {
      if (referrals.length == 3) {
        //token1.transfer(referrals[2], _amount * L3_REFERRAL_SHARE / 100 ether);
        IERC20Detailed(_token).mint(referrals[2], currentTokenAmount * _l3ReferralShare / 1000);
      }

      if (referrals.length >= 2) {
        //token1.transfer(referrals[1], _amount * L2_REFERRAL_SHARE / 100 ether);
        IERC20Detailed(_token).mint(referrals[1], currentTokenAmount * _l2ReferralShare / 1000);
      }

      //token1.transfer(referrals[0], _amount * L1_REFERRAL_SHARE / 100 ether);
      IERC20Detailed(_token).mint(referrals[0], currentTokenAmount * _l1ReferralShare / 1000);
    }

    IERC20Detailed(_token).mint(msg.sender, currentTokenAmount);
    IERC20Detailed(_token).mint(_owner, currentTokenAmount);    
    emit Buy(msg.sender, currentTokenAmount, 1, coinAmount);
  }

  receive() external payable { // receive not supported paramters, so call buyWithETH with 0x0 address
    buyWithETH(address(0));
  }

  function getToken() external view returns (address) {
    return _token;
  }
}
