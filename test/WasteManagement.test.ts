import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

describe("WasteManagement Contract", function () {
  async function deployFixture() {
    const [owner, user1, user2, recycler, collector, otherCollector] = await ethers.getSigners();

    // Deploy Escrow contract
    const Escrow = await ethers.getContractFactory("EscrowContract");
    const escrow = await Escrow.deploy();

    const CollectorLib = await ethers.getContractFactory("CollectorLib");
    const collectorLib = await CollectorLib.deploy();

    const RecyclerLib = await ethers.getContractFactory("RecyclerLib");
    const recyclerLib = await RecyclerLib.deploy();

    const UserLib = await ethers.getContractFactory("UserLib");
    const userLib = await UserLib.deploy();

    const RequestLib = await ethers.getContractFactory("RequestLib");
    const requestLib = await RequestLib.deploy();

    const WasteLib = await ethers.getContractFactory("waste");
    const wasteErr = await WasteLib.deploy();


    
  

    // Deploy WasteManagement contract
    const WasteManagement = await ethers.getContractFactory("WasteManagement", {
      libraries: {
        UserLib: userLib.target,
        RecyclerLib: recyclerLib.target,
        CollectorLib: collectorLib.target,
        RequestLib: requestLib.target,
      },
    });

    const wasteManagement = await WasteManagement.deploy(escrow.getAddress());
  

    return { wasteManagement, escrow, owner, user1, user2, recycler, collector, otherCollector, wasteErr };
  }
  
  // removed direct user registration and user management test as a result of modifying the contract

  describe("Recycler Management", function () {
    it("Should allow registering a recycler", async function () {
      const { wasteManagement, recycler } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);

      const recyclerInfo = await wasteManagement.recyclers(recycler.address);
      expect(recyclerInfo.isRegistered).to.be.true;
      expect(recyclerInfo.location).to.equal("City A");
    });

    it("It should get all the recyclers", async function () {
      const { wasteManagement, recycler } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);

      const recyclerInfo = await wasteManagement.recyclers(recycler.address);
      const recycer = await wasteManagement.seeAllRecyclers();
      expect(recycer.length).to.be.equal(1);
      expect(recyclerInfo.isRegistered).to.be.true;
      expect(recyclerInfo.location).to.equal("City A");
    });

    it("Should not allow duplicate recycler registration", async function () {
      const { wasteManagement, recycler, wasteErr } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await expect(wasteManagement.createRecycler(recycler.address, "City B", 789, 101)).to.be.revertedWithCustomError(wasteErr, "RECYCLER_ALREADY_REGISTERED");
    });

    it("Should revert registration with invalid coordinates", async function () {
      const { wasteManagement, recycler, wasteErr } = await loadFixture(deployFixture);

      await expect(wasteManagement.createRecycler(recycler.address, "City A", 0, 456)).to.be.revertedWithCustomError(wasteErr, "INVALIDLATITUTUDE");
      await expect(wasteManagement.createRecycler(recycler.address, "City A", 123, 0)).to.be.revertedWithCustomError(wasteErr, "INVALIDLONGITUDE");
    });
  });

  describe("Offer Management", function () {
    it("Should allow a recycler to create an offer", async function () {
      const { wasteManagement, recycler } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);

      const offer = await wasteManagement.recyclerOffers(recycler.address);
      expect(offer[0].name).to.equal("Plastic");
      expect(offer[0].pricePerKg).to.equal(10);
      expect(offer[0].minQuantity).to.equal(5);
    });

    it("Should get all offers of a recycler", async function () {
      const { wasteManagement, recycler } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);

      const offers = await wasteManagement.getRecyclerOffers(1);
      expect(offers.length).to.equal(1);      
    });


    it("Should revert creating an offer by unregistered recycler", async function () {
      const { wasteManagement, user1, wasteErr } = await loadFixture(deployFixture);

      await expect(wasteManagement.connect(user1).createOffer("Plastic", 10, 5)).to.be.revertedWithCustomError(wasteErr, "INVALIDRECYCLER");
    });

    it("Should update an offer", async function () {
      const { wasteManagement, recycler } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);

      const tx = await wasteManagement.connect(recycler).getRecyclerOffers(1);
      console.log(tx)

      const tx2 = await wasteManagement.connect(recycler).viewOffer(recycler.getAddress(), 0);
      console.log(tx2)

      await wasteManagement
        .connect(recycler)
        .updateOffer(0, "Updated Plastic", recycler.address, 15, 3);
      
       // Retrieve updated offer
      const updatedOffer = await wasteManagement.connect(recycler).viewOffer(recycler.address, 0);
      expect(updatedOffer.name).to.equal("Updated Plastic");
      expect(updatedOffer.pricePerKg).to.equal(15);
      expect(updatedOffer.minQuantity).to.equal(3);
    });
  });

  describe("Request Management", function () {
    it("Should allow a user to make a waste collection request", async function () {
      const { wasteManagement, user1, recycler } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
      await wasteManagement.connect(user1).makeRequest(1, 0, 10, 100, 6, 5);

      const userRequest = await wasteManagement.connect(user1).getAllUserRequest();
      // console.log("All User Requests:", userRequest);
      const request = await wasteManagement.showRequest(1);
      expect(request.userAddress).to.equal(user1.address);
      expect(request.recyclerAddress).to.equal(recycler.address);
      expect(request.weight).to.equal(10);
      expect(request.valuedAt).to.equal(100);
    });

    it("Should allow a recycler to accept a request", async function () {
      const { wasteManagement, user1, recycler, collector } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
      await wasteManagement.connect(user1).makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);

      await wasteManagement.connect(recycler).acceptRequest(1, collector.address, {value: ethers.parseEther("1")});
      const request = await wasteManagement.showRequest(1);
      console.log(request.status);
      expect(request.status).to.be.equal(1);
      expect(request.isAccepted).to.be.true;
      expect(request.assignedCollector).to.equal(collector.address);
    });

    it("Should revert if a user tries to make a request with insufficient weight", async function () {
      const { wasteManagement, user1, recycler, wasteErr } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
      
      await expect(
          wasteManagement.connect(user1).makeRequest(1, 0, 3, ethers.parseEther("1"), 6, 5)
      ).to.be.revertedWithCustomError(wasteErr, "LOWER_THAN_MINQUANTITY");
  });



    it("Should revert if recycler deposit amount less than valuedAt by user", async function () {
      const { wasteManagement, user1, recycler, collector, wasteErr } = await loadFixture(deployFixture);
  
      // Register recycler and create an offer
      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
  
      // Register user and make a request
      await wasteManagement.connect(user1).makeRequest(
          1,
          0,
          10, // Weight
          ethers.parseEther("1"), // Valued at 1 Ether
          6,
          5
      );
  
      // Try to accept the request with insufficient deposit
      await expect(
          wasteManagement.connect(recycler).acceptRequest(1, collector.address, {
              value: ethers.parseEther("0.5"), // Less than 1 Ether
          })
      ).to.be.revertedWithCustomError(wasteErr, "AMOUNT_LESS_THAN_AMOUNT_VALUED");
  });


    it("Should allow the collector to confirm the request", async function () {
      const { wasteManagement, user1, recycler, collector } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
      await wasteManagement.connect(user1).makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);
      await wasteManagement.connect(recycler).acceptRequest(1, collector.address, {value: ethers.parseEther("1")});

      await wasteManagement.connect(collector).confirmRequest(1);
      const request = await wasteManagement.showRequest(1);
      expect(request.status).to.be.equal(2)
      expect(request.isCompleted).to.be.true;
    });


    it("Should get recycler requests", async function () {
      const { wasteManagement, user1, recycler, collector } = await loadFixture(deployFixture);

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
      await wasteManagement.connect(user1).makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);      
      await wasteManagement.connect(user1).makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);      
      const tx2 = await wasteManagement.getRecyclerRequests(1);
      expect(tx2.length).equal(2)
  });


  it("Should get all user requests", async function () {
    const { wasteManagement, user1, recycler, collector } = await loadFixture(deployFixture);

    await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
    await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
    await wasteManagement.connect(user1).makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);      
    await wasteManagement.connect(user1).makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);      
    const tx2 = await wasteManagement.getAllUserRequests(user1);
    // console.log(tx2);
    
  
    expect(tx2.length).equal(2)
});

    it("Should revert if a non-assigned collector tries to confirm the request", async function () {
      const { wasteManagement, user1, recycler, collector, otherCollector, wasteErr } = await loadFixture(
          deployFixture
      );

      await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
      await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
      await wasteManagement
          .connect(user1)
          .makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);

      await wasteManagement.connect(recycler).acceptRequest(1, collector.address, {
          value: ethers.parseEther("1"),
      });

      await expect(wasteManagement.connect(otherCollector).confirmRequest(1)).to.be.revertedWithCustomError(
          wasteErr,
          "NOT_ASSIGNED"
      );
  });

  it("Should allow a user to cancel their request if it has not been accepted", async function () {
    const { wasteManagement, user1, recycler } = await loadFixture(deployFixture);

    await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
    await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
    await wasteManagement
        .connect(user1)
        .makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);

    await wasteManagement.connect(user1).userCancelRequest(1);

    const request = await wasteManagement.showRequest(1);
    expect(request.status).to.be.equal(3);
});

