pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDX is ERC20 {
  uint256 private constant _INITIAL_SUPPLY = 100000000 * (10**10);

  constructor() public ERC20("USDX stable coin", "USDX") {
    _setupDecimals(10);
    _mint(msg.sender, _INITIAL_SUPPLY);
  }
}
