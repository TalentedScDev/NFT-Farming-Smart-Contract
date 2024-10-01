const { ethers } = require("hardhat");

async function main() {
    const [owner] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", owner.address);

    const receiveTokenAddress = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    const rewardTokenAddress = "0xCEa8c90402D0139e98BF7901A12Ac86039c36F1C";    // gynx address
    const rewardRate = 1e4;

    const TerafarmStaking = await ethers.getContractFactory("TeraStaking");
    const Terafarm = await TerafarmStaking.deploy(owner.address, receiveTokenAddress, rewardTokenAddress, rewardRate);

    console.log("Terafarm deployed to: ", Terafarm.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
