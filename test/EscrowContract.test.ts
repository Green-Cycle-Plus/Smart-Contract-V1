import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

describe("EscrowContract", function () {
  async function deployEscrowFixture() {
    // Get test accounts
    const [payer, payee, otherAccount] = await ethers.getSigners();

    // Deploy the EscrowContract
    const escrow = await ethers.deployContract("EscrowContract");

    return { escrow, payer, payee, otherAccount };
  }

  it("should create a new escrow with valid payment", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund the escrow
    const tx = await escrow.connect(payer).createEscrow(payee.address, { value: amount });
    await tx.wait();

    // Verify the escrow details
    const escrowDetails = await escrow.escrows(1);
    expect(escrowDetails.payer).to.equal(payer.address);
    expect(escrowDetails.payee).to.equal(payee.address);
    expect(escrowDetails.amount).to.equal(amount);
    expect(escrowDetails.isFunded).to.be.true;
    expect(escrowDetails.isReleased).to.be.false;
    expect(escrowDetails.isRefunded).to.be.false;
  });

  it("should emit EscrowCreated event on escrow creation", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund the escrow and check for event
    await expect(escrow.connect(payer).createEscrow(payee.address, { value: amount }))
      .to.emit(escrow, "EscrowCreated")
      .withArgs(1, payer.address, payee.address, amount);
  });

  it("should allow payer or payee to release funds to payee", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund the escrow
    await escrow.connect(payer).createEscrow(payee.address, { value: amount });

    // Release funds as the payer
    await expect(escrow.connect(payer).releaseEscrow(1))
      .to.emit(escrow, "EscrowReleased")
      .withArgs(1);

    // Verify payee received the funds
    const payeeBalanceAfter = await ethers.provider.getBalance(payee.address);
    expect(payeeBalanceAfter).to.be.above(amount);
  });

  it("should prevent unauthorized accounts from releasing escrow", async function () {
    const { escrow, payer, payee, otherAccount } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund the escrow
    await escrow.connect(payer).createEscrow(payee.address, { value: amount });

    // Attempt to release funds as an unauthorized user
    await expect(escrow.connect(otherAccount).releaseEscrow(1)).to.be.revertedWithCustomError(
      escrow,
      "Unauthorized"
    );
  });

  it("should allow only the payer to refund escrow", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund the escrow
    await escrow.connect(payer).createEscrow(payee.address, { value: amount });

    // Refund the escrow as the payer
    await expect(escrow.connect(payer).refundEscrow(1))
      .to.emit(escrow, "EscrowRefunded")
      .withArgs(1);

    // Verify payer received the refunded amount
    const payerBalanceAfter = await ethers.provider.getBalance(payer.address);
    expect(payerBalanceAfter).to.be.above(amount);
  });

  it("should prevent payee from refunding escrow", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund the escrow
    await escrow.connect(payer).createEscrow(payee.address, { value: amount });

    // Attempt to refund as the payee
    await expect(escrow.connect(payee).refundEscrow(1)).to.be.revertedWithCustomError(
      escrow,
      "Unauthorized"
    );
  });

  it("should prevent release of already released escrow", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund and release the escrow
    await escrow.connect(payer).createEscrow(payee.address, { value: amount });
    await escrow.connect(payer).releaseEscrow(1);

    // Attempt to release again
    await expect(escrow.connect(payer).releaseEscrow(1)).to.be.revertedWithCustomError(
      escrow,
      "AlreadyReleased"
    );
  });

  it("should prevent refund of already released escrow", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund and release the escrow
    await escrow.connect(payer).createEscrow(payee.address, { value: amount });
    await escrow.connect(payer).releaseEscrow(1);

    // Attempt to refund
    await expect(escrow.connect(payer).refundEscrow(1)).to.be.revertedWithCustomError(
      escrow,
      "AlreadyReleased"
    );
  });

  it("should prevent refund of already refunded escrow", async function () {
    const { escrow, payer, payee } = await loadFixture(deployEscrowFixture);
    const amount = ethers.parseEther("1.0");

    // Fund and refund the escrow
    await escrow.connect(payer).createEscrow(payee.address, { value: amount });
    await escrow.connect(payer).refundEscrow(1);

    // Attempt to refund again
    await expect(escrow.connect(payer).refundEscrow(1)).to.be.revertedWithCustomError(
      escrow,
      "AlreadyRefunded"
    );
  });
});
