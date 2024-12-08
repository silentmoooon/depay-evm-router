// Dependency file: contracts\interfaces\IPermit2.sol

// SPDX-License-Identifier: MIT

// pragma solidity 0.8.18;

interface IPermit2 {

  struct PermitDetails {
    address token;
    uint160 amount;
    uint48 expiration;
    uint48 nonce;
  }

  struct PermitSingle {
    PermitDetails details;
    address spender;
    uint256 sigDeadline;
  }

  struct PermitTransferFrom {
    TokenPermissions permitted;
    uint256 nonce;
    uint256 deadline;
  }

  struct TokenPermissions {
    address token;
    uint256 amount;
  }

  struct SignatureTransferDetails {
    address to;
    uint256 requestedAmount;
  }

  function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external;

  function transferFrom(address from, address to, uint160 amount, address token) external;

  function permitTransferFrom(PermitTransferFrom memory permit, SignatureTransferDetails calldata transferDetails, address owner, bytes calldata signature) external;

  function allowance(address user, address token, address spender) external view returns (uint160 amount, uint48 expiration, uint48 nonce);

}


// Dependency file: contracts\interfaces\IUnusPayRouter.sol


// pragma solidity 0.8.18;

// import 'contracts\interfaces\IPermit2.sol';

interface IUnusPayRouter {
    struct FromToken {
        address tokenAddress;
        uint256 amount;
        address swapTokenAddress;
        uint256 swapAmount;
        address exchangeAddress;
        bytes exchangeCallData;
        uint8 exchangeType;
    }


    struct ToToken {
        address tokenAddress;
        uint256 amount;
        uint256 feeAmount;
    }

    struct Payment {
        FromToken[] fromTokens;
        ToToken[] toTokens;
        address paymentReceiverAddress;
        address feeReceiverAddress;
        uint256 deadline;
    }




    function pay(
        Payment calldata payment
    ) external payable returns (bool);

    function convert(IUnusPayRouter.FromToken[] calldata payment) external payable returns (bool);

    event Enabled(
        address indexed exchange
    );

    event Disabled(
        address indexed exchange
    );

    function enable(address exchange, bool enabled) external returns (bool);

    function withdraw(address token, uint amount) external returns (bool);

}


// Root file: contracts\interfaces\IUnusPayForwarder.sol


pragma solidity 0.8.18;

// import 'contracts\interfaces\IUnusPayRouter.sol';

interface IUnusPayForwarder {

  function forward(
    IUnusPayRouter.Payment calldata payment
  ) external payable returns(bool);

  function toggle(bool stop) external returns(bool);

}
