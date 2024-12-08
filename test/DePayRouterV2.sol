// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {UnusPayForwarder} from "../contracts/UnusPayForwarderV2.sol";
import {UnusPayRouter} from "../contracts/UnusPayRouterV2.sol";

contract UnusPayRouterV2Test is Test {
    UnusPayForwarder public forwarder;
    UnusPayRouter public router;

    function setUp() public {
        forwarder = new UnusPayForwarderV2();
        router = new UnusPayRouterV2(address(0), address(forwarder));
    }

    function test_enable() public {
        router.enable(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD, true);
        assert(router.exchanges(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD) == true);
    }
}
