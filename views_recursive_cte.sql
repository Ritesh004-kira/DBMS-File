-- =====================================================================
--  Experiment 5 : SQL Views, View Updatability and Recursive CTEs (MySQL 8.0+)
--  Student : Ritesh Vishwakarma    UID : 25LBCS3192
--  Uses the Employee-Department-Project schema from Experiment 3.
--
--  Run (company_queries.sql from Experiment 3 first; it creates and fills company_db):
--     mysql -u root -p -t < company_queries.sql
--     mysql -u root -p -t --force < views_recursive_cte.sql
--  (--force keeps running after the intentional errors in Part C)
--  All data changes are undone in Part F, so company_db is left unchanged.
-- =====================================================================

USE company_db;

DROP VIEW IF EXISTS v_dept_salary_summary, v_emp_dept, v_employee_manager, v_employee_hierarchy,
                    v_engineering, v_engineering_nocheck, v_eng_senior_local,
                    v_eng_senior_cascaded, v_employee_public, v_emp_pay,
                    v_all_people, v_distinct_designations;

-- =====================================================================
--  PART A : VIEW 1 - DEPARTMENT SALARY SUMMARY
-- =====================================================================

-- V1. [CREATE VIEW - aggregate] Department-wise salary summary view.
CREATE VIEW v_dept_salary_summary AS
SELECT d.dept_id,
       d.dept_name,
       d.location,
       COUNT(e.emp_id)           AS headcount,
       SUM(e.salary)             AS total_monthly_salary,
       ROUND(AVG(e.salary), 2)   AS avg_salary,
       MIN(e.salary)             AS min_salary,
       MAX(e.salary)             AS max_salary,
       SUM(e.salary) * 12        AS annual_payroll
FROM department d
LEFT JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name, d.location;

SELECT * FROM v_dept_salary_summary ORDER BY dept_id;

-- V2. [Query a view] A view is used like a table: filter and sort it.
SELECT dept_name, headcount, avg_salary
FROM v_dept_salary_summary
WHERE avg_salary > 90000
ORDER BY avg_salary DESC;

-- V3. [View is always current] A view stores the query, not the data: a salary change shows up immediately.
SELECT dept_name, total_monthly_salary FROM v_dept_salary_summary WHERE dept_id = 'D02';
UPDATE employee SET salary = salary + 10000 WHERE emp_id = 114;
SELECT dept_name, total_monthly_salary FROM v_dept_salary_summary WHERE dept_id = 'D02';

-- =====================================================================
--  PART B : VIEW 2 - EMPLOYEE HIERARCHY
-- =====================================================================

-- V4. [CREATE VIEW - self-join] Each employee with their direct manager.
CREATE VIEW v_employee_manager AS
SELECT e.emp_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
       e.designation,
       e.dept_id,
       e.manager_id,
       CONCAT(m.first_name, ' ', m.last_name) AS manager_name,
       m.designation                          AS manager_designation
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.emp_id;

SELECT * FROM v_employee_manager WHERE dept_id = 'D01' ORDER BY emp_id;

-- V5. [CREATE VIEW - recursive CTE] Full employee hierarchy with level and reporting path.
CREATE VIEW v_employee_hierarchy AS
WITH RECURSIVE org AS (
    -- anchor member: top-level managers (no manager)
    SELECT emp_id,
           CONCAT(first_name, ' ', last_name)     AS employee_name,
           designation,
           dept_id,
           manager_id,
           1                                      AS level,
           CAST(first_name AS CHAR(500))          AS reporting_path
    FROM employee
    WHERE manager_id IS NULL
    UNION ALL
    -- recursive member: people who report to someone already in org
    SELECT e.emp_id,
           CONCAT(e.first_name, ' ', e.last_name),
           e.designation,
           e.dept_id,
           e.manager_id,
           o.level + 1,
           CONCAT(o.reporting_path, ' > ', e.first_name)
    FROM employee e
    JOIN org o ON e.manager_id = o.emp_id
)
SELECT * FROM org;

SELECT emp_id, employee_name, level, reporting_path
FROM v_employee_hierarchy
WHERE dept_id = 'D01'
ORDER BY reporting_path;

-- V6. [Query the hierarchy view] Number of employees at each level of the organisation.
SELECT level, COUNT(*) AS employees
FROM v_employee_hierarchy
GROUP BY level
ORDER BY level;

-- V7. [SHOW FULL TABLES] List every view in the database.
SHOW FULL TABLES WHERE Table_type = 'VIEW';