it("Should revert if a user tries to cancel an accepted request", async function () {
    const { wasteManagement, user1, recycler, collector, wasteErr } = await loadFixture(deployFixture);

    await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
    await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
    await wasteManagement
        .connect(user1)
        .makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5) ;

    await wasteManagement.connect(recycler).acceptRequest(1, collector.address, {
        value: ethers.parseEther("1"),
    });

    await expect(wasteManagement.connect(user1).userCancelRequest(1)).to.be.revertedWithCustomError(
      wasteErr,
        "ALREADY_ACCEPTED"
    );
});

it("Should revert if a user tries to cancel a completed request", async function () {
    const { wasteManagement, user1, recycler, collector, wasteErr } = await loadFixture(deployFixture);

    await wasteManagement.createRecycler(recycler.address, "City A", 123, 456);
    await wasteManagement.connect(recycler).createOffer("Plastic", 10, 5);
    await wasteManagement
        .connect(user1)
        .makeRequest(1, 0, 10, ethers.parseEther("1"), 6, 5);

    await wasteManagement.connect(recycler).acceptRequest(1, collector.address, {
        value: ethers.parseEther("1"),
    });

    await wasteManagement.connect(collector).confirmRequest(1);

    await expect(wasteManagement.connect(user1).userCancelRequest(1)).to.be.revertedWithCustomError(
        wasteErr,
        "ALREADY_COMPLETED"
    );
});

  });
});
