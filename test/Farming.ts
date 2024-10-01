import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("TeraFarming", function () {
    var teraFarming, nftContract, rewardToken;
    let owner, user1, user2;
    let rewardRate = 10;

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock NFT contract
        const MockNFT = await ethers.getContractFactory("MockNFT");
        nftContract = await MockNFT.deploy();
        await nftContract.waitForDeployment();

        // Mint an NFT for user1
        await nftContract.mint(user1.address, 1);

        // Deploy mock ERC20 token contract
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        rewardToken = await MockERC20.deploy();
        await rewardToken.waitForDeployment();

        // Deploy the TeraFarming contract
        const TeraFarming = await ethers.getContractFactory("TeraFarming");
        teraFarming = await TeraFarming.deploy(owner.address, nftContract.target, rewardToken.target, rewardRate);
        await teraFarming.waitForDeployment();

        // Mint some reward tokens
        // await rewardToken.mint(owner.address, ethers.utils.parseEther("1000"));
        // await rewardToken.transfer(teraFarming.target, ethers.utils.parseEther("1000"));
    });

});