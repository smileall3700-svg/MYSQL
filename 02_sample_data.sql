-- ============================================================
-- SAMPLE DATA — run after 01_schema.sql to try the system out
-- ============================================================
USE store_management;

-- Categories
INSERT INTO categories (name, description) VALUES
('Grocery', 'Packaged food and pantry staples'),
('Beverages', 'Soft drinks, juices, water'),
('Dairy', 'Milk, cheese, yogurt'),
('Household', 'Cleaning and home supplies'),
('Personal Care', 'Hygiene and grooming products');

-- Suppliers
INSERT INTO suppliers (name, contact_person, phone, email, address) VALUES
('Sunrise Distributors', 'Anil Mehta', '9876543210', 'anil@sunrise.com', 'Sector 12, Bijnor'),
('Fresh Farms Co.', 'Rita Sharma', '9876500011', 'rita@freshfarms.com', 'MG Road, Moradabad'),
('CleanHome Supplies', 'Vikas Rao', '9876500022', 'vikas@cleanhome.com', 'Industrial Area, Meerut');

-- Employees
INSERT INTO employees (name, role, phone, email, hire_date, status) VALUES
('Priya Singh', 'manager', '9998887770', 'priya@store.com', '2023-02-01', 'active'),
('Rahul Verma', 'cashier', '9998887771', 'rahul@store.com', '2023-06-15', 'active'),
('Sonia Kapoor', 'stock_clerk', '9998887772', 'sonia@store.com', '2024-01-10', 'active');

-- Customers
INSERT INTO customers (name, phone, email, loyalty_points) VALUES
('Amit Kumar', '9123456780', 'amit@example.com', 120),
('Neha Gupta', '9123456781', 'neha@example.com', 45),
('Sanjay Yadav', '9123456782', 'sanjay@example.com', 0);

-- Products
INSERT INTO products (sku, name, category_id, supplier_id, cost_price, selling_price, quantity_in_stock, reorder_level, unit) VALUES
('GRO-001', 'Basmati Rice 5kg', 1, 1, 380.00, 450.00, 60, 15, 'bag'),
('GRO-002', 'Wheat Flour 5kg', 1, 1, 190.00, 230.00, 8, 15, 'bag'),
('BEV-001', 'Cola 750ml', 2, 1, 28.00, 40.00, 120, 30, 'bottle'),
('BEV-002', 'Orange Juice 1L', 2, 2, 55.00, 75.00, 40, 20, 'carton'),
('DAI-001', 'Toned Milk 1L', 3, 2, 44.00, 52.00, 25, 25, 'pack'),
('DAI-002', 'Paneer 200g', 3, 2, 60.00, 80.00, 5, 10, 'pack'),
('HH-001', 'Dish Wash Liquid 500ml', 4, 3, 65.00, 95.00, 30, 10, 'bottle'),
('HH-002', 'Floor Cleaner 1L', 4, 3, 80.00, 120.00, 12, 10, 'bottle'),
('PC-001', 'Shampoo 340ml', 5, 3, 140.00, 190.00, 22, 10, 'bottle'),
('PC-002', 'Toothpaste 150g', 5, 3, 45.00, 65.00, 3, 15, 'tube');

-- Purchase order (stock coming in)
INSERT INTO purchase_orders (supplier_id, employee_id, order_date, expected_date, status) VALUES
(1, 1, '2026-07-10', '2026-07-15', 'received');
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_cost) VALUES
(1, 1, 20, 380.00),
(1, 2, 15, 190.00);

-- Sales (each insert into sales, then sale_items — triggers handle stock + totals)
INSERT INTO sales (customer_id, employee_id, payment_method) VALUES
(1, 2, 'cash'),
(2, 2, 'card'),
(NULL, 2, 'upi');

INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES
(1, 1, 2, 450.00),
(1, 3, 4, 40.00),
(2, 5, 3, 52.00),
(2, 9, 1, 190.00),
(3, 7, 2, 95.00),
(3, 10, 2, 65.00);
