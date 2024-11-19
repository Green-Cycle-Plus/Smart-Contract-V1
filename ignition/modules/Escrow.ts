import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const EscrowModule = buildModule("EscrowModule", (m) => {

  const escrow = m.contract("EscrowContract");

  return { escrow };
});

export default EscrowModule;
