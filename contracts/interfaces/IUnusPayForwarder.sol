// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import './IUnusPayRouter.sol';

interface IUnusPayForwarder {

  function forward(
    IUnusPayRouter.Payment calldata payment
  ) external payable returns(bool);

  function toggle(bool stop) external returns(bool);

}
