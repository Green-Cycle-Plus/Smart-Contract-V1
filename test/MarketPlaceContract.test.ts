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
    
  
    console.log("CategoryLib deployed to:", categoryLib.target.toString()); // Check the address
  
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
    it("should allow a user to purchase a product", async function () {
      const { owner, recycler, buyer, escrow, marketplace } = await loadFixture(deployMarketPlace);

      await marketplace.connect(owner).addCategory("Electronics");
      await marketplace.connect(recycler).listProduct(0, ethers.parseEther("1"), 100, "Qm1234abcd");

      await expect(
        marketplace.connect(buyer).purchaseProduct(1, 2, { value: ethers.parseEther("2") })
      )
        .to.emit(marketplace, "ProductPurchased")
        .withArgs(1, buyer.address, 1);
      
      const order = await marketplace.getOrder(1);
    
      expect(order.quantity).to.equal(2);
      expect(order.totalAmount).to.equal(ethers.parseEther("2"));
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
        
        const provider = ethers.provider;
        const balance = await provider.getBalance(escrow);
  
        const etherBalance = ethers.formatEther(balance);
        console.log(`Escrow Contract balance: ${etherBalance} ETH`);
  
      const order = await marketplace.getOrder(1);
      expect(prod.quantity).to.equal(98);
      expect(order.quantity).to.equal(2);
      expect(order.totalAmount).to.equal(ethers.parseEther("2"));
    });


  });

  

});
