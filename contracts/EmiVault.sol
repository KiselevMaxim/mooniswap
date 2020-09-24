// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IESD.sol";

contract EmiVault {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  uint256 private _totalValue;
  address private _dividendToken;
  address private _owner;
  uint8 private _initialized;

  mapping(address => uint8) private _trustedFactories;

  modifier onlyOwner() {
    require(_owner == msg.sender, "Ownable: caller is not vault");
    _;
  }

  function initialize(address dividendToken) public {
    require(_initialized == 0, "Already initialized");
    _dividendToken = dividendToken;
    _owner = msg.sender;
    _initialized = 1;
  }

  function _getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) internal pure returns (uint256 amountOut) {
    require(amountIn > 0, "EmiswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
    require(
      reserveIn > 0 && reserveOut > 0,
      "EmiswapV2Library: INSUFFICIENT_LIQUIDITY"
    );
    uint256 amountInWithFee = amountIn.mul(997);
    uint256 numerator = amountInWithFee.mul(reserveOut);
    uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
    amountOut = numerator / denominator;
  }

  /* Temporary removed */
  /* function exchange(
    address factory,
    address tokenFrom,
    address tokenTo
  ) public returns (bool) {
    require(_trustedFactories[factory] == 1, "Exchange not authorized");
    require(
      IESD(_dividendToken).portfolioTokenStatus(tokenFrom) != 1 &&
        IESD(_dividendToken).portfolioTokenStatus(tokenTo) == 1,
      "Exchange not permitted"
    );

    uint256 balance = IERC20(tokenFrom).balanceOf(address(this));

    // WARNING: tokens aren't sorted
    // WARNING: no check for trusted factory
    address pairContract = IUniswapV2Factory(factory).getPair(
      tokenFrom,
      tokenTo
    );
    require(pairContract != address(0), "Pair not found");
    (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairContract)
      .getReserves();

    IERC20(tokenFrom).safeTransfer(pairContract, balance);

    uint256 coinAmount = 0;
    if (tokenFrom < tokenTo) {
      coinAmount = _getAmountOut(balance, reserve0, reserve1);
      // TODO: fix arguments (requires 4 arguments)
      // IUniswapV2Pair(pairContract).swap(0, coinAmount);
    } else {
      coinAmount = _getAmountOut(balance, reserve1, reserve0);
      // TODO: fix arguments (requires 4 arguments)
      // IUniswapV2Pair(pairContract).swap(coinAmount, 0);
    }
  } */

  function setTrustedFactory(address factory, uint8 status)
    public
    onlyOwner
    returns (bool)
  {
    _trustedFactories[factory] = status;
  }

  function setDividendToken(address dividendToken) public {
    _dividendToken = dividendToken;
  }

  function totalValue() public view returns (uint256) {
    return _totalValue;
  }

  function deposit(address token, uint256 value) public returns (bool) {
    _totalValue = _totalValue.add(value);

    // temporary add ===========================================
    IERC20(token).approve(_dividendToken, value);
    // =========================================== temporary add

    IESD(_dividendToken).addDividends(token, value);
    return (true);
  }

  // ??? _totalValue not used, remove?
  function withdraw(uint256, uint256 value) public returns (bool) {
    _totalValue = _totalValue.sub(value);
    return (true);
  }
}