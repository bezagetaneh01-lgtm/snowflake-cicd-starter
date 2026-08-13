/*
  seed_data.sql - Sample data for exploring the schema.

  NOT a migration. Lives outside migrations/ on purpose, so schemachange
  never picks it up automatically. Run this by hand, whenever you want,
  against whichever database you're pointed at (DEMO_DEV or DEMO_PROD) —
  set your Snowsight worksheet's database/schema context first, or just
  run these fully-qualified statements as-is against either one.
*/

INSERT INTO DEMO_DEV.RAW.CUSTOMERS (customer_id, email, full_name) VALUES
    (1, 'alice@example.com',   'Alice Nguyen'),
    (2, 'bob@example.com',     'Bob Martinez'),
    (3, 'carla@example.com',   'Carla Jensen'),
    (4, 'devon@example.com',   'Devon Price'),
    (5, 'elena@example.com',   'Elena Rossi');

INSERT INTO DEMO_DEV.RAW.PRODUCTS (product_id, product_name, price) VALUES
    (1, 'Wireless Mouse',      24.99),
    (2, 'Mechanical Keyboard', 89.99),
    (3, 'USB-C Hub',           34.50),
    (4, '27" Monitor',         249.00),
    (5, 'Laptop Stand',        39.99);

INSERT INTO DEMO_DEV.RAW.CATEGORIES (category_id, category_name) VALUES
    (1, 'Peripherals'),
    (2, 'Displays'),
    (3, 'Accessories');

INSERT INTO DEMO_DEV.RAW.SUPPLIERS (supplier_id, supplier_name, contact_email) VALUES
    (1, 'Acme Supply Co',      'sales@acmesupply.example'),
    (2, 'Northwind Traders',   'orders@northwind.example');

INSERT INTO DEMO_DEV.RAW.ORDERS (order_id, customer_id, order_total) VALUES
    (1, 1, 24.99),
    (2, 2, 89.99),
    (3, 1, 34.50),
    (4, 3, 249.00),
    (5, 4, 39.99),
    (6, 2, 64.49);
