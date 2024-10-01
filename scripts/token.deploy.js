const { ethers } = require("hardhat");

async function main() {
    const [owner] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", owner.address);

    const TERACToken = await ethers.getContractFactory("TERACToken");
    const teToken = await TERACToken.deploy(owner.address, 1000);
    console.log("TERACToken deployed to: ", teToken.target);

    const GynxToken = await ethers.getContractFactory("GYNXToken");
    const gToken = await GynxToken.deploy(owner.address, 1000);

    console.log("TERACToken deployed to: ", gToken.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
