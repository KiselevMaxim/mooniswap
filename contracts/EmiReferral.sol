// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.12;


contract EmiReferral {
  
  uint256 public l1ReferralShare = 50; // 5%
  uint256 public l2ReferralShare = 30; // 3%
  uint256 public l3ReferralShare = 15; // 1.5%

  mapping(address => address) public referrals;

  function addReferral(address _user, address _referral) external {
    referrals[_user] = _referral;
  }

  // VIEW METHODS
  function getReferralChain(address _user) external view returns (address[] memory userReferrals) {
    address l1 = referrals[_user];

    // len == 0
    if (l1 == address(0)) {
      return userReferrals;
    }

    // len == 1
    address l2 = referrals[l1];
    if (l2 == address(0)) {
      userReferrals = new address[](1);
      userReferrals[0] = l1;
      return userReferrals;
    }

    // len == 2
    address l3 = referrals[l2];
    if (l3 == address(0)) {
      userReferrals = new address[](2);
      userReferrals[0] = l1;
      userReferrals[1] = l2;

      return userReferrals;
    }

    // len == 3
    userReferrals = new address[](3);
    userReferrals[0] = l1;
    userReferrals[1] = l2;
    userReferrals[2] = l3;
  }
}