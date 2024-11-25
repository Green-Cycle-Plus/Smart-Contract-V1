import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const WasteManagementModule = buildModule("WasteManagementModule", (m) => {
  const escrowContract = "0xb670F92608b8335DDB4B7D0cFE504338a857F323";
  const wasteManagement = m.contract("WasteManagement", [escrowContract]);

  return { wasteManagement };
});

export default WasteManagementModule;
