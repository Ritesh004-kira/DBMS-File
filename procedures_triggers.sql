-- =====================================================================
--  Experiment 6 : Stored Procedure, Triggers and Edge-Case Testing (MySQL 8.0+)
--  Student : Ritesh Vishwakarma    UID : 25LBCS3192
--  Uses the Employee-Department-Project schema from Experiment 3.
--
--  Run (company_queries.sql from Experiment 3 first; it creates and fills company_db):
--     mysql -u root -p -t < company_queries.sql
--     mysql -u root -p -t --force < procedures_triggers.sql
--  (--force keeps running after the intentional errors in the test cases)
--  NOTE: the tests change employee data. Re-run the Experiment 3 script to reset it.
-- =====================================================================

USE company_db;

DROP TRIGGER   IF EXISTS trg_employee_before_insert;
DROP TRIGGER   IF EXISTS trg_employee_before_update;
DROP TRIGGER   IF EXISTS trg_employee_before_delete;
DROP TRIGGER   IF EXISTS trg_employee_after_insert;
DROP TRIGGER   IF EXISTS trg_employee_after_update;
DROP TRIGGER   IF EXISTS trg_employee_after_delete;
DROP PROCEDURE IF EXISTS transfer_employee;
DROP PROCEDURE IF EXISTS validate_salary;
DROP TABLE     IF EXISTS employee_audit, transfer_history, procedure_error_log;

-- =====================================================================
--  PART A : SUPPORTING TABLES
-- =====================================================================

