import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const WasteManagementModule = buildModule("WasteManagementModule", (m) => {
  const escrowContract = "0xEfF517687753FFEc4b0536a735a06FD9EB1094b3";
  const wasteManagement = m.contract("WasteManagement", [escrowContract]);

  return { wasteManagement };
});

export default WasteManagementModule;
