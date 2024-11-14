// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ErrorLib.sol";

/**
 * @title CategoryLib
 * @dev Library for managing categories in the marketplace.
 */

library CategoryLib {
    struct Category {
        uint id;
        string name;
    }

    struct CategoryStorage {
        mapping(uint => Category) categories;
        uint[] categoryIds;
        uint totalCategory;
    }

    event CategoryAdded(uint indexed categoryId, string name);
    event CategoryUpdated(uint indexed categoryId, string name);

    /**
     * @notice Creates a new category with a given name.
     * @dev Reverts if the category name is empty.
     * @param self Reference to CategoryStorage.
     * @param _name Name of the category to create.
     */
    function createCategory(
        CategoryStorage storage self,
        string memory _name
    ) internal {
        if (bytes(_name).length == 0) {
            revert ErrorLib.InvalidCategoryName();
        }
        uint categoryId = self.totalCategory++;
        self.categories[categoryId] = Category(categoryId, _name);
        self.categoryIds.push(categoryId);
        emit CategoryAdded(categoryId, _name);
    }

    /**
     * @notice Retrieves all categories.
     * @param self Reference to CategoryStorage.
     * @return Array of all Category structs in the marketplace.
     */
    function getCategories(
        CategoryStorage storage self
    ) external view returns (Category[] memory) {
        Category[] memory result = new Category[](self.categoryIds.length);
        for (uint i = 0; i < self.categoryIds.length; i++) {
            result[i] = self.categories[self.categoryIds[i]];
        }
        return result;
    }

    /**
     * @notice Updates the name of an existing category.
     * @dev Reverts if the category with the given ID does not exist.
     * @param self Reference to CategoryStorage.
     * @param _categoryId ID of the category to update.
     * @param _name New name for the category.
     */
    function updateCategory(
        CategoryStorage storage self,
        uint _categoryId,
        string memory _name
    ) internal {
        Category storage category = self.categories[_categoryId];
        if (category.id != _categoryId) revert ErrorLib.CategoryNotFound();
        category.name = _name;
        emit CategoryUpdated(_categoryId, _name);
    }

    /**
     * @notice Retrieves a single category by its ID.
     * @dev Reverts if the category with the given ID does not exist.
     * @param self Reference to CategoryStorage.
     * @param _categoryId ID of the category to retrieve.
     * @return Tuple containing the ID and name of the category.
     */
    function getCategory(
        CategoryStorage storage self,
        uint _categoryId
    ) internal view returns (uint, string memory) {
        Category storage category = self.categories[_categoryId];
        if (category.id != _categoryId) revert ErrorLib.CategoryNotFound();
        return (category.id, category.name);
    }
}
