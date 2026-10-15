-- =====================================================================
--  Experiment 4 : Joins, Subqueries, Set Operations and EXPLAIN (MySQL 8.0+)
--  Student : Ritesh Vishwakarma    UID : 25LBCS3192
--  Uses the Employee-Department-Project schema from Experiment 3.
--
--  Run (company_queries.sql from Experiment 3 first; it creates and fills company_db):
--     mysql -u root -p -t < company_queries.sql
--     mysql -u root -p -t < joins_subqueries.sql
-- =====================================================================

USE company_db;

-- Remove the indexes created in Part H so the script can be re-run.
DROP PROCEDURE IF EXISTS drop_exp4_indexes;
DELIMITER //
CREATE PROCEDURE drop_exp4_indexes()
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.STATISTICS
               WHERE TABLE_SCHEMA = 'company_db' AND TABLE_NAME = 'employee'
                 AND INDEX_NAME = 'idx_emp_city') THEN
        DROP INDEX idx_emp_city ON employee;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.STATISTICS
               WHERE TABLE_SCHEMA = 'company_db' AND TABLE_NAME = 'employee'
                 AND INDEX_NAME = 'idx_emp_salary') THEN
        DROP INDEX idx_emp_salary ON employee;
    END IF;
END //
DELIMITER ;
CALL drop_exp4_indexes();
DROP PROCEDURE drop_exp4_indexes;

-- =====================================================================
--  PART A : INNER JOIN
-- =====================================================================

-- Q1. [INNER JOIN] Employees of HR and Finance with their department name and location.
SELECT e.emp_id, e.first_name, e.designation, d.dept_name, d.location
FROM employee e
INNER JOIN department d ON e.dept_id = d.dept_id
WHERE d.dept_id IN ('D02', 'D03')
ORDER BY d.dept_id, e.emp_id;

-- Q2. [INNER JOIN] Each project with the name of its controlling department and the department manager.
SELECT p.proj_id, p.proj_name, d.dept_name,
       CONCAT(m.first_name, ' ', m.last_name) AS dept_manager
FROM project p
INNER JOIN department d ON p.dept_id = d.dept_id
INNER JOIN employee   m ON d.manager_id = m.emp_id
ORDER BY p.proj_id;

-- Q3. [INNER JOIN + GROUP BY] Number of projects and total budget controlled by each department.
SELECT d.dept_name, COUNT(p.proj_id) AS projects, SUM(p.budget) AS total_budget
FROM department d
INNER JOIN project p ON p.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY total_budget DESC;

-- =====================================================================
--  PART B : LEFT JOIN
-- =====================================================================

-- Q4. [LEFT JOIN] All HR employees with their projects; employees without a project still appear (NULL).
SELECT e.emp_id, e.first_name, w.proj_id, w.role
FROM employee e
LEFT JOIN works_on w ON e.emp_id = w.emp_id
WHERE e.dept_id = 'D02'
ORDER BY e.emp_id;

-- Q5. [LEFT JOIN - anti-join] Employees who are not assigned to any project.
SELECT e.emp_id, e.first_name, e.last_name, e.designation
FROM employee e
LEFT JOIN works_on w ON e.emp_id = w.emp_id
WHERE w.emp_id IS NULL;

-- Q6. [LEFT JOIN - condition in ON] Every department with the count of its commission earners (0 if none).
SELECT d.dept_name, COUNT(e.emp_id) AS commission_earners
FROM department d
LEFT JOIN employee e
       ON e.dept_id = d.dept_id
      AND e.commission IS NOT NULL
GROUP BY d.dept_id, d.dept_name
ORDER BY d.dept_id;

-- Q7. [LEFT JOIN vs WHERE] Same query with the condition in WHERE: departments with 0 earners disappear.
SELECT d.dept_name, COUNT(e.emp_id) AS commission_earners
FROM department d
LEFT JOIN employee e ON e.dept_id = d.dept_id
WHERE e.commission IS NOT NULL
GROUP BY d.dept_id, d.dept_name;

-- Q8. [RIGHT JOIN] Projects with members of the Finance department (RIGHT JOIN keeps every project).
SELECT p.proj_id, p.proj_name, f.first_name AS finance_member
FROM (SELECT w.proj_id, e.first_name
      FROM works_on w
      JOIN employee e ON e.emp_id = w.emp_id
      WHERE e.dept_id = 'D03') AS f
RIGHT JOIN project p ON p.proj_id = f.proj_id
ORDER BY p.proj_id;

