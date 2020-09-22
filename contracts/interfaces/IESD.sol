// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IESD {
  function basicTransfer(
    address,
    address,
    uint256
  ) external;

  function basicMint(address to, uint256 amount) external;

  function addDividends(address asset, uint256 amount) external returns (bool);

  function portfolioTokenStatus(address token) external view returns (uint8);
}
