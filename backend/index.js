import express from 'express';
import { ethers } from 'ethers';
import cors from 'cors';
import dotenv from 'dotenv';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config();

const app = express();
app.use(express.json());
app.use(cors());

const RPC_URL = process.env.RPC_URL || 'http://127.0.0.1:8545';
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || '';
const PRIVATE_KEY = process.env.PRIVATE_KEY || '';

if (!CONTRACT_ADDRESS) {
  console.error('CONTRACT_ADDRESS environment variable is required');
  process.exit(1);
}

if (!PRIVATE_KEY) {
  console.error('PRIVATE_KEY environment variable is required');
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const signer = wallet.connect(provider);

let CONTRACT_ABI;
try {
  const abiPath = join(__dirname, 'contract-abi.json');
  const abiFile = readFileSync(abiPath, 'utf8');
  CONTRACT_ABI = JSON.parse(abiFile);
} catch (error) {
  console.error('Error loading contract ABI:', error);
  process.exit(1);
}

let contract;

try {
  contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, provider);
} catch (error) {
  console.error('Error initializing contract:', error);
  process.exit(1);
}

function getContractWithSigner() {
  return new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
}

app.get('/campaigns', async (req, res) => {
  try {
    const totalCampaigns = await contract.totalCampaigns();
    const campaigns = [];

    for (let i = 0; i < Number(totalCampaigns); i++) {
      const campaignData = await contract.campaigns(i);
      const ethRaised = await contract.getTotalRaised(i, ethers.ZeroAddress);

      campaigns.push({
        id: i,
        owner: campaignData.owner,
        goalAmount: campaignData.goalAmount.toString(),
        deadline: campaignData.deadline.toString(),
        title: campaignData.title,
        description: campaignData.description,
        raisedAmount: ethRaised.toString(),
        withdrawn: campaignData.withdrawn,
      });
    }

    res.json({ campaigns, total: campaigns.length });
  } catch (error) {
    console.error('Error fetching campaigns:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/campaigns', async (req, res) => {
  try {
    const { goalAmount, deadline, title, description } = req.body;

    if (!goalAmount || !deadline || !title || !description) {
      return res.status(400).json({
        error:
          'Missing required fields: goalAmount, deadline, title, description',
      });
    }

    const contractWithSigner = getContractWithSigner();
    const tx = await contractWithSigner.createCampaign(
      goalAmount,
      deadline,
      title,
      description
    );

    const receipt = await tx.wait();

    const event = receipt.logs.find((log) => {
      try {
        const parsed = contract.interface.parseLog(log);
        return parsed && parsed.name === 'CampaignCreated';
      } catch {
        return false;
      }
    });

    let campaignId = null;
    if (event) {
      const parsed = contract.interface.parseLog(event);
      campaignId = parsed.args.id.toString();
    }

    res.json({
      success: true,
      transactionHash: tx.hash,
      campaignId,
      receipt: {
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString(),
      },
    });
  } catch (error) {
    console.error('Error creating campaign:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/contribute', async (req, res) => {
  try {
    const { campaignId, amount, token } = req.body;

    if (
      campaignId === undefined ||
      campaignId === null ||
      amount === undefined
    ) {
      return res.status(400).json({
        error: 'Missing required fields: campaignId, amount',
      });
    }

    const contractWithSigner = getContractWithSigner();
    let tx;

    if (token) {
      tx = await contractWithSigner.contributeToken(campaignId, token, amount);
    } else {
      tx = await contractWithSigner.contributeETH(campaignId, {
        value: amount,
      });
    }

    const receipt = await tx.wait();

    res.json({
      success: true,
      transactionHash: tx.hash,
      receipt: {
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString(),
      },
    });
  } catch (error) {
    console.error('Error contributing:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/refund', async (req, res) => {
  try {
    const { campaignId, token } = req.body;

    if (campaignId === undefined || campaignId === null) {
      return res.status(400).json({
        error: 'Missing required field: campaignId',
      });
    }

    const contractWithSigner = getContractWithSigner();
    const tokenAddress = token || ethers.ZeroAddress;

    const tx = await contractWithSigner.refund(campaignId, tokenAddress);
    const receipt = await tx.wait();

    res.json({
      success: true,
      transactionHash: tx.hash,
      receipt: {
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString(),
      },
    });
  } catch (error) {
    console.error('Error refunding:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/withdraw', async (req, res) => {
  try {
    const { campaignId } = req.body;

    if (campaignId === undefined || campaignId === null) {
      return res.status(400).json({
        error: 'Missing required field: campaignId',
      });
    }

    const contractWithSigner = getContractWithSigner();
    const tx = await contractWithSigner.withdraw(campaignId);
    const receipt = await tx.wait();

    res.json({
      success: true,
      transactionHash: tx.hash,
      receipt: {
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString(),
      },
    });
  } catch (error) {
    console.error('Error withdrawing:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', contractAddress: CONTRACT_ADDRESS });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Backend server running on port ${PORT}`);
  console.log(`Contract address: ${CONTRACT_ADDRESS}`);
  console.log(`RPC URL: ${RPC_URL}`);
});