-- =====================================================================
--  PART C : SELF-JOIN
-- =====================================================================

-- Q9. [SELF-JOIN] Engineering employees with the name of their manager (LEFT self-join keeps the top manager).
SELECT e.emp_id, e.first_name AS employee, e.designation,
       m.first_name AS manager, m.designation AS manager_designation
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.emp_id
WHERE e.dept_id = 'D01'
ORDER BY e.emp_id;

-- Q10. [SELF-JOIN + GROUP BY] Managers and the number of people reporting directly to them.
SELECT m.emp_id, m.first_name AS manager, COUNT(e.emp_id) AS direct_reports
FROM employee m
INNER JOIN employee e ON e.manager_id = m.emp_id
GROUP BY m.emp_id, m.first_name
ORDER BY direct_reports DESC, m.emp_id;

-- Q11. [SELF-JOIN] Pairs of employees from the same city but different departments.
SELECT e1.city, e1.first_name AS employee_1, e1.dept_id AS dept_1,
       e2.first_name AS employee_2, e2.dept_id AS dept_2
FROM employee e1
INNER JOIN employee e2
        ON e1.city = e2.city
       AND e1.emp_id < e2.emp_id
       AND e1.dept_id <> e2.dept_id
ORDER BY e1.city, e1.emp_id;

-- Q12. [SELF-JOIN] Employees whose salary is at least 75% of their own manager's salary.
SELECT e.first_name AS employee, e.salary AS emp_salary,
       m.first_name AS manager,  m.salary AS mgr_salary,
       ROUND(e.salary * 100 / m.salary, 1) AS pct_of_manager
FROM employee e
JOIN employee m ON e.manager_id = m.emp_id
WHERE e.salary >= 0.75 * m.salary
ORDER BY pct_of_manager DESC;

-- =====================================================================
--  PART D : 3-WAY (MULTI-TABLE) JOIN
-- =====================================================================

-- Q13. [3-WAY JOIN] EMPLOYEE - WORKS_ON - PROJECT: team of the AI Chatbot project.
SELECT p.proj_name, e.first_name, e.last_name, w.role, w.hours_per_week
FROM employee e
JOIN works_on w ON e.emp_id  = w.emp_id
JOIN project  p ON w.proj_id = p.proj_id
WHERE p.proj_id = 'P03'
ORDER BY w.hours_per_week DESC, e.emp_id;

-- Q14. [5-WAY JOIN] Employees working on a project controlled by a DIFFERENT department.
SELECT e.first_name, ed.dept_name AS home_dept,
       p.proj_name,  pd.dept_name AS project_dept, w.role
FROM employee e
JOIN department ed ON e.dept_id  = ed.dept_id
JOIN works_on   w  ON e.emp_id   = w.emp_id
JOIN project    p  ON w.proj_id  = p.proj_id
JOIN department pd ON p.dept_id  = pd.dept_id
WHERE e.dept_id <> p.dept_id
ORDER BY e.emp_id;

-- Q15. [3-WAY JOIN + GROUP BY] Weekly hours each department contributes to projects.
SELECT d.dept_name,
       COUNT(DISTINCT e.emp_id) AS staff_on_projects,
       SUM(w.hours_per_week)    AS weekly_hours
FROM department d
JOIN employee e ON e.dept_id = d.dept_id
JOIN works_on w ON w.emp_id  = e.emp_id
GROUP BY d.dept_id, d.dept_name
ORDER BY weekly_hours DESC;

-- =====================================================================
--  PART E : CORRELATED SUBQUERIES
-- =====================================================================

-- Q16. [CORRELATED SUBQUERY] Employees earning more than the average salary of their own department.
SELECT e.emp_id, e.first_name, e.dept_id, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary)
                  FROM employee e2
                  WHERE e2.dept_id = e.dept_id)
ORDER BY e.dept_id, e.salary DESC;

-- Q17. [CORRELATED SUBQUERY] Highest-paid non-manager in each department.
SELECT e.dept_id, e.first_name, e.designation, e.salary
FROM employee e
WHERE e.manager_id IS NOT NULL
  AND e.salary = (SELECT MAX(e2.salary)
                  FROM employee e2
                  WHERE e2.dept_id = e.dept_id
                    AND e2.manager_id IS NOT NULL)
ORDER BY e.dept_id;

