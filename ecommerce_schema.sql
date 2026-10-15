-- =====================================================================
--  Experiment 2 : ER Diagram -> Relational Schema (MySQL 8.0+)
--  Student : Ritesh Vishwakarma    UID : 25LBCS3192
--  Indian E-Commerce Platform
--  Run:  mysql -u root -p --force < ecommerce_schema.sql
--        (--force keeps running after the intentional errors in Part C)
-- =====================================================================

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;

-- =====================================================================
--  PART A : CREATE TABLE STATEMENTS
-- =====================================================================

-- ---------- 1. CUSTOMER (strong entity, composite attribute "name") ----
CREATE TABLE customer (
    customer_id    VARCHAR(10)  PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,          -- composite: name
    middle_name    VARCHAR(50),                    -- composite: name
    last_name      VARCHAR(50)  NOT NULL,          -- composite: name
    email          VARCHAR(100) NOT NULL UNIQUE,
    date_of_birth  DATE,                           -- age is derived, not stored
    registered_on  DATE         NOT NULL DEFAULT (CURRENT_DATE)
);

-- ---------- 2. CUSTOMER_PHONE (multi-valued attribute) ----------------
CREATE TABLE customer_phone (
    customer_id   VARCHAR(10) NOT NULL,
    phone_number  CHAR(10)    NOT NULL,
    PRIMARY KEY (customer_id, phone_number),
    CONSTRAINT chk_cust_phone CHECK (phone_number REGEXP '^[6-9][0-9]{9}$'),
    CONSTRAINT fk_cphone_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------- 3. ADDRESS (weak entity, owner = CUSTOMER) -----------------
CREATE TABLE address (
    customer_id   VARCHAR(10) NOT NULL,            -- owner key
    address_seq   INT         NOT NULL,            -- partial key
    house_no      VARCHAR(20) NOT NULL,            -- composite: street_address
    street        VARCHAR(100) NOT NULL,           -- composite: street_address
    landmark      VARCHAR(100),                    -- composite: street_address
    city          VARCHAR(50) NOT NULL,
    state         VARCHAR(50) NOT NULL,
    pincode       CHAR(6)     NOT NULL,
    address_type  ENUM('Home','Work','Other') NOT NULL DEFAULT 'Home',
    PRIMARY KEY (customer_id, address_seq),
    CONSTRAINT chk_pincode CHECK (pincode REGEXP '^[1-9][0-9]{5}$'),
    CONSTRAINT fk_address_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------- 4. SELLER --------------------------------------------------
CREATE TABLE seller (
    seller_id           VARCHAR(10)  PRIMARY KEY,
    business_name       VARCHAR(100) NOT NULL,
    gstin               CHAR(15)     NOT NULL UNIQUE,
    pan                 CHAR(10)     NOT NULL UNIQUE,
    contact_first_name  VARCHAR(50)  NOT NULL,     -- composite: contact_name
    contact_last_name   VARCHAR(50),               -- composite: contact_name
    email               VARCHAR(100) NOT NULL UNIQUE,
    pickup_city         VARCHAR(50)  NOT NULL,     -- composite: pickup_address
    pickup_state        VARCHAR(50)  NOT NULL,     -- composite: pickup_address
    pickup_pincode      CHAR(6)      NOT NULL,     -- composite: pickup_address
    CONSTRAINT chk_pan   CHECK (pan   REGEXP '^[A-Z]{5}[0-9]{4}[A-Z]$'),
    CONSTRAINT chk_gstin CHECK (gstin REGEXP '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

-- ---------- 5. SELLER_PHONE (multi-valued attribute) ------------------
CREATE TABLE seller_phone (
    seller_id     VARCHAR(10) NOT NULL,
    phone_number  CHAR(10)    NOT NULL,
    PRIMARY KEY (seller_id, phone_number),
    CONSTRAINT fk_sphone_seller FOREIGN KEY (seller_id)
        REFERENCES seller(seller_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------- 6. CATEGORY (recursive relationship "parent of") ----------
CREATE TABLE category (
    category_id         VARCHAR(10)  PRIMARY KEY,
    category_name       VARCHAR(100) NOT NULL UNIQUE,
    description         VARCHAR(255),
    parent_category_id  VARCHAR(10)  NULL,
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id)
        REFERENCES category(category_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------- 7. PRODUCT (superclass of the specialization) -------------
CREATE TABLE product (
    product_id     VARCHAR(10)   PRIMARY KEY,
    seller_id      VARCHAR(10)   NOT NULL,
    category_id    VARCHAR(10)   NULL,             -- SET NULL if category removed
    product_name   VARCHAR(150)  NOT NULL,
    brand          VARCHAR(50),
    mrp            DECIMAL(10,2) NOT NULL,
    selling_price  DECIMAL(10,2) NOT NULL,
    hsn_code       VARCHAR(8)    NOT NULL,
    gst_rate       DECIMAL(4,2)  NOT NULL,
    stock_qty      INT           NOT NULL DEFAULT 0,
    product_type   ENUM('Electronics','Clothing','Book','Grocery','Other') NOT NULL DEFAULT 'Other',
    CONSTRAINT chk_price    CHECK (selling_price > 0 AND selling_price <= mrp),
    CONSTRAINT chk_gst_rate CHECK (gst_rate IN (0, 5, 12, 18, 28)),
    CONSTRAINT chk_stock    CHECK (stock_qty >= 0),
    CONSTRAINT fk_product_seller FOREIGN KEY (seller_id)
        REFERENCES seller(seller_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_product_category FOREIGN KEY (category_id)
        REFERENCES category(category_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------- 8. PRODUCT_IMAGE (multi-valued attribute) -----------------
CREATE TABLE product_image (
    product_id  VARCHAR(10)  NOT NULL,
    image_url   VARCHAR(255) NOT NULL,
    PRIMARY KEY (product_id, image_url),
    CONSTRAINT fk_pimage_product FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------- 9-12. SUBCLASSES (disjoint, partial specialization) --------
CREATE TABLE electronics (
    product_id         VARCHAR(10) PRIMARY KEY,
    model_number       VARCHAR(50) NOT NULL,
    warranty_months    INT         NOT NULL DEFAULT 12,
    bis_certification  VARCHAR(30),
    CONSTRAINT fk_elec_product FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE clothing (
    product_id  VARCHAR(10) PRIMARY KEY,
    size        ENUM('XS','S','M','L','XL','XXL') NOT NULL,
    fabric      VARCHAR(30) NOT NULL,
    gender      ENUM('Men','Women','Kids','Unisex') NOT NULL,
    CONSTRAINT fk_cloth_product FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE book (
    product_id  VARCHAR(10)  PRIMARY KEY,
    isbn        CHAR(13)     NOT NULL UNIQUE,
    author      VARCHAR(100) NOT NULL,
    publisher   VARCHAR(100),
    language    VARCHAR(30)  NOT NULL DEFAULT 'English',
    CONSTRAINT fk_book_product FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE grocery (
    product_id     VARCHAR(10) PRIMARY KEY,
    fssai_license  CHAR(14)    NOT NULL,
    expiry_date    DATE        NOT NULL,
    is_vegetarian  BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_grocery_product FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------- 13. ORDERS ("ORDER" is a reserved word in MySQL) ----------
CREATE TABLE orders (
    order_id          VARCHAR(12) PRIMARY KEY,
    customer_id       VARCHAR(10) NOT NULL,
    ship_customer_id  VARCHAR(10) NULL,            -- FK to ADDRESS (part 1)
    ship_address_seq  INT         NULL,            -- FK to ADDRESS (part 2)
    order_date        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status      ENUM('Placed','Shipped','Delivered','Cancelled','Returned')
                      NOT NULL DEFAULT 'Placed',
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,      -- keep order history
    CONSTRAINT fk_orders_address FOREIGN KEY (ship_customer_id, ship_address_seq)
        REFERENCES address(customer_id, address_seq)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------- 14. ORDER_ITEM (weak entity, owner = ORDERS) --------------
CREATE TABLE order_item (
    order_id    VARCHAR(12)   NOT NULL,            -- owner key
    line_no     INT           NOT NULL,            -- partial key
    product_id  VARCHAR(10)   NOT NULL,
    quantity    INT           NOT NULL,
    unit_price  DECIMAL(10,2) NOT NULL,
    gst_amount  DECIMAL(10,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (order_id, line_no),
    CONSTRAINT chk_qty CHECK (quantity > 0),
    CONSTRAINT fk_oitem_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_oitem_product FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE       -- cannot delete a sold product
);

-- ---------- 15. PAYMENT -----------------------------------------------
CREATE TABLE payment (
    payment_id       VARCHAR(12)   PRIMARY KEY,
    order_id         VARCHAR(12)   NOT NULL,
    amount           DECIMAL(10,2) NOT NULL,
    payment_mode     ENUM('UPI','Card','NetBanking','Wallet','COD','EMI') NOT NULL,
    transaction_ref  VARCHAR(30)   UNIQUE,         -- NULL allowed for COD
    payment_status   ENUM('Pending','Success','Failed','Refunded') NOT NULL DEFAULT 'Pending',
    paid_at          DATETIME,
    CONSTRAINT chk_amount CHECK (amount > 0),
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------- 16. DELIVERY (weak entity, owner = ORDERS) ----------------
CREATE TABLE delivery (
    order_id         VARCHAR(12) NOT NULL,         -- owner key
    shipment_no      INT         NOT NULL,         -- partial key
    courier_partner  VARCHAR(50) NOT NULL,
    awb_number       VARCHAR(20) NOT NULL UNIQUE,
    dispatch_date    DATE,
    expected_date    DATE,
    delivered_date   DATE,
    delivery_status  ENUM('Pending','In Transit','Out for Delivery','Delivered','RTO')
                     NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (order_id, shipment_no),
    CONSTRAINT fk_delivery_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

SHOW TABLES;

-- =====================================================================
--  PART B : SAMPLE DATA
-- =====================================================================

INSERT INTO customer (customer_id, first_name, middle_name, last_name, email, date_of_birth, registered_on) VALUES
('C001', 'Aarav',  NULL,     'Sharma', 'aarav.sharma@gmail.com', '1998-04-12', '2024-01-10'),
('C002', 'Priya',  'Lakshmi','Iyer',   'priya.iyer@yahoo.in',    '2000-09-25', '2024-03-05'),
('C003', 'Rohan',  NULL,     'Das',    'rohan.das@outlook.com',  '1995-12-01', '2025-02-18'),
('C004', 'Sneha',  NULL,     'Patel',  'sneha.patel@gmail.com',  '2001-06-30', '2025-07-22');

INSERT INTO customer_phone VALUES
('C001', '9876543210'), ('C001', '8765432109'),
('C002', '9123456780'),
('C003', '7012345678'),
('C004', '6301234567');

INSERT INTO address VALUES
('C001', 1, '12B',  'MG Road',          'Near Metro Station', 'Bengaluru', 'Karnataka',   '560001', 'Home'),
('C001', 2, '4th Floor, Tower A', 'Outer Ring Road', 'Embassy Tech Village', 'Bengaluru', 'Karnataka', '560103', 'Work'),
('C002', 1, '7',    'T Nagar Main Road', NULL,                'Chennai',   'Tamil Nadu',  '600017', 'Home'),
('C003', 1, '22/5', 'Salt Lake Sector V', 'Opp. City Centre', 'Kolkata',   'West Bengal', '700091', 'Home'),
('C004', 1, '101',  'CG Road',          'Navrangpura',        'Ahmedabad', 'Gujarat',     '380009', 'Home');

INSERT INTO seller VALUES
('S001', 'TechWorld Electronics', '29AABCT1234F1Z5', 'AABCT1234F', 'Vikram', 'Rao',   'sales@techworld.in',   'Bengaluru', 'Karnataka',   '560034'),
('S002', 'Desi Threads',          '24AAFCD5678K1Z2', 'AAFCD5678K', 'Meera',  'Shah',  'hello@desithreads.in', 'Surat',     'Gujarat',     '395003'),
('S003', 'Book Bazaar',           '07AAGCB9012M1Z8', 'AAGCB9012M', 'Anil',   'Gupta', 'orders@bookbazaar.in', 'New Delhi', 'Delhi',       '110002'),
('S004', 'Kisan Fresh Foods',     '27AAHCK3456P1Z1', 'AAHCK3456P', 'Suresh', 'Patil', 'care@kisanfresh.in',   'Pune',      'Maharashtra', '411001');

INSERT INTO seller_phone VALUES
('S001', '8045671234'), ('S001', '9845012345'),
('S002', '9909012345'),
('S003', '9811098110'),
('S004', '9822098220');

INSERT INTO category VALUES
('CAT01', 'Electronics',       'Electronic gadgets',        NULL),
('CAT02', 'Mobiles',           'Smartphones and feature phones', 'CAT01'),
('CAT03', 'Fashion',           'Clothing and accessories',  NULL),
('CAT04', 'Ethnic Wear',       'Kurtas, sarees, sherwanis', 'CAT03'),
('CAT05', 'Books',             'Printed books',             NULL),
('CAT06', 'Grocery',           'Daily essentials',          NULL),
('CAT07', 'Home Decor',        'Furniture and decor',       NULL);

INSERT INTO product VALUES
('P001', 'S001', 'CAT02', 'Redmi Note 13 5G (8GB/256GB)', 'Xiaomi',   20999.00, 17999.00, '8517', 18, 50,  'Electronics'),
('P002', 'S001', 'CAT01', 'boAt Airdopes 141',            'boAt',      4490.00,  1299.00, '8518', 18, 200, 'Electronics'),
('P003', 'S002', 'CAT04', 'Cotton Straight Kurta',        'Fabindia',  1999.00,  1499.00, '6211', 5,  120, 'Clothing'),
('P004', 'S003', 'CAT05', 'Wings of Fire',                'Universities Press', 399.00, 299.00, '4901', 0, 80, 'Book'),
('P005', 'S004', 'CAT06', 'Basmati Rice 5kg',             'India Gate', 899.00,   749.00, '1006', 5,  300, 'Grocery'),
('P006', 'S004', 'CAT07', 'Brass Diya Set (Pack of 4)',   'Handicraft', 599.00,   449.00, '7419', 12, 60,  'Other');

INSERT INTO product_image VALUES
('P001', 'https://cdn.example.in/p001_front.jpg'),
('P001', 'https://cdn.example.in/p001_back.jpg'),
('P003', 'https://cdn.example.in/p003.jpg'),
('P004', 'https://cdn.example.in/p004.jpg');

INSERT INTO electronics VALUES
('P001', 'RN13-5G-256', 12, 'R-41234567'),
('P002', 'AD141-BLK',   12, 'R-41987654');
INSERT INTO clothing VALUES ('P003', 'L', 'Cotton', 'Men');
INSERT INTO book     VALUES ('P004', '9788173711466', 'A. P. J. Abdul Kalam', 'Universities Press', 'English');
INSERT INTO grocery  VALUES ('P005', '10014011001234', '2027-06-30', TRUE);
-- P006 (Brass Diya Set) belongs to no subclass -> partial specialization

INSERT INTO orders VALUES
('ORD1001', 'C001', 'C001', 1, '2026-09-01 10:15:00', 'Delivered'),
('ORD1002', 'C002', 'C002', 1, '2026-09-05 18:40:00', 'Shipped'),
('ORD1003', 'C001', 'C001', 2, '2026-09-10 09:05:00', 'Placed'),
('ORD1004', 'C003', 'C003', 1, '2026-09-12 21:30:00', 'Delivered');

INSERT INTO order_item VALUES
('ORD1001', 1, 'P001', 1, 17999.00, 2745.61),
('ORD1001', 2, 'P002', 2,  1299.00,  396.31),
('ORD1002', 1, 'P003', 2,  1499.00,  142.76),
('ORD1003', 1, 'P004', 3,   299.00,    0.00),
('ORD1003', 2, 'P005', 1,   749.00,   35.67),
('ORD1004', 1, 'P006', 2,   449.00,   96.21);

INSERT INTO payment VALUES
('PAY5001', 'ORD1001', 20597.00, 'UPI',        'UTR426101234567', 'Success', '2026-09-01 10:16:00'),
('PAY5002', 'ORD1002',  2998.00, 'Card',       'RZP_KJ8H2L9P0Q',  'Success', '2026-09-05 18:41:00'),
('PAY5003', 'ORD1003',  1646.00, 'COD',        NULL,              'Pending', NULL),
('PAY5004', 'ORD1004',   898.00, 'UPI',        'UTR426109876543', 'Failed',  '2026-09-12 21:31:00'),
('PAY5005', 'ORD1004',   898.00, 'NetBanking', 'NB20260912ICIC01','Success', '2026-09-12 21:35:00');

INSERT INTO delivery VALUES
('ORD1001', 1, 'Delhivery',  'DLV1234567890', '2026-09-02', '2026-09-05', '2026-09-04', 'Delivered'),
('ORD1001', 2, 'Ekart',      'EKT9876543210', '2026-09-02', '2026-09-06', '2026-09-06', 'Delivered'),
('ORD1002', 1, 'Blue Dart',  'BD55667788',    '2026-09-06', '2026-09-09', NULL,         'In Transit'),
('ORD1004', 1, 'India Post', 'EE123456789IN', '2026-09-13', '2026-09-18', '2026-09-17', 'Delivered');

-- Row count of every table
SELECT 'customer' AS table_name, COUNT(*) AS row_count FROM customer
UNION ALL SELECT 'customer_phone', COUNT(*) FROM customer_phone
UNION ALL SELECT 'address',        COUNT(*) FROM address
UNION ALL SELECT 'seller',         COUNT(*) FROM seller
UNION ALL SELECT 'seller_phone',   COUNT(*) FROM seller_phone
UNION ALL SELECT 'category',       COUNT(*) FROM category
UNION ALL SELECT 'product',        COUNT(*) FROM product
UNION ALL SELECT 'product_image',  COUNT(*) FROM product_image
UNION ALL SELECT 'electronics',    COUNT(*) FROM electronics
UNION ALL SELECT 'clothing',       COUNT(*) FROM clothing
UNION ALL SELECT 'book',           COUNT(*) FROM book
UNION ALL SELECT 'grocery',        COUNT(*) FROM grocery
UNION ALL SELECT 'orders',         COUNT(*) FROM orders
UNION ALL SELECT 'order_item',     COUNT(*) FROM order_item
UNION ALL SELECT 'payment',        COUNT(*) FROM payment
UNION ALL SELECT 'delivery',       COUNT(*) FROM delivery;

-- =====================================================================
--  PART C : REFERENTIAL INTEGRITY & CONSTRAINT VIOLATIONS
--  Each statement below is EXPECTED to fail.
-- =====================================================================

-- C1. INSERT child with non-existent parent (FK violation) -> ERROR 1452
INSERT INTO orders (order_id, customer_id) VALUES ('ORD9999', 'C999');

-- C2. INSERT order item for a product that does not exist -> ERROR 1452
INSERT INTO order_item VALUES ('ORD1001', 3, 'P999', 1, 100.00, 0);

-- C3. DELETE a product that has been ordered (ON DELETE RESTRICT) -> ERROR 1451
DELETE FROM product WHERE product_id = 'P001';

-- C4. DELETE a customer who has orders (ON DELETE RESTRICT) -> ERROR 1451
DELETE FROM customer WHERE customer_id = 'C001';

-- C5. UPDATE a child FK to a non-existent parent -> ERROR 1452
UPDATE product SET seller_id = 'S999' WHERE product_id = 'P002';

-- C6. NOT NULL violation -> ERROR 1048
INSERT INTO customer (customer_id, first_name, last_name, email)
VALUES ('C005', 'Kabir', 'Singh', NULL);

-- C7. UNIQUE violation (duplicate email) -> ERROR 1062
INSERT INTO customer (customer_id, first_name, last_name, email)
VALUES ('C005', 'Kabir', 'Singh', 'aarav.sharma@gmail.com');

-- C8. PRIMARY KEY violation (duplicate weak-entity key) -> ERROR 1062
INSERT INTO address VALUES ('C002', 1, '9', 'Anna Salai', NULL, 'Chennai', 'Tamil Nadu', '600002', 'Work');

-- C9. CHECK violation (invalid 5-digit PIN code) -> ERROR 3819
INSERT INTO address VALUES ('C004', 2, '5', 'SG Highway', NULL, 'Ahmedabad', 'Gujarat', '38005', 'Work');

-- C10. Weak entity without owner -> ERROR 1452
INSERT INTO delivery VALUES ('ORD7777', 1, 'Delhivery', 'DLV0000000001', NULL, NULL, NULL, 'Pending');

-- C11. DROP a parent table that is still referenced -> ERROR 3730
DROP TABLE seller;

-- =====================================================================
--  PART D : ON DELETE CASCADE  (these succeed)
-- =====================================================================

-- D1. Deleting an ORDER cascades to ORDER_ITEM, PAYMENT and DELIVERY
SELECT 'BEFORE' AS stage,
       (SELECT COUNT(*) FROM order_item WHERE order_id = 'ORD1001') AS items,
       (SELECT COUNT(*) FROM payment    WHERE order_id = 'ORD1001') AS payments,
       (SELECT COUNT(*) FROM delivery   WHERE order_id = 'ORD1001') AS deliveries;

DELETE FROM orders WHERE order_id = 'ORD1001';

SELECT 'AFTER' AS stage,
       (SELECT COUNT(*) FROM order_item WHERE order_id = 'ORD1001') AS items,
       (SELECT COUNT(*) FROM payment    WHERE order_id = 'ORD1001') AS payments,
       (SELECT COUNT(*) FROM delivery   WHERE order_id = 'ORD1001') AS deliveries;

-- D2. Deleting a CUSTOMER with no orders cascades to phones and addresses
DELETE FROM customer WHERE customer_id = 'C004';
SELECT * FROM customer_phone WHERE customer_id = 'C004';   -- Empty set
SELECT * FROM address        WHERE customer_id = 'C004';   -- Empty set

-- D3. ON UPDATE CASCADE: renaming a seller ID updates all its products
UPDATE seller SET seller_id = 'S010' WHERE seller_id = 'S003';
SELECT product_id, seller_id FROM product WHERE product_id = 'P004';
SELECT * FROM seller_phone WHERE seller_id = 'S010';

-- =====================================================================
--  PART E : ON DELETE SET NULL  (these succeed)
-- =====================================================================

-- E1. Deleting parent category 'Fashion' -> sub-category parent becomes NULL
DELETE FROM category WHERE category_id = 'CAT03';
SELECT category_id, category_name, parent_category_id FROM category WHERE category_id = 'CAT04';

-- E2. Deleting category 'Home Decor' -> its product's category_id becomes NULL
DELETE FROM category WHERE category_id = 'CAT07';
SELECT product_id, product_name, category_id FROM product WHERE product_id = 'P006';

-- E3. Deleting a saved address -> order is kept, ship-to address becomes NULL
DELETE FROM address WHERE customer_id = 'C001' AND address_seq = 2;
SELECT order_id, customer_id, ship_customer_id, ship_address_seq FROM orders WHERE order_id = 'ORD1003';

-- =====================================================================
--  PART F : VERIFY CONSTRAINTS FROM THE DATA DICTIONARY
-- =====================================================================
SELECT rc.TABLE_NAME, rc.CONSTRAINT_NAME, rc.REFERENCED_TABLE_NAME,
       rc.DELETE_RULE, rc.UPDATE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS rc
WHERE rc.CONSTRAINT_SCHEMA = 'ecommerce_db'
ORDER BY rc.TABLE_NAME, rc.CONSTRAINT_NAME;
