// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import './IUnusPayRouterV2.sol';

interface IUnusPayForwarderV2 {

  function forward(
    IUnusPayRouterV2.Payment calldata payment
  ) external payable returns(bool);

  function toggle(bool stop) external returns(bool);

}