-- =====================================================================
--  PART C : TESTING UPDATABILITY OF VIEWS
-- =====================================================================

-- U1. [Updatable view] Simple single-table view of Engineering staff, WITH CHECK OPTION.
CREATE VIEW v_engineering AS
SELECT emp_id, first_name, last_name, gender, dob, hire_date, email,
       city, designation, salary, manager_id, dept_id
FROM employee
WHERE dept_id = 'D01'
WITH CHECK OPTION;

SELECT emp_id, first_name, designation, salary FROM v_engineering WHERE emp_id IN (109, 110);

-- U2. [UPDATE through a view] Give the associate engineers a raise through the view.
UPDATE v_engineering SET salary = salary + 5000 WHERE designation = 'Associate Engineer';
SELECT emp_id, first_name, salary FROM employee WHERE designation = 'Associate Engineer';

-- U3. [INSERT through a view] Add a new Engineering employee through the view.
INSERT INTO v_engineering (emp_id, first_name, last_name, gender, dob, hire_date, email,
                           city, designation, salary, manager_id, dept_id)
VALUES (133, 'Ishaan', 'Malik', 'M', '2001-02-11', '2026-07-01', 'ishaan.malik@company.in',
        'Bengaluru', 'Associate Engineer', 52000, 103, 'D01');
SELECT emp_id, first_name, designation, salary, commission, dept_id FROM employee WHERE emp_id = 133;

-- U4. [WITH CHECK OPTION violation] Inserting a Finance employee through the Engineering view is rejected.
INSERT INTO v_engineering (emp_id, first_name, last_name, gender, dob, hire_date, email,
                           city, designation, salary, manager_id, dept_id)
VALUES (134, 'Riya', 'Sen', 'F', '2000-08-08', '2026-07-01', 'riya.sen@company.in',
        'Kolkata', 'Accountant', 50000, 116, 'D03');

-- U5. [WITH CHECK OPTION violation] Moving an employee out of the view's WHERE condition is rejected.
UPDATE v_engineering SET dept_id = 'D05' WHERE emp_id = 133;

-- U6. [Without CHECK OPTION] The same UPDATE succeeds, and the row disappears from the view.
CREATE VIEW v_engineering_nocheck AS
SELECT emp_id, first_name, dept_id, salary FROM employee WHERE dept_id = 'D01';

UPDATE v_engineering_nocheck SET dept_id = 'D05' WHERE emp_id = 133;
SELECT * FROM v_engineering_nocheck WHERE emp_id = 133;
SELECT emp_id, first_name, dept_id FROM employee WHERE emp_id = 133;

-- U7. [DELETE through a view] Delete the new employee through a view.
UPDATE employee SET dept_id = 'D01' WHERE emp_id = 133;
DELETE FROM v_engineering WHERE emp_id = 133;
SELECT COUNT(*) AS rows_left FROM employee WHERE emp_id = 133;

-- U8. [LOCAL vs CASCADED CHECK OPTION] Views built on a view without its own check.
CREATE VIEW v_eng_senior_local AS
SELECT * FROM v_engineering_nocheck WHERE salary >= 100000
WITH LOCAL CHECK OPTION;

CREATE VIEW v_eng_senior_cascaded AS
SELECT * FROM v_engineering_nocheck WHERE salary >= 100000
WITH CASCADED CHECK OPTION;

-- LOCAL checks only its own condition (salary >= 100000): moving dept is allowed
UPDATE v_eng_senior_local SET dept_id = 'D05' WHERE emp_id = 104;
SELECT emp_id, first_name, dept_id FROM employee WHERE emp_id = 104;
UPDATE employee SET dept_id = 'D01' WHERE emp_id = 104;

-- CASCADED also checks the underlying view's condition (dept_id = 'D01'): rejected
UPDATE v_eng_senior_cascaded SET dept_id = 'D05' WHERE emp_id = 104;

-- U9. [Non-updatable: aggregate view] Views with GROUP BY / aggregates cannot be updated.
UPDATE v_dept_salary_summary SET headcount = 20 WHERE dept_id = 'D01';

-- U10. [Non-updatable: aggregate view] ... and cannot be inserted into or deleted from.
DELETE FROM v_dept_salary_summary WHERE dept_id = 'D01';

-- U11. [Partly updatable: computed column] Base columns can be updated, a derived column cannot.
CREATE VIEW v_emp_pay AS
SELECT emp_id, first_name, salary, salary * 12 AS annual_ctc
FROM employee;