-- Audit trail written by the triggers (no FK, so history survives deletes)
CREATE TABLE employee_audit (
    audit_id         INT AUTO_INCREMENT PRIMARY KEY,
    emp_id           INT          NOT NULL,
    action           ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    old_dept         CHAR(3),
    new_dept         CHAR(3),
    old_salary       DECIMAL(10,2),
    new_salary       DECIMAL(10,2),
    old_designation  VARCHAR(50),
    new_designation  VARCHAR(50),
    changed_by       VARCHAR(100) NOT NULL,
    changed_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- History of successful transfers written by the procedure
CREATE TABLE transfer_history (
    transfer_id      INT AUTO_INCREMENT PRIMARY KEY,
    emp_id           INT     NOT NULL,
    from_dept        CHAR(3) NOT NULL,
    to_dept          CHAR(3) NOT NULL,
    old_manager_id   INT,
    new_manager_id   INT,
    transferred_by   VARCHAR(100) NOT NULL,
    transferred_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Failed procedure calls captured by the error handler
CREATE TABLE procedure_error_log (
    log_id           INT AUTO_INCREMENT PRIMARY KEY,
    proc_name        VARCHAR(64) NOT NULL,
    emp_id           INT,
    new_dept_id      VARCHAR(10),
    sql_state        CHAR(5),
    error_no         INT,
    error_message    VARCHAR(255),
    logged_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================================
--  PART B : STORED PROCEDURE transfer_employee(emp_id, new_dept_id)
-- =====================================================================
--  Business rules (custom error numbers):
--   5001  emp_id and new_dept_id are required (NULL / blank input)
--   5002  employee does not exist
--   5003  department does not exist
--   5004  employee is already in that department
--   5005  employee is the head (manager) of a department
--   5006  employee is Lead of an Ongoing project
--   5007  employee still has people reporting to them
-- =====================================================================

DELIMITER $$

CREATE PROCEDURE transfer_employee(IN p_emp_id INT, IN p_new_dept_id VARCHAR(10))
BEGIN
    DECLARE v_old_dept   CHAR(3);
    DECLARE v_old_mgr    INT;
    DECLARE v_new_mgr    INT;
    DECLARE v_emp_name   VARCHAR(61);
    DECLARE v_count      INT DEFAULT 0;
    DECLARE v_msg        VARCHAR(255);
    -- variables for the error handler
    DECLARE v_state      CHAR(5);
    DECLARE v_errno      INT;
    DECLARE v_errmsg     VARCHAR(255);

    -- Error handling: on ANY error, roll back, log the failure, re-raise it to the caller
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_state  = RETURNED_SQLSTATE,
            v_errno  = MYSQL_ERRNO,
            v_errmsg = MESSAGE_TEXT;
        ROLLBACK;
        INSERT INTO procedure_error_log (proc_name, emp_id, new_dept_id, sql_state, error_no, error_message)
        VALUES ('transfer_employee', p_emp_id, p_new_dept_id, v_state, v_errno, v_errmsg);
        RESIGNAL;
    END;

    -- Normalise input: ' d05 ' -> 'D05'
    SET p_new_dept_id = UPPER(TRIM(p_new_dept_id));

    -- Rule 5001: required parameters
    IF p_emp_id IS NULL OR p_new_dept_id IS NULL OR p_new_dept_id = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'emp_id and new_dept_id are required', MYSQL_ERRNO = 5001;
    END IF;

    START TRANSACTION;

    -- Rule 5002: employee must exist (row is locked until COMMIT/ROLLBACK)
    SELECT dept_id, manager_id, CONCAT(first_name, ' ', last_name)
      INTO v_old_dept, v_old_mgr, v_emp_name
      FROM employee
     WHERE emp_id = p_emp_id
       FOR UPDATE;

    IF v_old_dept IS NULL THEN
        SET v_msg = CONCAT('Employee ', p_emp_id, ' does not exist');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5002;
    END IF;

    -- Rule 5003: target department must exist
    IF NOT EXISTS (SELECT 1 FROM department WHERE dept_id = p_new_dept_id) THEN
        SET v_msg = CONCAT('Department ', p_new_dept_id, ' does not exist');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5003;
    END IF;

    -- Rule 5004: must be a different department
    IF v_old_dept = p_new_dept_id THEN
        SET v_msg = CONCAT(v_emp_name, ' is already in department ', p_new_dept_id);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5004;
    END IF;

    -- Rule 5005: department heads cannot be transferred
    IF EXISTS (SELECT 1 FROM department WHERE manager_id = p_emp_id) THEN
        SET v_msg = CONCAT(v_emp_name, ' heads a department; appoint a new head first');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5005;
    END IF;

    -- Rule 5006: Leads of ongoing projects cannot be transferred
    IF EXISTS (SELECT 1
                 FROM works_on w
                 JOIN project p ON p.proj_id = w.proj_id
                WHERE w.emp_id = p_emp_id AND w.role = 'Lead' AND p.status = 'Ongoing') THEN
        SET v_msg = CONCAT(v_emp_name, ' leads an ongoing project; hand over the project first');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5006;
    END IF;

    -- Rule 5007: employees with direct reports cannot be transferred
    SELECT COUNT(*) INTO v_count FROM employee WHERE manager_id = p_emp_id;
    IF v_count > 0 THEN
        SET v_msg = CONCAT(v_emp_name, ' has ', v_count, ' direct report(s); reassign them first');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5007;
    END IF;

    -- All checks passed: move the employee and report to the new department's head
    SELECT manager_id INTO v_new_mgr FROM department WHERE dept_id = p_new_dept_id;

    UPDATE employee
       SET dept_id = p_new_dept_id,
           manager_id = v_new_mgr
     WHERE emp_id = p_emp_id;

    INSERT INTO transfer_history (emp_id, from_dept, to_dept, old_manager_id, new_manager_id, transferred_by)
    VALUES (p_emp_id, v_old_dept, p_new_dept_id, v_old_mgr, v_new_mgr, CURRENT_USER());

    COMMIT;

    SELECT CONCAT('SUCCESS: ', v_emp_name, ' transferred from ', v_old_dept,
                  ' to ', p_new_dept_id, ' (new manager: ', v_new_mgr, ')') AS result;
END $$

-- =====================================================================
--  PART C : TRIGGERS
-- =====================================================================
--  Salary rules (custom error numbers):
--   5101  salary below the minimum of Rs 15,000
--   5102  salary above the maximum of Rs 5,00,000
--   5103  commission more than 50% of salary
--   5104  raise of more than 30% in a single update
--   5105  salary reduction is not allowed
--   5106  a department head cannot be deleted
-- =====================================================================

-- Helper procedure shared by the INSERT and UPDATE triggers
CREATE PROCEDURE validate_salary(IN p_salary DECIMAL(10,2), IN p_commission DECIMAL(10,2))
BEGIN
    IF p_salary < 15000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Salary cannot be below Rs 15,000 per month', MYSQL_ERRNO = 5101;
    END IF;
    IF p_salary > 500000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Salary cannot exceed Rs 5,00,000 per month', MYSQL_ERRNO = 5102;
    END IF;
    IF p_commission IS NOT NULL AND p_commission > 0.5 * p_salary THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Commission cannot exceed 50% of salary', MYSQL_ERRNO = 5103;
    END IF;
END $$

-- 1. Salary validation on INSERT
CREATE TRIGGER trg_employee_before_insert
BEFORE INSERT ON employee
FOR EACH ROW
BEGIN
    CALL validate_salary(NEW.salary, NEW.commission);
END $$

-- 2. Salary validation on UPDATE (limits + no big jumps + no cuts)
CREATE TRIGGER trg_employee_before_update
BEFORE UPDATE ON employee
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(255);

    CALL validate_salary(NEW.salary, NEW.commission);

    IF NEW.salary > OLD.salary * 1.30 THEN
        SET v_msg = CONCAT('Raise for employee ', OLD.emp_id, ' is ',
                           ROUND((NEW.salary - OLD.salary) * 100 / OLD.salary, 1),
                           '%; maximum allowed is 30%');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5104;
    END IF;

    IF NEW.salary < OLD.salary THEN
        SET v_msg = CONCAT('Salary of employee ', OLD.emp_id, ' cannot be reduced (',
                           OLD.salary, ' -> ', NEW.salary, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg, MYSQL_ERRNO = 5105;
    END IF;
END $$

-- 3. Protect department heads from deletion
CREATE TRIGGER trg_employee_before_delete
BEFORE DELETE ON employee
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM department WHERE manager_id = OLD.emp_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot delete a department head; appoint a new head first',
                MYSQL_ERRNO = 5106;
    END IF;
END $$

-- 4. Audit logging: INSERT
CREATE TRIGGER trg_employee_after_insert
AFTER INSERT ON employee
FOR EACH ROW
BEGIN
    INSERT INTO employee_audit (emp_id, action, new_dept, new_salary, new_designation, changed_by)
    VALUES (NEW.emp_id, 'INSERT', NEW.dept_id, NEW.salary, NEW.designation, CURRENT_USER());
END $$

-- 5. Audit logging: UPDATE (only when a tracked column really changed)
CREATE TRIGGER trg_employee_after_update
AFTER UPDATE ON employee
FOR EACH ROW
BEGIN
    IF NOT (OLD.dept_id     <=> NEW.dept_id)
    OR NOT (OLD.salary      <=> NEW.salary)
    OR NOT (OLD.designation <=> NEW.designation) THEN
        INSERT INTO employee_audit (emp_id, action, old_dept, new_dept, old_salary, new_salary,
                                    old_designation, new_designation, changed_by)
        VALUES (NEW.emp_id, 'UPDATE', OLD.dept_id, NEW.dept_id, OLD.salary, NEW.salary,
                OLD.designation, NEW.designation, CURRENT_USER());
    END IF;
END $$

-- 6. Audit logging: DELETE
CREATE TRIGGER trg_employee_after_delete
AFTER DELETE ON employee
FOR EACH ROW
BEGIN
    INSERT INTO employee_audit (emp_id, action, old_dept, old_salary, old_designation, changed_by)
    VALUES (OLD.emp_id, 'DELETE', OLD.dept_id, OLD.salary, OLD.designation, CURRENT_USER());
END $$

DELIMITER ;

-- =====================================================================
--  PART D : VERIFY THE OBJECTS WERE CREATED
-- =====================================================================

-- D1. [Verify] Stored routines in company_db.
SELECT ROUTINE_NAME, ROUTINE_TYPE, CREATED IS NOT NULL AS created
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'company_db'
ORDER BY ROUTINE_NAME;

-- D2. [Verify] Triggers on the employee table.
SELECT TRIGGER_NAME, ACTION_TIMING AS timing, EVENT_MANIPULATION AS event, EVENT_OBJECT_TABLE AS on_table
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'company_db'
ORDER BY ACTION_TIMING DESC, EVENT_MANIPULATION;

-- =====================================================================
--  PART E : TESTING transfer_employee
-- =====================================================================

-- T1. [Happy path] Transfer Arjun (105) from Engineering (D01) to Finance (D03).
SELECT emp_id, first_name, dept_id, manager_id FROM employee WHERE emp_id = 105;
CALL transfer_employee(105, 'D03');
SELECT emp_id, first_name, dept_id, manager_id FROM employee WHERE emp_id = 105;
SELECT transfer_id, emp_id, from_dept, to_dept, old_manager_id, new_manager_id FROM transfer_history;

-- T2. [Edge: input normalisation] Lower-case department code with spaces is accepted.
CALL transfer_employee(132, '  d02 ');
SELECT emp_id, first_name, dept_id, manager_id FROM employee WHERE emp_id = 132;

-- T3. [Edge: completed project] Sanjay (112) is Lead only of a COMPLETED project, so he may move.
CALL transfer_employee(112, 'D04');

-- T4. [Error 5001] NULL employee id.
CALL transfer_employee(NULL, 'D02');

-- T5. [Error 5001] Blank department code.
CALL transfer_employee(110, '   ');

-- T6. [Error 5002] Employee that does not exist.
CALL transfer_employee(999, 'D02');

-- T7. [Error 5003] Department that does not exist.
CALL transfer_employee(110, 'D09');

-- T8. [Error 5004] Transfer to the department the employee is already in.
CALL transfer_employee(110, 'D01');

-- T9. [Error 5005] Transfer a department head (Rajesh, head of Engineering).
CALL transfer_employee(101, 'D05');

-- T10. [Error 5006] Transfer the Lead of an ongoing project (Sneha leads P02 Mobile App Revamp).
CALL transfer_employee(104, 'D05');

-- T11. [Error 5007] Transfer someone who has direct reports (Vikram manages Karthik and Divya).
CALL transfer_employee(103, 'D05');

-- T12. [Atomicity] After all the failures, the employees are unchanged and only 3 transfers exist.
SELECT emp_id, first_name, dept_id FROM employee WHERE emp_id IN (101, 103, 104, 110) ORDER BY emp_id;
SELECT COUNT(*) AS successful_transfers FROM transfer_history;

-- T13. [Error log] Every failed call was captured by the EXIT HANDLER.
SELECT log_id, emp_id, new_dept_id, sql_state, error_no, error_message
FROM procedure_error_log
ORDER BY log_id;

-- =====================================================================
--  PART F : TESTING THE TRIGGERS
-- =====================================================================

-- S1. [INSERT valid] A valid new employee is inserted and audited.
INSERT INTO employee (emp_id, first_name, last_name, gender, dob, hire_date, email, city,
                      designation, salary, commission, manager_id, dept_id)
VALUES (140, 'Kiran', 'Bose', 'F', '2001-03-14', '2026-09-01', 'kiran.bose@company.in',
        'Kolkata', 'Sales Executive', 40000, 5000, 120, 'D04');
SELECT emp_id, first_name, salary, commission FROM employee WHERE emp_id = 140;

-- S2. [Error 5101] Salary below the minimum.
INSERT INTO employee (emp_id, first_name, last_name, gender, dob, hire_date, email, city,
                      designation, salary, manager_id, dept_id)
VALUES (141, 'Test', 'Low', 'M', '2002-01-01', '2026-09-01', 'test.low@company.in',
        'Pune', 'Intern', 12000, 127, 'D05');

-- S3. [Edge: boundary] Exactly Rs 15,000 is allowed.
INSERT INTO employee (emp_id, first_name, last_name, gender, dob, hire_date, email, city,
                      designation, salary, manager_id, dept_id)
VALUES (141, 'Test', 'Boundary', 'M', '2002-01-01', '2026-09-01', 'test.boundary@company.in',
        'Pune', 'Intern', 15000, 127, 'D05');
SELECT emp_id, first_name, salary FROM employee WHERE emp_id = 141;

-- S4. [Error 5102] Salary above the maximum.
INSERT INTO employee (emp_id, first_name, last_name, gender, dob, hire_date, email, city,
                      designation, salary, manager_id, dept_id)
VALUES (142, 'Test', 'High', 'M', '1980-01-01', '2026-09-01', 'test.high@company.in',
        'Mumbai', 'Director', 600000, NULL, 'D03');

-- S5. [Error 5103] Commission more than 50% of salary.
INSERT INTO employee (emp_id, first_name, last_name, gender, dob, hire_date, email, city,
                      designation, salary, commission, manager_id, dept_id)
VALUES (143, 'Test', 'Comm', 'F', '1999-01-01', '2026-09-01', 'test.comm@company.in',
        'Delhi', 'Sales Executive', 40000, 25000, 120, 'D04');

-- S6. [Edge: NULL salary] The trigger lets NULL through (comparisons with NULL are unknown); NOT NULL catches it.
INSERT INTO employee (emp_id, first_name, last_name, gender, dob, hire_date, email, city,
                      designation, salary, manager_id, dept_id)
VALUES (144, 'Test', 'Null', 'M', '1999-01-01', '2026-09-01', 'test.null@company.in',
        'Delhi', 'Intern', NULL, 120, 'D04');

-- S7. [UPDATE valid] A 10% raise is accepted and audited.
UPDATE employee SET salary = salary * 1.10 WHERE emp_id = 117;
SELECT emp_id, first_name, salary FROM employee WHERE emp_id = 117;

-- S8. [Edge: boundary] A raise of exactly 30% is allowed.
UPDATE employee SET salary = salary * 1.30 WHERE emp_id = 119;
SELECT emp_id, first_name, salary FROM employee WHERE emp_id = 119;

-- S9. [Error 5104] A raise of more than 30%.
UPDATE employee SET salary = salary * 1.31 WHERE emp_id = 113;

-- S10. [Error 5105] Salary reduction.
UPDATE employee SET salary = salary - 1000 WHERE emp_id = 113;

-- S11. [Edge: multi-row statement] One bad row makes the WHOLE statement fail; no row is changed.
SELECT emp_id, first_name, salary FROM employee WHERE dept_id = 'D05' ORDER BY emp_id;
UPDATE employee SET salary = salary + 20000 WHERE dept_id = 'D05';
SELECT emp_id, first_name, salary FROM employee WHERE dept_id = 'D05' ORDER BY emp_id;

-- S12. [Edge: untracked column] Changing only the city does NOT create an audit row.
SELECT COUNT(*) AS audit_rows_before FROM employee_audit;
UPDATE employee SET city = 'Navi Mumbai' WHERE emp_id = 114;
SELECT COUNT(*) AS audit_rows_after FROM employee_audit;

-- S13. [Edge: no-op update] Setting a salary to its current value is not a "reduction" and is not audited.
UPDATE employee SET salary = salary WHERE emp_id = 114;
SELECT COUNT(*) AS audit_rows_after_noop FROM employee_audit;

-- S14. [Error 5106] Deleting a department head is blocked.
DELETE FROM employee WHERE emp_id = 111;

-- S15. [DELETE valid] Deleting an ordinary employee is audited (works_on rows cascade).
DELETE FROM employee WHERE emp_id = 141;

-- S16. [Trigger fired by the procedure] The successful transfers in T1-T3 were audited by the UPDATE trigger.
SELECT a.audit_id, a.emp_id, a.old_dept, a.new_dept, t.transfer_id
FROM employee_audit a
JOIN transfer_history t ON t.emp_id = a.emp_id AND t.to_dept = a.new_dept
ORDER BY a.audit_id;

-- =====================================================================
--  PART G : FINAL AUDIT TRAIL
-- =====================================================================

-- G1. [Audit log] Every change made by the tests, recorded automatically by the triggers.
SELECT audit_id, emp_id, action, old_dept, new_dept, old_salary, new_salary,
       old_designation, new_designation, changed_by
FROM employee_audit
ORDER BY audit_id;