-- Q18. [CORRELATED SUBQUERY in SELECT] Each Operations employee with their number of projects and total hours.
SELECT e.emp_id, e.first_name,
       (SELECT COUNT(*) FROM works_on w WHERE w.emp_id = e.emp_id)           AS projects,
       (SELECT IFNULL(SUM(w.hours_per_week), 0)
          FROM works_on w WHERE w.emp_id = e.emp_id)                         AS weekly_hours
FROM employee e
WHERE e.dept_id = 'D05'
ORDER BY e.emp_id;

-- Q19. [CORRELATED SUBQUERY] Projects whose budget is above the average budget of the same department's projects.
SELECT p.proj_id, p.proj_name, p.dept_id, p.budget
FROM project p
WHERE p.budget > (SELECT AVG(p2.budget) FROM project p2 WHERE p2.dept_id = p.dept_id);

-- =====================================================================
--  PART F : EXISTS / NOT EXISTS
-- =====================================================================

-- Q20. [EXISTS] Departments that have at least one employee earning Rs 1,50,000 or more.
SELECT d.dept_id, d.dept_name
FROM department d
WHERE EXISTS (SELECT 1 FROM employee e
              WHERE e.dept_id = d.dept_id AND e.salary >= 150000)
ORDER BY d.dept_id;

-- Q21. [NOT EXISTS] Employees not working on any project (same result as Q5).
SELECT e.emp_id, e.first_name, e.last_name
FROM employee e
WHERE NOT EXISTS (SELECT 1 FROM works_on w WHERE w.emp_id = e.emp_id);

-- Q22. [EXISTS] Employees who work on at least one project with more than 35 hours per week.
SELECT e.emp_id, e.first_name, e.dept_id
FROM employee e
WHERE EXISTS (SELECT 1 FROM works_on w
              WHERE w.emp_id = e.emp_id AND w.hours_per_week > 35)
  AND e.dept_id IN ('D01', 'D05')
ORDER BY e.emp_id;

-- Q23. [NOT EXISTS - relational division] Employees who work on EVERY project that Rajesh (101) works on.
SELECT e.emp_id, e.first_name
FROM employee e
WHERE NOT EXISTS (
        SELECT 1 FROM works_on r
        WHERE r.emp_id = 101
          AND NOT EXISTS (SELECT 1 FROM works_on w
                          WHERE w.emp_id = e.emp_id
                            AND w.proj_id = r.proj_id));

-- =====================================================================
--  PART G : SIMULATED INTERSECT AND EXCEPT
--  (MySQL added native INTERSECT/EXCEPT only in 8.0.31; older versions
--   need these simulations, and they work on every version.)
-- =====================================================================

-- Q24. [INTERSECT using IN] Engineering employees who ALSO served on the HR hiring project P04.
SELECT emp_id, first_name
FROM employee
WHERE dept_id = 'D01'
  AND emp_id IN (SELECT emp_id FROM works_on WHERE proj_id = 'P04')
ORDER BY emp_id;

-- Q25. [INTERSECT using INNER JOIN] Same result using a join on the two sets.
SELECT DISTINCT a.emp_id, a.first_name
FROM (SELECT emp_id, first_name FROM employee WHERE dept_id = 'D01') AS a
INNER JOIN (SELECT emp_id FROM works_on WHERE proj_id = 'P04') AS b
        ON a.emp_id = b.emp_id
ORDER BY a.emp_id;

-- Q26. [INTERSECT native, MySQL 8.0.31+] Same result with the INTERSECT operator.
SELECT emp_id FROM employee WHERE dept_id = 'D01'
INTERSECT
SELECT emp_id FROM works_on WHERE proj_id = 'P04'
ORDER BY emp_id;

-- Q27. [EXCEPT using NOT IN] Engineering employees EXCEPT those on the Mobile App Revamp (P02).
SELECT emp_id, first_name
FROM employee
WHERE dept_id = 'D01'
  AND emp_id NOT IN (SELECT emp_id FROM works_on WHERE proj_id = 'P02')
ORDER BY emp_id;

-- Q28. [EXCEPT using LEFT JOIN ... IS NULL] Same result as Q27 with an anti-join.
SELECT e.emp_id, e.first_name
FROM employee e
LEFT JOIN works_on w ON w.emp_id = e.emp_id AND w.proj_id = 'P02'
WHERE e.dept_id = 'D01' AND w.emp_id IS NULL
ORDER BY e.emp_id;

-- Q29. [EXCEPT native, MySQL 8.0.31+] Same result with the EXCEPT operator.
SELECT emp_id FROM employee WHERE dept_id = 'D01'
EXCEPT
SELECT emp_id FROM works_on WHERE proj_id = 'P02'
ORDER BY emp_id;

