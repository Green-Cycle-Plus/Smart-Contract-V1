import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

describe("MarketPlaceContract", function () {
  let marketplace, escrow, owner, recycler, buyer;
  

  async function deployMarketPlace() {
    const [owner, recycler, buyer] = await ethers.getSigners();
  
    // Deploy the Escrow mock contract
    const EscrowMock = await ethers.getContractFactory("EscrowContract");
    const escrow = await EscrowMock.deploy();
  
  
    // Deploy the CategoryLib library and wait for it to be fully deployed
    const CategoryLib = await ethers.getContractFactory("CategoryLib");
    const categoryLib = await CategoryLib.deploy();
    
  
    // console.log("CategoryLib deployed to:", categoryLib.target.toString()); // Check the address
  
    // Deploy the MarketPlaceContract with the linked library and wrap the address in an array
    const MarketPlaceContract = await ethers.getContractFactory("MarketPlaceContract", {
      libraries: {
        CategoryLib: categoryLib.target, // Use the correct address
      },
    });
  
    // Wrap `escrow.address` in an array as deploy expects an array of arguments
    const marketplace = await MarketPlaceContract.deploy(escrow.getAddress());
  
    // Onboard a recycler
    await marketplace.connect(owner).onboardRecycler(recycler.address);
  
    return { owner, recycler, buyer, escrow, marketplace };
  }

  describe("Category Management", function () {

    it("Should not allow non-owner to add a category", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      await expect(marketplace.connect(recycler).addCategory("Invalid"))
        .to.be.revertedWith("Unauthorized");
    });

    it("Should not allow owner to add a category with empty name", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      await expect(marketplace.connect(owner).addCategory(""))
        .to.be.revertedWithCustomError(marketplace, "InvalidCategoryName");
    });

    it("Should allow anyone to retrieve category list", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      const categories = await marketplace.connect(buyer).getCategories();
      expect(categories).to.be.an("array");
    });

    it("Should revert if a non-existent category is requested", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      await expect(marketplace.connect(owner).getCategory("999"))
        .to.be.revertedWithCustomError(marketplace, "CategoryNotFound");
    });

    it('It Should Create new Category', async function() {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      const tx = await marketplace.connect(owner).addCategory("Glass");
      tx.wait();

      const tx2 = await marketplace.connect(owner).addCategory("Glassw");
      tx2.wait();

      const categories = await marketplace.getCategories();
      expect(categories.length).equal(2);
    });

    it('It Should Update a Category', async function() {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      const tx = await marketplace.connect(owner).addCategory("Glass");
      tx.wait();

      const tx2 = await marketplace.connect(owner).addCategory("Glassw");
      tx2.wait();

      const tx3 = await marketplace.connect(owner).updateCategory(0, "New Category");
      tx3.wait();

      const cat = await marketplace.connect(owner).getCategory(0);


      expect(cat[1]).equal("New Category");
    })
  });

  describe("Product Management", function(){

    it("Should revert if unauthorized recycler tries to list a product", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      await expect(
        marketplace.connect(buyer).listProduct(1, ethers.parseEther("1"), 10, "ipfsHash")
      ).to.be.revertedWith("UnauthorizedRecycler");
    });

    it("Should revert if product is listed under a non-existent category", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await expect(
        marketplace.connect(recycler).listProduct("999", ethers.parseEther("1"), 10, "ipfsHash")
      ).to.be.revertedWithCustomError(marketplace, "CategoryNotFound");
    });

    it("Should allow recycler to update product price and quantity", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      const tx = await marketplace.connect(owner).addCategory("Glass");
      tx.wait();
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 10, "ipfsHash");
      await marketplace.connect(recycler).updateProduct(1, ethers.parseEther("0.8"), 15, "newIpfsHash");
      const product = await marketplace.getProduct(1);
      expect(product.price).to.equal(ethers.parseEther("0.8"));
      expect(product.quantity).to.equal(15);
    });

    it("Should revert if a non-owner tries to update the product", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);
      const tx = await marketplace.connect(owner).addCategory("Glass");
      tx.wait();
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 10, "ipfsHash");
      await expect(
        marketplace.connect(buyer).updateProduct(1, ethers.parseEther("2"), 5, "newIpfsHash")
      ).to.be.revertedWith("Only the product owner (recycler) can perform this action");
    });

    
    it("should allow recycler add product successfully", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(0, ethers.parseEther("0.1"), 5, "ipfsHash1");
      await marketplace.connect(recycler).listProduct(0, ethers.parseEther("0.1"), 5, "ipfsHash2");

      const prods = await marketplace.connect(buyer).getProductCount();
      expect(prods).to.equal(2);
    });

    it("should not allow unauthorized recycler to list a product", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await expect(marketplace.connect(buyer).listProduct(0, ethers.parseEther("0.1"), 5, "ipfsHash1")).to.be.revertedWith("UnauthorizedRecycler");
    });

    it("should allow only the product owner to update the product", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(0, ethers.parseEther("1"), 100, "Qm1234abcd");

      await expect(
        marketplace.connect(recycler).updateProduct(1, ethers.parseEther("2"), 80, "Qm5678efgh")
      )
        .to.emit(marketplace, "ProductUpdated")
        .withArgs(1, recycler, 0, ethers.parseEther("2"), 80, "Qm5678efgh");
      await expect(marketplace.connect(buyer).updateProduct(1, ethers.parseEther("1.5"), 90, "Qm1234abcd"))
        .to.be.revertedWith("Only the product owner (recycler) can perform this action");
    });

  });

  describe('Order Processing', function(){
    it("Should revert if purchase amount is insufficient", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");
      await expect(
        marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("0.1") })
      ).to.be.revertedWithCustomError(marketplace, "InsufficientEther");
    });

    it("Should revert if buyer sends excess amount", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");
      await expect(
        marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("2") })
      ).to.be.revertedWithCustomError(marketplace, "PayingExcess");
    });

    it("Should decrease product quantity upon successful purchase", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");

      await marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("1") });
      const product = await marketplace.getProduct(1);
      expect(product.quantity).to.equal(99);
    });

    it("Should revert if attempting to purchase out-of-stock product", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");

      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 4, "ipfsHash");
      await expect(
        marketplace.connect(buyer).purchaseProduct(1, 5, { value: ethers.parseEther("5") })
      ).to.be.revertedWithCustomError(marketplace, "ProductQuantityExceeded");
    });

    it("should allow a user to purchase a product", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");

      await expect(
        marketplace.connect(buyer).purchaseProduct(1, 2, { value: ethers.parseEther("2") })
      )
        .to.emit(marketplace, "ProductPurchased")
        .withArgs(1, buyer.address, 1);
      
      const order = await marketplace.getOrder(1);
    
      expect(order.quantity).to.equal(2);
      expect(order.totalAmount).to.equal(ethers.parseEther("2"));
    });


    it("Should allow buyer to cancel an order in processing", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");

      await marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("1") });
      await marketplace.connect(buyer).cancelOrder(1);
      const order = await marketplace.getOrder(1);
      expect(order.status).to.equal(3); 
    });

    it("Should revert if a non-buyer tries to cancel the order", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");

      await marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("1") });
      await expect(
        marketplace.connect(owner).cancelOrder(1)
      ).to.be.revertedWithCustomError(marketplace, "UnauthorizedToCancel");
    });

    it("Should revert if trying to confirm an order not in processing state", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");

      await marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("1") });
      await marketplace.connect(buyer).cancelOrder(1);
      await expect(
        marketplace.connect(buyer).confirmDelivery(1)
      ).to.be.revertedWithCustomError(marketplace, "CannotCancelOrder");
    });

    it("Should revert if non-buyer tries to confirm delivery", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("1"), 100, "Qm1234abcd");

      await marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("1") });
      await expect(
        marketplace.connect(recycler).confirmDelivery(1)
      ).to.be.revertedWithCustomError(marketplace, "OnlyBuyer");
    });




    it("should allow only buyer cancel Order", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(0, ethers.parseEther("1"), 100, "Qm1234abcd");

      await expect(
        marketplace.connect(buyer).purchaseProduct(1, 2, { value: ethers.parseEther("2") })
      )
        .to.emit(marketplace, "ProductPurchased")
        .withArgs(1, buyer.address, 1);
      
        await expect(
          marketplace.connect(buyer).cancelOrder(1)
        )
          .to.emit(marketplace, "OrderCancelled")
          .withArgs(1, buyer.address, "Buyer cancelled the order");

        const prod = await marketplace.connect(buyer).getProduct(1);
        
  
      const order = await marketplace.getOrder(1);
      expect(prod.quantity).to.equal(100);
      expect(order.quantity).to.equal(2);
      expect(order.totalAmount).to.equal(ethers.parseEther("2"));
    });


    it("should allow only buyer confirm Order", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(0, ethers.parseEther("1"), 100, "Qm1234abcd");

      await expect(
        marketplace.connect(buyer).purchaseProduct(1, 2, { value: ethers.parseEther("2") })
      )
        .to.emit(marketplace, "ProductPurchased")
        .withArgs(1, buyer.address, 1);
      
        await expect(
          marketplace.connect(buyer).confirmDelivery(1)
        )
          .to.emit(marketplace, "OrderDelivered")
          .withArgs(1);

        const prod = await marketplace.connect(buyer).getProduct(1);
        
        // const provider = ethers.provider;
        // const balance = await provider.getBalance(escrow);
  
        // const etherBalance = ethers.formatEther(balance);
        // console.log(`Escrow Contract balance: ${etherBalance} ETH`);
  
      const order = await marketplace.getOrder(1);
      expect(prod.quantity).to.equal(98);
      expect(order.quantity).to.equal(2);
      expect(order.totalAmount).to.equal(ethers.parseEther("2"));
    });


  });

  describe("Escrow Interaction", function () {
    it("Should have the escrow contract balance updated correctly after purchase", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Furniture");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("2"), 5, "ipfsHash");

      await marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("2") });

      const escrowBalance = await ethers.provider.getBalance(escrow.target);
      expect(escrowBalance).to.equal(ethers.parseEther("2"));
    });

    it("Should release funds from escrow upon successful order completion", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Furniture");
      await marketplace.connect(recycler).listProduct(1, ethers.parseEther("2"), 5, "ipfsHash");

      await marketplace.connect(buyer).purchaseProduct(1, 1, { value: ethers.parseEther("2") });
      await marketplace.connect(buyer).confirmDelivery(1);

      const escrowBalance = await ethers.provider.getBalance(escrow.target);
      expect(escrowBalance).to.equal(ethers.parseEther("0"));
    });
  });

  

});
