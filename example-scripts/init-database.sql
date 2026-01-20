-- Bepoz POS Database Initialization Script
-- Description: Creates initial database schema and tables
-- Type: SQL
-- Category: SQL Scripts
-- Parameters: ServerName, DatabaseName

USE master
GO

-- Create database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BepozPOS')
BEGIN
    PRINT 'Creating database BepozPOS...'
    CREATE DATABASE BepozPOS
    PRINT 'Database created successfully'
END
ELSE
BEGIN
    PRINT 'Database BepozPOS already exists'
END
GO

USE BepozPOS
GO

-- Create Products table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Products')
BEGIN
    PRINT 'Creating Products table...'
    CREATE TABLE Products (
        ProductID INT PRIMARY KEY IDENTITY(1,1),
        ProductName NVARCHAR(100) NOT NULL,
        SKU NVARCHAR(50) UNIQUE NOT NULL,
        Description NVARCHAR(500),
        CategoryID INT,
        Price DECIMAL(10,2) NOT NULL,
        Cost DECIMAL(10,2),
        StockQuantity INT DEFAULT 0,
        MinStockLevel INT DEFAULT 0,
        IsActive BIT DEFAULT 1,
        CreatedDate DATETIME DEFAULT GETDATE(),
        ModifiedDate DATETIME DEFAULT GETDATE()
    )
    PRINT 'Products table created'
END
GO

-- Create Categories table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Categories')
BEGIN
    PRINT 'Creating Categories table...'
    CREATE TABLE Categories (
        CategoryID INT PRIMARY KEY IDENTITY(1,1),
        CategoryName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(500),
        ParentCategoryID INT NULL,
        IsActive BIT DEFAULT 1,
        CreatedDate DATETIME DEFAULT GETDATE()
    )
    PRINT 'Categories table created'
END
GO

-- Create Customers table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Customers')
BEGIN
    PRINT 'Creating Customers table...'
    CREATE TABLE Customers (
        CustomerID INT PRIMARY KEY IDENTITY(1,1),
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        Email NVARCHAR(100),
        Phone NVARCHAR(20),
        Address NVARCHAR(200),
        City NVARCHAR(50),
        State NVARCHAR(50),
        ZipCode NVARCHAR(20),
        LoyaltyPoints INT DEFAULT 0,
        IsActive BIT DEFAULT 1,
        CreatedDate DATETIME DEFAULT GETDATE(),
        ModifiedDate DATETIME DEFAULT GETDATE()
    )
    PRINT 'Customers table created'
END
GO

-- Create Employees table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Employees')
BEGIN
    PRINT 'Creating Employees table...'
    CREATE TABLE Employees (
        EmployeeID INT PRIMARY KEY IDENTITY(1,1),
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        Username NVARCHAR(50) UNIQUE NOT NULL,
        PasswordHash NVARCHAR(256) NOT NULL,
        Email NVARCHAR(100),
        Phone NVARCHAR(20),
        Role NVARCHAR(50) NOT NULL,
        HireDate DATE,
        IsActive BIT DEFAULT 1,
        CreatedDate DATETIME DEFAULT GETDATE(),
        ModifiedDate DATETIME DEFAULT GETDATE()
    )
    PRINT 'Employees table created'
END
GO

-- Create Transactions table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Transactions')
BEGIN
    PRINT 'Creating Transactions table...'
    CREATE TABLE Transactions (
        TransactionID INT PRIMARY KEY IDENTITY(1,1),
        TransactionNumber NVARCHAR(50) UNIQUE NOT NULL,
        TransactionDate DATETIME DEFAULT GETDATE(),
        CustomerID INT,
        EmployeeID INT NOT NULL,
        SubTotal DECIMAL(10,2) NOT NULL,
        TaxAmount DECIMAL(10,2) NOT NULL,
        DiscountAmount DECIMAL(10,2) DEFAULT 0,
        TotalAmount DECIMAL(10,2) NOT NULL,
        PaymentMethod NVARCHAR(50),
        Status NVARCHAR(20) DEFAULT 'Completed',
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
        FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
    )
    PRINT 'Transactions table created'
END
GO

-- Create TransactionItems table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TransactionItems')
BEGIN
    PRINT 'Creating TransactionItems table...'
    CREATE TABLE TransactionItems (
        TransactionItemID INT PRIMARY KEY IDENTITY(1,1),
        TransactionID INT NOT NULL,
        ProductID INT NOT NULL,
        Quantity INT NOT NULL,
        UnitPrice DECIMAL(10,2) NOT NULL,
        Discount DECIMAL(10,2) DEFAULT 0,
        LineTotal DECIMAL(10,2) NOT NULL,
        FOREIGN KEY (TransactionID) REFERENCES Transactions(TransactionID),
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
    )
    PRINT 'TransactionItems table created'
END
GO

-- Create Inventory table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Inventory')
BEGIN
    PRINT 'Creating Inventory table...'
    CREATE TABLE Inventory (
        InventoryID INT PRIMARY KEY IDENTITY(1,1),
        ProductID INT NOT NULL,
        TransactionType NVARCHAR(20) NOT NULL, -- 'IN', 'OUT', 'ADJUSTMENT'
        Quantity INT NOT NULL,
        EmployeeID INT NOT NULL,
        Notes NVARCHAR(500),
        TransactionDate DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
        FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
    )
    PRINT 'Inventory table created'
END
GO

-- Add foreign key constraint to Products table
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Products_Categories')
BEGIN
    ALTER TABLE Products
    ADD CONSTRAINT FK_Products_Categories
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID)
    PRINT 'Foreign key constraint added to Products table'
END
GO

-- Create default admin user (password: admin123)
IF NOT EXISTS (SELECT * FROM Employees WHERE Username = 'admin')
BEGIN
    PRINT 'Creating default admin user...'
    INSERT INTO Employees (FirstName, LastName, Username, PasswordHash, Role, HireDate, IsActive)
    VALUES ('System', 'Administrator', 'admin',
            'EF92B778BAFE771E89245B89ECBC08A44A4E166C06659911881F383D4473E94F', -- SHA256 of 'admin123'
            'Administrator', GETDATE(), 1)
    PRINT 'Default admin user created (username: admin, password: admin123)'
    PRINT 'WARNING: Please change the default password after first login!'
END
GO

-- Create default categories
IF NOT EXISTS (SELECT * FROM Categories WHERE CategoryName = 'Food')
BEGIN
    PRINT 'Creating default categories...'
    INSERT INTO Categories (CategoryName, Description) VALUES
    ('Food', 'Food items and ingredients'),
    ('Beverages', 'Drinks and beverage products'),
    ('Merchandise', 'Retail merchandise and products'),
    ('Services', 'Service items')
    PRINT 'Default categories created'
END
GO

-- Create indexes for performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_SKU')
BEGIN
    CREATE INDEX IX_Products_SKU ON Products(SKU)
    PRINT 'Index created on Products.SKU'
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Transactions_Date')
BEGIN
    CREATE INDEX IX_Transactions_Date ON Transactions(TransactionDate)
    PRINT 'Index created on Transactions.TransactionDate'
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Customers_Email')
BEGIN
    CREATE INDEX IX_Customers_Email ON Customers(Email)
    PRINT 'Index created on Customers.Email'
END
GO

PRINT ''
PRINT '========================================'
PRINT 'Database initialization completed!'
PRINT '========================================'
PRINT 'Database: BepozPOS'
PRINT 'Tables created: 8'
PRINT 'Default admin: admin/admin123'
PRINT ''
PRINT 'IMPORTANT: Change default password!'
PRINT '========================================'
GO
