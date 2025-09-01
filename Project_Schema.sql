-- 1. Stores
CREATE TABLE stores (
    store_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_name         VARCHAR(255) NOT NULL,
    address            VARCHAR(255),
    city               VARCHAR(100),
    state              VARCHAR(50),
    zip                VARCHAR(50),
    open_date          DATE
);

-- 2. Product Categories
CREATE TABLE product_category (
    category_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name      VARCHAR(100) NOT NULL
);

-- 3. Products
CREATE TABLE products (
    product_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name       VARCHAR(255) NOT NULL,
    category_id        INT NOT NULL REFERENCES product_category(category_id),
    product_sku        VARCHAR(100)
);

-- 4. Employees
CREATE TABLE employees (
    employee_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name         VARCHAR(50) NOT NULL,
    last_name          VARCHAR(50) NOT NULL,
    store_id           INT NOT NULL REFERENCES stores(store_id),
    phone              VARCHAR(50),
    email              VARCHAR(100),
    salary             NUMERIC(12,2),
    start_date         DATE,
    employment_status  VARCHAR(50),
    job_title          VARCHAR(100)
);

-- 5. Vendors
CREATE TABLE vendors (
    vendor_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_name        VARCHAR(255) NOT NULL,
    vendor_phone       VARCHAR(50),
    vendor_email       VARCHAR(100)
);

-- 6. Vendor–Product Quotes
CREATE TABLE vendor_product (
    vendor_product_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_id          INT NOT NULL REFERENCES vendors(vendor_id),
    product_id         INT NOT NULL REFERENCES products(product_id),
    quoted_unit_cost   NUMERIC(12,2)
);

-- 7. Purchase Orders
CREATE TABLE purchase_order (
    purchase_order_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_id          INT NOT NULL REFERENCES vendors(vendor_id),
    store_id           INT NOT NULL REFERENCES stores(store_id),
    order_date         DATE NOT NULL,
    status             VARCHAR(50)
);

-- 8. Purchase Products
CREATE TABLE purchase_product (
    purchase_product_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id          INT NOT NULL REFERENCES products(product_id),
	purchase_order_id	INT NOT NULL REFERENCES purchase_order(purchase_order_id)
    quantity_purchased  INT,
    actual_unit_cost    NUMERIC(12,2)
);

-- 9. Payment Methods
CREATE TABLE payment_method (
    payment_method_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    method_name        VARCHAR(50) NOT NULL
);

-- 10. Transactions
CREATE TABLE transactions (
    transaction_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id           INT NOT NULL REFERENCES stores(store_id),
    employee_id        INT NOT NULL REFERENCES employees(employee_id),
    tran_time          TIMESTAMP NOT NULL,
    tran_amt           NUMERIC(12,2),
    payment_method_id  INT REFERENCES payment_method(payment_method_id)
);

-- 11. Refunds
CREATE TABLE refunds (
    refunds_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    original_tran_id   INT NOT NULL REFERENCES transactions(transaction_id),
    refund_time        TIMESTAMP,
    employee_id        INT REFERENCES employees(employee_id),
    refund_amt         NUMERIC(12,2),
    reason             TEXT
);

-- 12. Operating Expenses
CREATE TABLE operating_expenses (
    expense_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id           INT NOT NULL REFERENCES stores(store_id),
    expense_type       VARCHAR(100),
    amount             NUMERIC(12,2),
    expense_date       DATE
);

-- 13. Inventory
CREATE TABLE inventory (
    inventory_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id           INT NOT NULL REFERENCES stores(store_id),
    product_id         INT NOT NULL REFERENCES products(product_id),
    quantity_in_stock  INT,
    reorder_threshold  INT,
    last_updated       TIMESTAMP
);

-- 14. Inventory Lots
CREATE TABLE inventory_lot (
    lot_id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id           INT NOT NULL REFERENCES stores(store_id),
    product_id         INT NOT NULL REFERENCES products(product_id),
    quantity           INT,
    expiration_date    DATE,
    received_date      DATE CHECK (expiration_date >= received_date)
);

-- 15. Shifts
CREATE TABLE shifts (
    shift_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id        INT NOT NULL REFERENCES employees(employee_id),
    store_id           INT NOT NULL REFERENCES stores(store_id),
    schedule_start     TIMESTAMP,
    schedule_end       TIMESTAMP
);

-- 16. Sales Detailed Items
CREATE TABLE sales_detailed_item (
    detailed_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id     INT NOT NULL REFERENCES transactions(transaction_id),
    product_id         INT NOT NULL REFERENCES products(product_id),
    quantity           INT,
    actual_unit_price  NUMERIC(12,2),
    discount           NUMERIC(12,2)
);


-- Create the trigger function to automatically updates inventory quantity
CREATE OR REPLACE FUNCTION update_inventory_after_sale()
RETURNS TRIGGER AS $$
BEGIN
  -- Decrease quantity from the inventory table when product sold
  UPDATE inventory
  SET quantity_in_stock = quantity_in_stock - NEW.quantity,
      last_updated = NOW()
  WHERE product_id = NEW.product_id
    AND store_id = (
      SELECT store_id
      FROM transactions
      WHERE transaction_id = NEW.transaction_id
    );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_update_inventory_after_sale
AFTER INSERT ON sales_detailed_item
FOR EACH ROW
EXECUTE FUNCTION update_inventory_after_sale();


CREATE OR REPLACE FUNCTION update_inventory_after_delivery()
RETURNS TRIGGER AS $$
BEGIN
  -- Increase quantity from the inventory table when delivery receive
  UPDATE inventory
  SET quantity_in_stock = quantity_in_stock + NEW.quantity,
      last_updated = NOW()
  WHERE store_id = NEW.store_id
    AND product_id = NEW.product_id;

  IF NOT FOUND THEN
    INSERT INTO inventory (store_id, product_id, quantity_in_stock, last_updated)
    VALUES (NEW.store_id, NEW.product_id, NEW.quantity, NOW());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_update_inventory_after_delivery
AFTER INSERT ON inventory_lot
FOR EACH ROW
EXECUTE FUNCTION update_inventory_after_delivery();


