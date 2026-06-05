import { createPublicClient, http, formatEther } from 'viem';
import { optimism, base } from 'viem/chains';

async function verifySetup() {
    // 1. Initialize Clients
    const opClient = createPublicClient({ chain: optimism, transport: http() });
    const baseClient = createPublicClient({ chain: base, transport: http() });

    // 2. Fetch Gas Prices (Critical for Arb Profit calculation)
    const opGas = await opClient.getGasPrice();
    const baseGas = await baseClient.getGasPrice();

    console.log(`✅ Viem Connected!`);
    console.log(`Optimism Gas: ${formatEther(opGas)} ETH`);
    console.log(`Base Gas: ${formatEther(baseGas)} ETH`);
}

verifySetup().catch(console.error);
