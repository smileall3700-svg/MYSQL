-- ============================================================
-- STORE MANAGEMENT SYSTEM — MySQL Schema
-- ============================================================
-- Covers: inventory control, purchasing, sales tracking,
-- customers, employees, and reporting views for a dashboard.
-- Target: MySQL 8.0+
-- ============================================================

DROP DATABASE IF EXISTS store_management;
CREATE DATABASE store_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE store_management;

-- ------------------------------------------------------------
-- 1. CATEGORIES
-- ------------------------------------------------------------
CREATE TABLE categories (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE,
    description   VARCHAR(255)
);

-- ------------------------------------------------------------
-- 2. SUPPLIERS
-- ------------------------------------------------------------
CREATE TABLE suppliers (
    supplier_id     INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    contact_person  VARCHAR(100),
    phone           VARCHAR(20),
    email           VARCHAR(100),
    address         VARCHAR(255),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- 3. EMPLOYEES
-- ------------------------------------------------------------
CREATE TABLE employees (
    employee_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    role          ENUM('manager','cashier','stock_clerk','admin') NOT NULL DEFAULT 'cashier',
    phone         VARCHAR(20),
    email         VARCHAR(100) UNIQUE,
    hire_date     DATE NOT NULL,
    status        ENUM('active','inactive') NOT NULL DEFAULT 'active'
);

-- ------------------------------------------------------------
-- 4. CUSTOMERS
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id     INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    phone           VARCHAR(20),
    email           VARCHAR(100),
    loyalty_points  INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- 5. PRODUCTS
-- ------------------------------------------------------------
CREATE TABLE products (
    product_id        INT AUTO_INCREMENT PRIMARY KEY,
    sku               VARCHAR(30) NOT NULL UNIQUE,
    name              VARCHAR(150) NOT NULL,
    category_id       INT,
    supplier_id       INT,
    cost_price        DECIMAL(10,2) NOT NULL DEFAULT 0,
    selling_price     DECIMAL(10,2) NOT NULL DEFAULT 0,
    quantity_in_stock INT NOT NULL DEFAULT 0,
    reorder_level     INT NOT NULL DEFAULT 10,
    unit              VARCHAR(20) DEFAULT 'pcs',
    is_active         TINYINT(1) NOT NULL DEFAULT 1,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE SET NULL,
    INDEX idx_products_category (category_id),
    INDEX idx_products_stock (quantity_in_stock)
);

-- ------------------------------------------------------------
-- 6. SALES (header)
-- ------------------------------------------------------------
CREATE TABLE sales (
    sale_id         INT AUTO_INCREMENT PRIMARY KEY,
    customer_id     INT NULL,
    employee_id     INT NOT NULL,
    sale_date       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal        DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount        DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax             DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_amount    DECIMAL(12,2) NOT NULL DEFAULT 0,
    payment_method  ENUM('cash','card','upi','wallet','other') NOT NULL DEFAULT 'cash',
    status          ENUM('completed','refunded','void') NOT NULL DEFAULT 'completed',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE SET NULL,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    INDEX idx_sales_date (sale_date)
);

-- ------------------------------------------------------------
-- 7. SALE ITEMS (line items)
-- ------------------------------------------------------------
CREATE TABLE sale_items (
    sale_item_id  INT AUTO_INCREMENT PRIMARY KEY,
    sale_id       INT NOT NULL,
    product_id    INT NOT NULL,
    quantity      INT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    subtotal      DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    FOREIGN KEY (sale_id) REFERENCES sales(sale_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_sale_items_product (product_id)
);

-- ------------------------------------------------------------
-- 8. PURCHASE ORDERS (restocking from suppliers)
-- ------------------------------------------------------------
CREATE TABLE purchase_orders (
    po_id           INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id     INT NOT NULL,
    employee_id     INT NOT NULL,
    order_date      DATE NOT NULL DEFAULT (CURRENT_DATE),
    expected_date   DATE,
    status          ENUM('pending','received','cancelled') NOT NULL DEFAULT 'pending',
    total_amount    DECIMAL(12,2) NOT NULL DEFAULT 0,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

CREATE TABLE purchase_order_items (
    po_item_id   INT AUTO_INCREMENT PRIMARY KEY,
    po_id        INT NOT NULL,
    product_id   INT NOT NULL,
    quantity     INT NOT NULL,
    unit_cost    DECIMAL(10,2) NOT NULL,
    subtotal     DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ------------------------------------------------------------
-- 9. INVENTORY TRANSACTIONS (audit trail of every stock move)
-- ------------------------------------------------------------
CREATE TABLE inventory_transactions (
    transaction_id    INT AUTO_INCREMENT PRIMARY KEY,
    product_id        INT NOT NULL,
    change_qty        INT NOT NULL,              -- negative = stock out, positive = stock in
    transaction_type  ENUM('sale','purchase','adjustment','return') NOT NULL,
    reference_id      INT,                        -- sale_id or po_id depending on type
    transaction_date  DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes             VARCHAR(255),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_inv_txn_product (product_id),
    INDEX idx_inv_txn_date (transaction_date)
);

-- ============================================================
-- TRIGGERS — keep stock levels correct automatically
-- ============================================================
DELIMITER $$

-- Deduct stock + log transaction whenever a sale line item is added
CREATE TRIGGER trg_sale_item_after_insert
AFTER INSERT ON sale_items
FOR EACH ROW
BEGIN
    UPDATE products
    SET quantity_in_stock = quantity_in_stock - NEW.quantity
    WHERE product_id = NEW.product_id;

    INSERT INTO inventory_transactions (product_id, change_qty, transaction_type, reference_id, notes)
    VALUES (NEW.product_id, -NEW.quantity, 'sale', NEW.sale_id, 'Auto-logged from sale_items');
END$$

-- Restore stock if a sale item is deleted (e.g. line correction)
CREATE TRIGGER trg_sale_item_after_delete
AFTER DELETE ON sale_items
FOR EACH ROW
BEGIN
    UPDATE products
    SET quantity_in_stock = quantity_in_stock + OLD.quantity
    WHERE product_id = OLD.product_id;

    INSERT INTO inventory_transactions (product_id, change_qty, transaction_type, reference_id, notes)
    VALUES (OLD.product_id, OLD.quantity, 'adjustment', OLD.sale_id, 'Reversal from deleted sale_item');
END$$

-- Add stock + log transaction whenever a purchase order line item is received
CREATE TRIGGER trg_po_item_after_insert
AFTER INSERT ON purchase_order_items
FOR EACH ROW
BEGIN
    UPDATE products
    SET quantity_in_stock = quantity_in_stock + NEW.quantity
    WHERE product_id = NEW.product_id;

    INSERT INTO inventory_transactions (product_id, change_qty, transaction_type, reference_id, notes)
    VALUES (NEW.product_id, NEW.quantity, 'purchase', NEW.po_id, 'Auto-logged from purchase_order_items');
END$$

-- Keep sales.total_amount in sync with its line items
CREATE TRIGGER trg_sale_totals_after_insert
AFTER INSERT ON sale_items
FOR EACH ROW
BEGIN
    UPDATE sales s
    SET subtotal = (SELECT COALESCE(SUM(subtotal),0) FROM sale_items WHERE sale_id = NEW.sale_id),
        total_amount = (SELECT COALESCE(SUM(subtotal),0) FROM sale_items WHERE sale_id = NEW.sale_id) - s.discount + s.tax
    WHERE s.sale_id = NEW.sale_id;
END$$

-- Keep purchase_orders.total_amount in sync with its line items
CREATE TRIGGER trg_po_totals_after_insert
AFTER INSERT ON purchase_order_items
FOR EACH ROW
BEGIN
    UPDATE purchase_orders
    SET total_amount = (SELECT COALESCE(SUM(subtotal),0) FROM purchase_order_items WHERE po_id = NEW.po_id)
    WHERE po_id = NEW.po_id;
END$$

DELIMITER ;

-- ============================================================
-- STORED PROCEDURE — safe way to record a sale line and stop
-- overselling (checks stock before the trigger fires)
-- ============================================================
DELIMITER $$
CREATE PROCEDURE sp_add_sale_item(
    IN p_sale_id INT,
    IN p_product_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_price DECIMAL(10,2);

    SELECT quantity_in_stock, selling_price INTO v_stock, v_price
    FROM products WHERE product_id = p_product_id FOR UPDATE;

    IF v_stock < p_quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for this product';
    ELSE
        INSERT INTO sale_items (sale_id, product_id, quantity, unit_price)
        VALUES (p_sale_id, p_product_id, p_quantity, v_price);
    END IF;
END$$
DELIMITER ;

-- ============================================================
-- VIEWS — power the dashboard directly
-- ============================================================

-- Products at or below their reorder point
CREATE VIEW view_low_stock AS
SELECT p.product_id, p.sku, p.name, c.name AS category,
       p.quantity_in_stock, p.reorder_level, s.name AS supplier
FROM products p
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN suppliers s ON s.supplier_id = p.supplier_id
WHERE p.quantity_in_stock <= p.reorder_level AND p.is_active = 1;

-- Revenue per day
CREATE VIEW view_daily_sales AS
SELECT DATE(sale_date) AS sale_day,
       COUNT(DISTINCT sale_id) AS orders,
       SUM(total_amount) AS revenue
FROM sales
WHERE status = 'completed'
GROUP BY DATE(sale_date);

-- Best selling products (by quantity and revenue)
CREATE VIEW view_top_products AS
SELECT p.product_id, p.name, p.sku,
       SUM(si.quantity) AS units_sold,
       SUM(si.subtotal) AS revenue
FROM sale_items si
JOIN products p ON p.product_id = si.product_id
JOIN sales s ON s.sale_id = si.sale_id AND s.status = 'completed'
GROUP BY p.product_id, p.name, p.sku
ORDER BY revenue DESC;

-- Revenue by category
CREATE VIEW view_sales_by_category AS
SELECT c.name AS category, SUM(si.subtotal) AS revenue, SUM(si.quantity) AS units_sold
FROM sale_items si
JOIN products p ON p.product_id = si.product_id
JOIN categories c ON c.category_id = p.category_id
JOIN sales s ON s.sale_id = si.sale_id AND s.status = 'completed'
GROUP BY c.name;

-- Simple inventory valuation (cost basis)
CREATE VIEW view_inventory_value AS
SELECT p.product_id, p.name, p.quantity_in_stock, p.cost_price,
       (p.quantity_in_stock * p.cost_price) AS stock_value_at_cost,
       (p.quantity_in_stock * p.selling_price) AS stock_value_at_retail
FROM products p
WHERE p.is_active = 1;