UPDATE v_emp_pay SET salary = 47000 WHERE emp_id = 114;
SELECT * FROM v_emp_pay WHERE emp_id = 114;
UPDATE v_emp_pay SET annual_ctc = 600000 WHERE emp_id = 114;

-- U12. [Non-insertable: computed column] INSERT is not possible when the view has a derived column.
INSERT INTO v_emp_pay (emp_id, first_name, salary) VALUES (135, 'Test', 40000);

-- U13. [Join view] Columns of ONE base table can be updated through an INNER JOIN view ...
CREATE VIEW v_emp_dept AS
SELECT e.emp_id, e.first_name, e.designation, e.salary, d.dept_name, d.location
FROM employee e
JOIN department d ON d.dept_id = e.dept_id;

UPDATE v_emp_dept SET designation = 'Senior Associate Engineer' WHERE emp_id = 109;
SELECT * FROM v_emp_dept WHERE emp_id = 109;
UPDATE employee SET designation = 'Associate Engineer' WHERE emp_id = 109;

-- U14. [Join view] ... but one UPDATE cannot change BOTH base tables, and DELETE is not allowed.
UPDATE v_emp_dept SET salary = 60000, location = 'Pune' WHERE emp_id = 109;
DELETE FROM v_emp_dept WHERE emp_id = 109;

-- U15. [Self-join view] v_employee_manager (LEFT self-join of employee) is not updatable at all.
UPDATE v_employee_manager SET designation = 'Senior Associate Engineer' WHERE emp_id = 109;

-- U16. [Non-updatable: DISTINCT and UNION] Views using DISTINCT or UNION cannot be updated.
CREATE VIEW v_distinct_designations AS
SELECT DISTINCT designation, dept_id FROM employee;

CREATE VIEW v_all_people AS
SELECT emp_id AS id, first_name AS name, 'Employee' AS type FROM employee
UNION
SELECT manager_id, dept_name, 'Department' FROM department;

UPDATE v_distinct_designations SET designation = 'Engineer' WHERE designation = 'Software Engineer';
UPDATE v_all_people SET name = 'X' WHERE id = 101;

-- U17. [Non-updatable: recursive CTE view] The hierarchy view cannot be updated either.
UPDATE v_employee_hierarchy SET designation = 'CTO' WHERE emp_id = 101;

-- U18. [Summary] MySQL reports which views are updatable in INFORMATION_SCHEMA.VIEWS.
SELECT TABLE_NAME AS view_name, IS_UPDATABLE, CHECK_OPTION
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'company_db'
ORDER BY IS_UPDATABLE DESC, TABLE_NAME;

-- U19. [Security view] A view that hides salary and personal data from general users.
CREATE VIEW v_employee_public AS
SELECT e.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS name,
       e.designation, d.dept_name, e.email
FROM employee e
JOIN department d ON d.dept_id = e.dept_id;

SELECT * FROM v_employee_public WHERE dept_name = 'Finance' ORDER BY emp_id;

-- =====================================================================
--  PART D : RECURSIVE CTEs - REPORTING CHAINS
-- =====================================================================

-- R1. [Recursive CTE basics] Generate the numbers 1 to 10.
WITH RECURSIVE numbers AS (
    SELECT 1 AS n                         -- anchor
    UNION ALL
    SELECT n + 1 FROM numbers WHERE n < 10  -- recursive step + stop condition
)
SELECT GROUP_CONCAT(n ORDER BY n SEPARATOR ', ') AS series FROM numbers;

-- R2. [Reporting chain UPWARD] From Rahul (109) up to the top: whom does he report to?
WITH RECURSIVE chain AS (
    SELECT emp_id, first_name, designation, manager_id, 0 AS steps_up
    FROM employee
    WHERE emp_id = 109
    UNION ALL
    SELECT m.emp_id, m.first_name, m.designation, m.manager_id, c.steps_up + 1
    FROM employee m
    JOIN chain c ON m.emp_id = c.manager_id
)
SELECT steps_up, emp_id, first_name, designation
FROM chain
ORDER BY steps_up;

