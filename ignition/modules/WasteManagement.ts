import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const WasteManagementModule = buildModule("WasteManagementModule", (m) => {
  const escrowContract = "0xb670F92608b8335DDB4B7D0cFE504338a857F323";

  const RecyclerLib = m.library("RecyclerLib");
  const RequestLib = m.library("RequestLib");
  const UserLib = m.library("UserLib");
  const CollectorLib = m.library("CollectorLib");

  const wasteManagement = m.contract("WasteManagement", [escrowContract], {
    libraries: {
      RecyclerLib: RecyclerLib,
      RequestLib: RequestLib,
      UserLib: UserLib,
      CollectorLib: CollectorLib
    }
  });

  return { wasteManagement };
});

export default WasteManagementModule;