-- Q30. [EXCEPT using NOT EXISTS] Departments that do NOT control any Ongoing project.
SELECT d.dept_id, d.dept_name
FROM department d
WHERE NOT EXISTS (SELECT 1 FROM project p
                  WHERE p.dept_id = d.dept_id AND p.status = 'Ongoing');

-- =====================================================================
--  PART H : EXECUTION PLANS WITH EXPLAIN
-- =====================================================================

-- E1. [EXPLAIN - no index] Refresh table statistics first, then filter on a column without an index: a full table scan.
ANALYZE TABLE employee, department, project, works_on;
EXPLAIN SELECT * FROM employee WHERE city = 'Chennai';

-- E2. [EXPLAIN - with index] After creating an index on city, MySQL looks up matching rows directly.
CREATE INDEX idx_emp_city ON employee(city);
EXPLAIN SELECT * FROM employee WHERE city = 'Chennai';

-- E3. [EXPLAIN - primary key] Lookup by primary key is the cheapest access type (const).
EXPLAIN SELECT * FROM employee WHERE emp_id = 105;

-- E4. [EXPLAIN - range scan] An index on salary turns a range condition into a range scan.
CREATE INDEX idx_emp_salary ON employee(salary);
EXPLAIN SELECT emp_id, salary FROM employee WHERE salary > 150000;

-- E5. [EXPLAIN - 3-way join] Join order and eq_ref lookups on primary keys.
EXPLAIN
SELECT e.first_name, p.proj_name, w.hours_per_week
FROM employee e
JOIN works_on w ON e.emp_id  = w.emp_id
JOIN project  p ON w.proj_id = p.proj_id
WHERE p.proj_id = 'P03';

-- E6. [EXPLAIN - correlated subquery] Q16 as written: the subquery is DEPENDENT and re-runs per outer row.
EXPLAIN
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary) FROM employee e2 WHERE e2.dept_id = e.dept_id);

-- E7. [EXPLAIN - derived table rewrite] Q16 rewritten as a JOIN with a derived table: averages computed once.
EXPLAIN
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
JOIN (SELECT dept_id, AVG(salary) AS avg_sal
      FROM employee GROUP BY dept_id) AS da
  ON da.dept_id = e.dept_id
WHERE e.salary > da.avg_sal;

-- E8. [EXPLAIN - IN vs EXISTS vs JOIN] Three ways to find employees on some project (semi-join).
EXPLAIN SELECT emp_id FROM employee e WHERE emp_id IN (SELECT emp_id FROM works_on);
EXPLAIN SELECT emp_id FROM employee e WHERE EXISTS (SELECT 1 FROM works_on w WHERE w.emp_id = e.emp_id);
EXPLAIN SELECT DISTINCT e.emp_id FROM employee e JOIN works_on w ON w.emp_id = e.emp_id;

-- E9. [EXPLAIN - NOT IN vs NOT EXISTS vs LEFT JOIN] Three ways to write the anti-join of Q5.
EXPLAIN SELECT emp_id FROM employee WHERE emp_id NOT IN (SELECT emp_id FROM works_on);
EXPLAIN SELECT emp_id FROM employee e WHERE NOT EXISTS (SELECT 1 FROM works_on w WHERE w.emp_id = e.emp_id);
EXPLAIN SELECT e.emp_id FROM employee e LEFT JOIN works_on w ON w.emp_id = e.emp_id WHERE w.emp_id IS NULL;

-- E10. [EXPLAIN FORMAT=TREE] The plan of the 5-way join (Q14) as an operator tree.
EXPLAIN FORMAT=TREE
SELECT e.first_name, ed.dept_name, p.proj_name, pd.dept_name
FROM employee e
JOIN department ed ON e.dept_id = ed.dept_id
JOIN works_on   w  ON e.emp_id  = w.emp_id
JOIN project    p  ON w.proj_id = p.proj_id
JOIN department pd ON p.dept_id = pd.dept_id
WHERE e.dept_id <> p.dept_id;

-- E11. [EXPLAIN ANALYZE] Actually runs the correlated query and reports real row counts and times.
EXPLAIN ANALYZE
SELECT e.emp_id, e.first_name, e.salary
FROM employee e
WHERE e.salary > (SELECT AVG(e2.salary) FROM employee e2 WHERE e2.dept_id = e.dept_id);