-- R3. [Reporting chain as one line] The same chain printed as a single path.
WITH RECURSIVE chain AS (
    SELECT emp_id, manager_id, CAST(first_name AS CHAR(500)) AS path
    FROM employee
    WHERE emp_id = 109
    UNION ALL
    SELECT m.emp_id, m.manager_id, CONCAT(c.path, ' -> ', m.first_name)
    FROM employee m
    JOIN chain c ON m.emp_id = c.manager_id
)
SELECT path AS reporting_chain
FROM chain
WHERE manager_id IS NULL;

-- R4. [Hierarchy DOWNWARD] Everyone under Ananya (102), directly or indirectly, as an indented tree.
WITH RECURSIVE team AS (
    SELECT emp_id, first_name, designation, 0 AS depth,
           CAST(LPAD(emp_id, 4, '0') AS CHAR(200)) AS sort_key
    FROM employee
    WHERE emp_id = 102
    UNION ALL
    SELECT e.emp_id, e.first_name, e.designation, t.depth + 1,
           CONCAT(t.sort_key, '/', LPAD(e.emp_id, 4, '0'))
    FROM employee e
    JOIN team t ON e.manager_id = t.emp_id
)
SELECT emp_id,
       CONCAT(REPEAT('    ', depth), '└── ', first_name) AS org_tree,
       designation, depth
FROM team
ORDER BY sort_key;

-- R5. [Full org chart] Reporting chain of EVERY employee, from the top manager down.
WITH RECURSIVE org AS (
    SELECT emp_id, dept_id, first_name, 1 AS level,
           CAST(first_name AS CHAR(500)) AS chain
    FROM employee
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.dept_id, e.first_name, o.level + 1,
           CONCAT(o.chain, ' > ', e.first_name)
    FROM employee e
    JOIN org o ON e.manager_id = o.emp_id
)
SELECT dept_id, level, chain
FROM org
ORDER BY dept_id, chain;

-- R6. [Recursive CTE + aggregate] Total team size (direct + indirect reports) for each manager.
WITH RECURSIVE reports AS (
    SELECT manager_id AS boss, emp_id
    FROM employee
    WHERE manager_id IS NOT NULL
    UNION ALL
    SELECT e.manager_id, r.emp_id
    FROM reports r
    JOIN employee e ON e.emp_id = r.boss
    WHERE e.manager_id IS NOT NULL
)
SELECT r.boss AS manager_id, m.first_name AS manager,
       COUNT(*) AS total_team_size,
       SUM(s.salary) AS team_monthly_salary
FROM reports r
JOIN employee m ON m.emp_id = r.boss
JOIN employee s ON s.emp_id = r.emp_id
GROUP BY r.boss, m.first_name
ORDER BY total_team_size DESC, manager_id;

-- R7. [Depth of hierarchy] Deepest reporting chain in each department.
SELECT dept_id, MAX(level) AS max_depth,
       SUBSTRING_INDEX(GROUP_CONCAT(reporting_path ORDER BY level DESC, reporting_path SEPARATOR '|'), '|', 1)
           AS longest_chain
FROM v_employee_hierarchy
GROUP BY dept_id
ORDER BY dept_id;

-- R8. [Cycle protection] A recursive CTE stops at cte_max_recursion_depth (default 1000).
SET SESSION cte_max_recursion_depth = 20;
WITH RECURSIVE runaway AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM runaway          -- no stop condition!
)
SELECT COUNT(*) FROM runaway;
SET SESSION cte_max_recursion_depth = 1000;

-- =====================================================================
--  PART E : MANAGING VIEWS
-- =====================================================================

-- M1. [CREATE OR REPLACE VIEW] Add a column to an existing view without dropping it.
CREATE OR REPLACE VIEW v_employee_public AS
SELECT e.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS name,
       e.designation, d.dept_name, d.location, e.email
FROM employee e
JOIN department d ON d.dept_id = e.dept_id;

SELECT * FROM v_employee_public WHERE emp_id = 120;

-- M2. [DROP VIEW] Dropping a view removes only its definition; the base table is untouched.
DROP VIEW v_distinct_designations, v_all_people;
SELECT COUNT(*) AS employees_still_in_base_table FROM employee;

-- =====================================================================
--  PART F : UNDO THE DATA CHANGES MADE ABOVE
-- =====================================================================

-- F1. [Cleanup] Restore the original salaries changed in V3, U2 and U11.
UPDATE employee SET salary = 42000 WHERE emp_id = 114;
UPDATE employee SET salary = salary - 5000 WHERE designation = 'Associate Engineer';
SELECT emp_id, first_name, salary FROM employee WHERE emp_id IN (108, 109, 110, 114) ORDER BY emp_id;
