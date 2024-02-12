// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {UniswapV2Factory} from "../src/UniswapV2Factory.sol";
import {MockToken} from "../src/mocks/MockToken.sol";
import {Math} from "@openzeppelin/contracts@v5.0.0/utils/math/Math.sol";
import "forge-std/console.sol";

contract UniswapV2FactoryTest is Test {

    using Math for uint256;
    address public OwnerWallet;
    address public UserWallet;
    address public lp;
    UniswapV2Pair pair;
    UniswapV2Factory factory;
    MockToken token0;
    MockToken token1;
    function setUp() public {
        OwnerWallet = address(69);
        UserWallet = address(420);
        lp = address(666);

        vm.deal(UserWallet, 1000 ether);
        vm.deal(lp, 1000 ether);

        vm.prank(OwnerWallet);
        factory = new UniswapV2Factory(address(OwnerWallet));

        token0 = new MockToken(address(this));
        token1 = new MockToken(address(this));
        token0.mint(address(this), 1010 ether);
        token1.mint(address(this), 1000 ether);
        token0.mint(address(lp), 100 ether);
        token1.mint(address(lp), 100 ether);
        token0.mint(address(UserWallet), 100 ether);
        token1.mint(address(UserWallet), 100 ether);

 //       pair = new UniswapV2Pair();

//        pair.initialize(address(token0), address(token1));

        //factory.createPair(address(token0), address(token1));


        //token0.approve(address(pair), 1000 ether);
        //token1.approve(address(pair), 1000 ether);
        //pair.mint(address(this), 100 ether, 100 ether, 0, 0);
    } 
    function test_creatPair() public {
        vm.startPrank(OwnerWallet);
        factory.createPair(address(token0), address(token1));
    }
}