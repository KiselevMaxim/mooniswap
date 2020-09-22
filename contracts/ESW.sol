// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "./ProxiedERC20.sol";
import "./interfaces/IESD.sol";

contract ESW is ProxiedERC20 {
  address public dividendToken;
  address internal _votingContract;
  address internal _owner;
  uint256 internal _initialSupply;
  mapping(address => uint256) internal _mintLimit;

  modifier onlyOwner() {
    require(_owner == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  function initialize() public virtual {
    _initialize("EmiDAO Token", "ESW", 18);
    _owner = msg.sender;
  }

  function initialSupply() public view returns (uint256) {
    return _initialSupply;
  }

  function setDividendToken(address _dividendToken) public {
    dividendToken = _dividendToken;
  }

  function transfer(address recipient, uint256 amount)
    public
    virtual
    override
    returns (bool)
  {
    IESD(dividendToken).basicTransfer(msg.sender, recipient, amount);
    super.transfer(recipient, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override returns (bool) {
    IESD(dividendToken).basicTransfer(sender, recipient, amount);
    super.transferFrom(sender, recipient, amount);
    return true;
  }

  function getMintLimit(address account) public view onlyOwner returns(uint256) {
    return _mintLimit[account];
  }

  function setMintLimit(address account, uint256 amount) public onlyOwner {
    _mintLimit[account] = amount;
  }

  function mint(address recipient, uint256 amount) public {
    _mintLimit[msg.sender] = _mintLimit[msg.sender].sub(amount);
    IESD(dividendToken).basicMint(recipient, amount);
    super._mint(recipient, amount);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {}
}
