// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Bettle} from "../Bettle.sol";

contract ContractTest is DSTest {

    Vm vm = Vm(HEVM_ADDRESS);
    Bettle bet;

    function setUp() public {
        bet = new Bettle();
    }

    // function test_getLatestPrice() public {
    //     emit log_named_int("Price: ", bet.getLatestPrice());
    // }
}
