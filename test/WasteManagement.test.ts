import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("WasteManagement Contract", function () {
    let wasteManagement: any;
    let escrowContract: any;
    let user: any, recycler: any, collector: any;

    async function deployFixture() {
        // Deploy mock escrow contract
        escrowContract = await ethers.deployContract("EscrowContract");

        // Deploy WasteManagement contract
        wasteManagement = await ethers.deployContract("WasteManagement", [await escrowContract.getAddress()]);

        // Get signers
        [user, recycler, collector] = await ethers.getSigners();

        return { wasteManagement, escrowContract, user, recycler, collector };
    }

    describe("User Registration", function () {
        it("should allow a user to register", async function () {
            const { wasteManagement, user } = await loadFixture(deployFixture);
            await wasteManagement.connect(user).createUser();
            const registeredUser = await wasteManagement.users(user.address);
            expect(registeredUser.isRegistered).to.be.true;
        });

        it("should not allow a user to register twice", async function () {
            const { wasteManagement, user } = await loadFixture(deployFixture);
            await wasteManagement.connect(user).createUser();
            await expect(wasteManagement.connect(user).createUser()).to.be.revertedWithCustomError(wasteManagement, "REGISTERED");
        });
    });

    describe("Recycler Registration", function () {
        it("should allow a recycler to register", async function () {
            const { wasteManagement, recycler } = await loadFixture(deployFixture);
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            const registeredRecycler = await wasteManagement.recyclers(recycler.address);
            expect(registeredRecycler.isRegistered).to.be.true;
        });

        it("should not allow a recycler to register twice", async function () {
            const { wasteManagement, recycler } = await loadFixture(deployFixture);
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            await expect(wasteManagement.connect(recycler).createRecycler(recycler.address, "Location B", 4)).to.be.revertedWithCustomError(wasteManagement, "REGISTERED");
        });
    });

    describe("Offer Management", function () {
        it("should allow a recycler to create an offer", async function () {
            const { wasteManagement, recycler } = await loadFixture(deployFixture);
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            await wasteManagement.connect(recycler).createOffer("Plastic", ethers.parseEther("0.5"), 10);
        });
    });

    describe("Collection Request Management", function () {
        it("should allow a user to make a collection request", async function () {
            const { wasteManagement, user, recycler } = await loadFixture(deployFixture);
            await wasteManagement.connect(user).createUser();
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            await wasteManagement.connect(recycler).createOffer("Plastic", ethers.parseEther("0.5"), 10);
            await wasteManagement.connect(user).makeRequest(recycler.address, "Plastic", 15, ethers.parseEther("7.5"));
            const request = await wasteManagement.collectionRequests(1); // Assuming it's the first request
            expect(request.userAddress).to.equal(user.address);
            expect(request.recyclerAddress).to.equal(recycler.address);
            expect(request.weight).to.equal(15);
        });

        it("should not allow requests below minimum quantity", async function () {
            const { wasteManagement, user, recycler } = await loadFixture(deployFixture);
            await wasteManagement.connect(user).createUser();
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            await wasteManagement.connect(recycler).createOffer("Plastic", ethers.parseEther("0.5"), 10);
            await expect(wasteManagement.connect(user).makeRequest(recycler.address, "Plastic", 5, ethers.parseEther("2.5"))).to.be.revertedWithCustomError(wasteManagement, 'LOWER_THAN_MINQUANTITY');
        });
        
        it("should allow a recycler to accept a collection request", async function () {
            const { wasteManagement, user, recycler, collector } = await loadFixture(deployFixture);
            
            await wasteManagement.connect(user).createUser();
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            await wasteManagement.connect(recycler).createOffer("Plastic", ethers.parseEther("0.5"), 10);
            await wasteManagement.connect(user).makeRequest(recycler.address, "Plastic", 15, ethers.parseEther("7.5"));
        
            // Register the collector and set them as available
            await wasteManagement.connect(collector).createCollector(collector.address); // Ensure collector is registered
        
            await wasteManagement.connect(recycler).acceptRequest(1, collector.address);
            
            const request = await wasteManagement.collectionRequests(1);
            expect(request.isAccepted).to.be.true;
            expect(request.assignedCollector).to.equal(collector.address);
        });
        
        it("should allow a collector to confirm collection completion", async function () {
            const { wasteManagement, user, recycler } = await loadFixture(deployFixture);
            await wasteManagement.connect(user).createUser();
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            await wasteManagement.connect(recycler).createOffer("Plastic", ethers.parseEther("0.5"), 10);
            await wasteManagement.connect(user).makeRequest(recycler.address, "Plastic", 15, ethers.parseEther("7.5"));

            // Register the collector and set them as available
            await wasteManagement.connect(collector).createCollector(collector.address); // Ensure collector is registered

            await wasteManagement.connect(recycler).acceptRequest(1, collector.address);

            // Simulate confirming the collection
            await wasteManagement.connect(collector).confirmRequest(1);

            const request = await wasteManagement.collectionRequests(1);
            expect(request.isCompleted).to.be.true;
        });

        it("should allow cancellation of requests by authorized parties only", async function () {
            const { wasteManagement, user, recycler } = await loadFixture(deployFixture);
            await wasteManagement.connect(user).createUser();
            await wasteManagement.connect(recycler).createRecycler(recycler.address, "Location A", 5);
            await wasteManagement.connect(recycler).createOffer("Plastic", ethers.parseEther("0.5"), 10);
            await wasteManagement.connect(user).makeRequest(recycler.address, "Plastic", 15, ethers.parseEther("7.5"));

            // Only recycler or assigned collector can cancel
            await expect(wasteManagement.connect(user).cancelRequestAndRefund(1)).to.be.revertedWithCustomError(wasteManagement, "NOT_AUTHORIZED");

            // Recycler cancels the request
            await wasteManagement.connect(recycler).cancelRequestAndRefund(1);

            const request = await wasteManagement.collectionRequests(1);
            expect(request.isCompleted).to.be.true;
        });
    });

//     // describe("Fuzz Testing Collection Requests", function () {
//     //     it("should handle random weight inputs for collection requests correctly", async function () {
//     //       const {wasteManagement,user,recycler} = await loadFixture(deployFixture);

//     //       // Register user and recycler
//     //       await wasteManagement.connect(user).createUser();
//     //       await wasteManagement.connect(recycler).createRecycler(recycler.address,"Location A",5);

//     //       // Create an offer with minimum quantity of 10 kg
//     //       const minQuantity = 10;
//     //       const pricePerKg = ethers.parseEther('0.5');
//     //       await wasteManagement.connect(recycler).createOffer("Plastic",pricePerKg,minQuantity);

//     //       for (let i = 0; i < 10; i++) {
//     //           // Generate random weight between 1 and 20 kg
//     //           const randomWeight = Math.floor(Math.random() * (20 - 1 + 1)) + 1;

//     //           if (randomWeight < minQuantity) {
//     //               // Expect failure for weights below minimum quantity
//     //               await expect(
//     //                   wasteManagement.connect(user).makeRequest(
//     //                       recycler.address,
//     //                       "Plastic",
//     //                       randomWeight,
//     //                       ethers.parseEther((randomWeight * Number(pricePerKg)).toString())
//     //                   )
//     //               ).to.be.revertedWithCustomError(wasteManagement, 'LOWER_THAN_MINQUANTITY');
//     //           } else {
//     //               // Expect success for valid weights
//     //               let txResponse = await (await wasteManagement.connect(user)
//     //                   .makeRequest(
//     //                       recycler.address,
//     //                       "Plastic",
//     //                       randomWeight,
//     //                       ethers.parseEther((randomWeight * Number(pricePerKg)).toString())
//     //                   ) ).wait();

//     //                   console.log(txResponse);

//     //               let requestEvent=txResponse.events?.find((event: any) => event.event === 'RequestCreated');
//     //               console.log("Request Event", requestEvent);
//     //               expect(requestEvent?.args?.userAddress).to.equal(user.address); 
//     //               expect(requestEvent?.args?.recyclerAddress).to.equal(recycler.address); 
//     //               expect(requestEvent?.args?.weight).to.equal(randomWeight); 
//     //           }
//     //       }
//     //   });
//   });
});