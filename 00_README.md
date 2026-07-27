# Store Management System — MySQL + Dashboard

## What's included
1. **01_schema.sql** — full MySQL schema: categories, suppliers, employees,
   customers, products, sales, sale_items, purchase_orders,
   purchase_order_items, inventory_transactions. Includes triggers that
   auto-adjust stock on every sale/purchase, a stored procedure
   (`sp_add_sale_item`) that blocks overselling, and reporting views
   (`view_low_stock`, `view_daily_sales`, `view_top_products`,
   `view_sales_by_category`, `view_inventory_value`) built specifically to
   feed a dashboard.
2. **02_sample_data.sql** — sample categories, products, a purchase order,
   and a few sales so you can try queries immediately.
3. **03_dashboard.html** — a standalone, interactive dashboard (Overview,
   Inventory, Sales, Customers & Suppliers) with charts and tables. It
   currently runs on mock data shaped exactly like the schema, so you can
   open it in any browser with no setup.

## Setting up the database
```bash
mysql -u root -p < 01_schema.sql
mysql -u root -p < 02_sample_data.sql
```

Try the built-in reporting views right away:
```sql
SELECT * FROM view_low_stock;
SELECT * FROM view_daily_sales ORDER BY sale_day DESC;
SELECT * FROM view_top_products LIMIT 5;
```

## Recording a sale safely
Insert the sale header, then add items through the stored procedure so
stock is checked before it's deducted:
```sql
INSERT INTO sales (customer_id, employee_id, payment_method) VALUES (1, 2, 'cash');
CALL sp_add_sale_item(LAST_INSERT_ID(), 3, 2);  -- sale_id, product_id, quantity
```
The triggers on `sale_items` automatically decrement `products.quantity_in_stock`,
log the movement in `inventory_transactions`, and recompute the sale total.

## Connecting the dashboard to live data
`03_dashboard.html` is currently self-contained (mock arrays near the top of
the `<script>` block: `products`, `topProducts`, `recentSales`, `customers`,
`suppliers`). To go live, replace those arrays with `fetch()` calls to a
small API layer (Node/Express, PHP, or Python/Flask) that queries the views
above and returns JSON — the chart and table rendering code doesn't need to
change.

## Extending it
Natural next additions: user accounts/roles for staff login, barcode
scanning at checkout, a returns/refunds table, multi-branch support (add a
`store_id` to `products`/`sales`), and scheduled low-stock email alerts
driven off `view_low_stock`.
