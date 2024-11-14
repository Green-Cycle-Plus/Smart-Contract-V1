// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ErrorLib.sol";
import "./CategoryLib.sol";

/**
 * @title ProductLib
 * @dev Library for managing products in tthe marketplace, including adding, updating, and retrieving product data.
 */
library ProductLib {
    using CategoryLib for CategoryLib.CategoryStorage;

    struct Product {
        uint id;
        uint categoryId;
        uint price;
        uint quantity;
        address recycler;
        bool isActive;
        string ipfsHash; // Off-chain storage for Name/descriptions/images
    }

    struct ProductStorage {
        mapping(uint => Product) products;
        mapping(address => uint[]) recyclerProducts;
        uint productCount;
    }

    event ProductListed(
        uint indexed productId,
        address indexed recycler,
        uint _categoryId,
        uint _price,
        uint _quantity,
        string _ipfsHash
    );

    event ProductUpdated(
        uint indexed productId,
        address indexed recycler,
        uint _categoryId,
        uint _price,
        uint _quantity,
        string _ipfsHash
    );

    /**
     * @notice Adds a new product to the marketplace.
     * @dev Creates a new product with specified attributes and stores it in the ProductStorage.
     *      Reverts if quantity or price is zero, or if IPFS hash is invalid.
     * @param self Reference to ProductStorage.
     * @param _categoryId ID of the category the product belongs to.
     * @param _price Price of the product.
     * @param _quantity Quantity of the product in stock.
     * @param _ipfsHash IPFS hash storing the product's name, description, and image data.
     */
    function addProduct(
        ProductStorage storage self,
        uint _categoryId,
        uint _price,
        uint _quantity,
        string memory _ipfsHash //Contains IPFS Hash of Name/description/image etc
    ) internal {
        if (_quantity == 0) revert ErrorLib.InvalidQuanity();
        if (_price == 0) revert ErrorLib.InvalidPrice();
        if (bytes(_ipfsHash).length == 0) revert ErrorLib.InvalidIpfsHash();

        self.productCount++;
        self.products[self.productCount] = Product({
            id: self.productCount,
            categoryId: _categoryId,
            price: _price,
            quantity: _quantity,
            recycler: msg.sender,
            isActive: true,
            ipfsHash: _ipfsHash
        });

        self.recyclerProducts[msg.sender].push(self.productCount);
        emit ProductListed(
            self.productCount,
            msg.sender,
            _categoryId,
            _price,
            _quantity,
            _ipfsHash
        );
    }

    /**
     * @notice Updates an existing product's details.
     * @dev Allows updating price, quantity, and IPFS hash. Reverts if the product is inactive,
     *      or if quantity or price is zero.
     * @param self Reference to ProductStorage.
     * @param _productId ID of the product to update.
     * @param _price New price for the product.
     * @param _quantity New quantity for the product.
     * @param _ipfsHash New IPFS hash for updated product details.
     */
    function updateProduct(
        ProductStorage storage self,
        uint _productId,
        uint _price,
        uint _quantity,
        string memory _ipfsHash
    ) internal {
        Product storage product = self.products[_productId];
        if (!product.isActive) revert ErrorLib.InactiveProduct();
        if (_quantity == 0) revert ErrorLib.InvalidQuanity();
        if (_price == 0) revert ErrorLib.InvalidPrice();

        product.price = _price;
        product.quantity = _quantity;
        product.ipfsHash = _ipfsHash;

        emit ProductUpdated(
            _productId,
            msg.sender,
            product.categoryId,
            _price,
            _quantity,
            _ipfsHash
        );
    }

    /**
     * @notice Retrieves product details for a given product ID.
     * @dev Returns the product details if it is active. Reverts if the product is inactive.
     * @param self Reference to ProductStorage.
     * @param _productId ID of the product to retrieve.
     * @return Product struct containing the product's details.
     */
    function getProduct(
        ProductStorage storage self,
        uint _productId
    ) internal view returns (Product memory) {
        Product storage product = self.products[_productId];
        if (!product.isActive) revert ErrorLib.InactiveProduct();
        return product;
    }

    /**
     * @notice Retrieves all product IDs listed by a specific recycler.
     * @param self Reference to ProductStorage.
     * @param _recycler Address of the recycler whose products are being retrieved.
     * @return An array of product IDs listed by the recycler.
     */
    function getAllrecyclerProducts(
        ProductStorage storage self,
        address _recycler
    ) internal view returns (uint[] memory) {
        return self.recyclerProducts[_recycler];
    }

    /**
     * @notice Retrieves the total number of products added to the marketplace.
     * @param self Reference to ProductStorage.
     * @return productCount Total count of products in the marketplace.
     */
    function getProductCount(
        ProductStorage storage self
    ) internal view returns (uint) {
        return self.productCount;
    }
}
