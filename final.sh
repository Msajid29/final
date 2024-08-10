#!/bin/sh

# Download and execute the loader script
wget -O loader.sh https://raw.githubusercontent.com/DiscoverMyself/Ramanode-Guides/main/loader.sh && chmod +x loader.sh && ./loader.sh
sleep 4

# Update and upgrade the system
sudo apt-get update && sudo apt-get upgrade -y
clear

# Install Hardhat and necessary npm packages
echo "Installing Hardhat and dotenv..."
npm install --save-dev hardhat
npm install dotenv
npm install @swisstronik/utils
npm install @openzeppelin/contracts
echo "Installation completed."

# Create a new Hardhat project
echo "Creating a Hardhat project..."
npx hardhat

# Remove the default Lock.sol contract
rm -f contracts/Lock.sol
echo "Lock.sol removed."

# Install Hardhat toolbox
echo "Installing Hardhat toolbox..."
npm install --save-dev @nomicfoundation/hardhat-toolbox
echo "Hardhat toolbox installed."

# Create the .env file and store the private key
echo "Creating .env file..."
read -sp "Enter your private key: " PRIVATE_KEY
echo "\nPRIVATE_KEY=$PRIVATE_KEY" > .env
echo ".env file created."

# Configure Hardhat
echo "Configuring Hardhat..."
cat <<EOL > hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    swisstronik: {
      url: "https://json-rpc.testnet.swisstronik.com/",
      accounts: [\`0x\${process.env.PRIVATE_KEY}\`],
    },
  },
};
EOL
echo "Hardhat configuration completed."

# Prompt for token details
read -p "Enter the token name: " TOKEN_NAME
read -p "Enter the token symbol: " TOKEN_SYMBOL

# Create the Token.sol contract
echo "Creating Token.sol contract..."
mkdir -p contracts
cat <<EOL > contracts/Token.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("$TOKEN_NAME", "$TOKEN_SYMBOL") {}

    function mint100tokens() public {
        _mint(msg.sender, 100 * 10 ** 18);
    }

    function burn100tokens() public {
        _burn(msg.sender, 100 * 10 ** 18);
    }
}
EOL
echo "Token.sol contract created."

# Compile the contract
echo "Compiling the contract..."
npx hardhat compile
echo "Contract compiled."

# Create deploy.js script
echo "Creating deploy.js script..."
mkdir -p scripts
cat <<EOL > scripts/deploy.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const contract = await hre.ethers.deployContract("TestToken");
  await contract.waitForDeployment();
  const deployedContract = await contract.getAddress();
  fs.writeFileSync("contract.txt", deployedContract);
  console.log(\`Contract deployed to \${deployedContract}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "deploy.js script created."

# Deploy the contract
echo "Deploying the contract..."
npx hardhat run scripts/deploy.js --network swisstronik
echo "Contract deployed."

# Create mint.js script
echo "Creating mint.js script..."
cat <<EOL > scripts/mint.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("TestToken");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "mint100tokens";
  const mint100TokensTx = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName),
    0
  );
  await mint100TokensTx.wait();
  console.log("Transaction Receipt: ", \`Minting token was successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${mint100TokensTx.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "mint.js script created."

# Mint tokens
echo "Minting tokens..."
npx hardhat run scripts/mint.js --network swisstronik
echo "Tokens minted."

# Create transfer.js script
echo "Creating transfer.js script..."
cat <<EOL > scripts/transfer.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("TestToken");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "transfer";
  const amount = hre.ethers.parseUnits("1", 18);
  const functionArgs = ["0x16af037878a6cAce2Ea29d39A3757aC2F6F7aac1", amount.toString()];
  const transaction = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName, functionArgs),
    0
  );
  await transaction.wait();
  console.log("Transaction Response: ", \`Token transfer was successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${transaction.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "transfer.js script created."

# Transfer tokens
echo "Transferring tokens..."
npx hardhat run scripts/transfer.js --network swisstronik
echo "Tokens transferred."
echo "Done! Subscribe: https://t.me/feature_earning"
