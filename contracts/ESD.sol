// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IEmiVault.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IESD.sol";

contract ESD is IESD {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct DividendEntry {
    uint256 rate;
    uint256 available;
    uint256 withdrawn;
  }

  mapping(address => uint8) internal _portfolioTokenStatus;
  address[] public portfolioTokensList;

  // temporary changed ==================================================
  // uint256 internal _totalDividends;
  uint256 public _totalDividends;
  // ================================================== temporary changed
  address internal _daoToken;
  address internal _vault;

  address internal _basicToken;
  address internal _swapFactory;
  address internal _owner;

  // temporary changed ==================================================
  // uint256 internal _rate;
  uint256 public _rate;
  // ================================================== temporary changed

  uint8 internal _initialized;

  mapping(address => DividendEntry) public dividendRecords;

  modifier onlyVault() {
    require(_vault == msg.sender, "Ownable: caller is not vault");
    _;
  }
  modifier onlyOwner() {
    require(_owner == msg.sender, "Ownable: caller is not vault");
    _;
  }

  function portfolioTokenStatus(address token)
    public
    override
    view
    returns (uint8)
  {
    return _portfolioTokenStatus[token];
  }

  function setPortfolioTokenStatus(address token, uint8 state)
    public
    returns (bool)
  {
    if (_portfolioTokenStatus[token] == 0) {
      portfolioTokensList.push(token);
      _portfolioTokenStatus[token] = state;
      return true;
    }
    require(state != 0, "Cannot reset state");
    _portfolioTokenStatus[token] = state;
    return true;
  }

  function initialize(
    address daoToken,
    address vault,
    address basicToken,
    address swapFactory
  ) public {
    require(_initialized == 0, "Already initialized");
    _basicToken = basicToken;
    _daoToken = daoToken;
    _vault = vault;
    _swapFactory = swapFactory;
    _owner = msg.sender;
    IEmiVault(_vault).setDividendToken(address(this));
    IEmiVault(_daoToken).setDividendToken(address(this));
    _initialized = 1;
  }

  function setVault(address vault) public onlyOwner {
    _vault = vault;
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

  function _getBasicAssetAmount(address token, uint256 amount)
    // temporary comment it ==============================
    //private
    // ============================== temporary comment it
    public
    view
    returns (uint256)
  {
    address pairContract = IUniswapV2Factory(_swapFactory).getPair(
      _basicToken,
      token
    );
    require(pairContract != address(0), "Pair not found");
    (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairContract)
      .getReserves();
    uint256 coinAmount = 0;
    if (IUniswapV2Pair(pairContract).token0() == token) {
      coinAmount = _getAmountOut(amount, reserve0, reserve1);
    } else {
      coinAmount = _getAmountOut(amount, reserve1, reserve0);
    }
    return coinAmount;
  }

  function totalDividends() public view returns (uint256) {
    return IEmiVault(_vault).totalValue();
  }

  // NOTICE: called from EmiVault.deposit()
  // WARNING: added `amount` field to make compatible with IESW interface, the field is unused now
  // solhint-disable-next-line no-unused-vars
  function addDividends(address asset, uint256 amount)
    public
    override
    // temporary comment it ==============================
    //onlyVault
    // ===================================================
    returns (bool)
  {
    require(_portfolioTokenStatus[asset] == 1, "Not in portfolio");
    uint256 vaultBalance = IERC20(asset).balanceOf(_vault);
    IERC20(asset).transferFrom(_vault, address(this), vaultBalance);

    uint256 basicCoinAmount = _getBasicAssetAmount(asset, vaultBalance);
    _totalDividends = _totalDividends.add(basicCoinAmount);
    _rate = _rate.add(
      basicCoinAmount.div(IERC20(_daoToken).totalSupply().div(10000))
    );
    return true;
  }
  
  function withdraw(address account) public returns (bool) {
    uint256 _amount = _getAvailable(account);
    for (uint256 i = 0; i < portfolioTokensList.length; i++) {
      uint256 balance = IERC20(portfolioTokensList[i]).balanceOf(address(this));     

      if (balance > 0) 
      {
        IERC20(portfolioTokensList[i]).safeTransfer(
          msg.sender,
          balance.mul(_amount).div(_totalDividends)
        );
      }
    }
    dividendRecords[account].available = 0;
    dividendRecords[account].rate = _rate;

    _totalDividends = _totalDividends.sub(_amount);

    return true;
  }

  function getRate() public view returns (uint256) {
    return _rate;
  }

  function rate(uint256 amount, uint256 initialRate)
    public
    view
    returns (uint256)
  {
    return amount.mul(_rate.sub(initialRate)).div(10000);
  }

  // temporary changed ================================================== 
  //function _getAvailable(address account) internal view returns (uint256) {
  // ================================================== temporary changed
  function _getAvailable(address account) public view returns (uint256) {
    if (_rate == 0) {
      return 0;
    }
    return
      rate(IERC20(_daoToken).balanceOf(account), dividendRecords[account].rate)
        .add(dividendRecords[account].available);
  }

  function balanceOf(address account) public view returns (uint256) {
    return _getAvailable(account);
  }

  // WARNING: added `amount` field to make compatible with IESW interface, the field is unused now
  function basicTransfer(
    address from,
    address to,
    // solhint-disable-next-line no-unused-vars
    uint256 amount
  ) public override {
    uint256 balanceFrom = _getAvailable(from);
    uint256 balanceTo = _getAvailable(to);

    dividendRecords[from].available = balanceFrom;
    dividendRecords[to].available = balanceTo;
    dividendRecords[from].rate = _rate;
    dividendRecords[to].rate = _rate;
  }

  // NOTICE: called from ESW.mint()
  // TODO: figure out the purpose of this function
  // WARNING: added `amount` field to make compatible with IESW interface
  // solhint-disable-next-line no-unused-vars
  function basicMint(address to, uint256 amount) public override {
    uint256 balanceTo = _getAvailable(to);
    dividendRecords[to].available = balanceTo;
    dividendRecords[to].rate = _rate;
  }
}