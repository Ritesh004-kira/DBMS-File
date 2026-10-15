-- =====================================================================
--  Experiment 3 : Employee - Department - Project Schema (MySQL 8.0+)
--  Student : Ritesh Vishwakarma    UID : 25LBCS3192
--  Selection, Projection, Aggregates, GROUP BY, HAVING, CASE, ORDER BY
--  Run:  mysql -u root -p -t < company_queries.sql
-- =====================================================================

DROP DATABASE IF EXISTS company_db;
CREATE DATABASE company_db;
USE company_db;

-- =====================================================================
--  PART A : SCHEMA
-- =====================================================================

CREATE TABLE department (
    dept_id       CHAR(3)      PRIMARY KEY,
    dept_name     VARCHAR(50)  NOT NULL UNIQUE,
    location      VARCHAR(50)  NOT NULL,
    manager_id    INT          NULL,               -- FK added after EMPLOYEE exists
    established   YEAR         NOT NULL
);

CREATE TABLE employee (
    emp_id        INT           PRIMARY KEY,
    first_name    VARCHAR(30)   NOT NULL,
    last_name     VARCHAR(30)   NOT NULL,
    gender        ENUM('M','F') NOT NULL,
    dob           DATE          NOT NULL,
    hire_date     DATE          NOT NULL,
    email         VARCHAR(100)  NOT NULL UNIQUE,
    city          VARCHAR(30)   NOT NULL,
    designation   VARCHAR(50)   NOT NULL,
    salary        DECIMAL(10,2) NOT NULL,          -- monthly salary in INR
    commission    DECIMAL(10,2) NULL,              -- only sales/marketing staff
    manager_id    INT           NULL,
    dept_id       CHAR(3)       NOT NULL,
    CONSTRAINT chk_salary CHECK (salary > 0),
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id)
        REFERENCES employee(emp_id) ON DELETE SET NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id)
        REFERENCES department(dept_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

ALTER TABLE department
    ADD CONSTRAINT fk_dept_manager FOREIGN KEY (manager_id)
        REFERENCES employee(emp_id) ON DELETE SET NULL;

CREATE TABLE project (
    proj_id       CHAR(3)       PRIMARY KEY,
    proj_name     VARCHAR(60)   NOT NULL UNIQUE,
    dept_id       CHAR(3)       NOT NULL,          -- controlling department
    location      VARCHAR(50)   NOT NULL,
    budget        DECIMAL(12,2) NOT NULL,          -- INR
    start_date    DATE          NOT NULL,
    end_date      DATE          NULL,
    status        ENUM('Planned','Ongoing','Completed') NOT NULL DEFAULT 'Planned',
    CONSTRAINT chk_budget CHECK (budget > 0),
    CONSTRAINT fk_proj_dept FOREIGN KEY (dept_id)
        REFERENCES department(dept_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- M:N relationship EMPLOYEE <-> PROJECT
CREATE TABLE works_on (
    emp_id          INT          NOT NULL,
    proj_id         CHAR(3)      NOT NULL,
    hours_per_week  DECIMAL(4,1) NOT NULL,
    role            VARCHAR(30)  NOT NULL,
    PRIMARY KEY (emp_id, proj_id),
    CONSTRAINT chk_hours CHECK (hours_per_week BETWEEN 1 AND 48),
    CONSTRAINT fk_wo_emp  FOREIGN KEY (emp_id)  REFERENCES employee(emp_id) ON DELETE CASCADE,
    CONSTRAINT fk_wo_proj FOREIGN KEY (proj_id) REFERENCES project(proj_id) ON DELETE CASCADE
);

-- =====================================================================
--  PART B : SAMPLE DATA  (5 departments, 32 employees, 8 projects)
-- =====================================================================

INSERT INTO department (dept_id, dept_name, location, established) VALUES
('D01', 'Engineering',     'Bengaluru', 2010),
('D02', 'Human Resources', 'Mumbai',    2010),
('D03', 'Finance',         'Mumbai',    2011),
('D04', 'Marketing',       'New Delhi', 2013),
('D05', 'Operations',      'Chennai',   2012);

INSERT INTO employee VALUES
-- Engineering (10)
(101,'Rajesh','Kumar','M','1980-03-15','2012-06-01','rajesh.kumar@company.in','Bengaluru','Engineering Manager',210000,NULL,NULL,'D01'),
(102,'Ananya','Reddy','F','1988-07-22','2015-08-17','ananya.reddy@company.in','Hyderabad','Tech Lead',165000,NULL,101,'D01'),
(103,'Vikram','Singh','M','1990-11-05','2016-01-11','vikram.singh@company.in','Bengaluru','Senior Software Engineer',135000,NULL,102,'D01'),
(104,'Sneha','Kulkarni','F','1993-02-14','2018-07-02','sneha.kulkarni@company.in','Pune','Senior Software Engineer',128000,NULL,102,'D01'),
(105,'Arjun','Nair','M','1995-09-30','2019-03-18','arjun.nair@company.in','Kochi','Software Engineer',95000,NULL,102,'D01'),
(106,'Pooja','Desai','F','1996-12-08','2020-09-07','pooja.desai@company.in','Ahmedabad','Software Engineer',88000,NULL,102,'D01'),
(107,'Karthik','Iyer','M','1997-05-19','2021-07-12','karthik.iyer@company.in','Chennai','Software Engineer',82000,NULL,103,'D01'),
(108,'Divya','Menon','F','1998-08-25','2022-08-01','divya.menon@company.in','Bengaluru','Associate Engineer',62000,NULL,103,'D01'),
(109,'Rahul','Verma','M','1999-01-10','2023-07-17','rahul.verma@company.in','Lucknow','Associate Engineer',58000,NULL,104,'D01'),
(110,'Neha','Joshi','F','2000-04-03','2024-01-08','neha.joshi@company.in','Jaipur','Associate Engineer',55000,NULL,104,'D01'),
-- Human Resources (4)
(111,'Meenakshi','Pillai','F','1982-06-11','2010-04-05','meenakshi.pillai@company.in','Mumbai','HR Manager',150000,NULL,NULL,'D02'),
(112,'Sanjay','Gupta','M','1989-10-02','2016-11-14','sanjay.gupta@company.in','Mumbai','HR Business Partner',90000,NULL,111,'D02'),
(113,'Ritu','Saxena','F','1994-03-27','2019-06-03','ritu.saxena@company.in','Delhi','Recruiter',60000,NULL,111,'D02'),
(114,'Aditya','Bhatt','M','1998-12-15','2023-02-20','aditya.bhatt@company.in','Mumbai','HR Executive',42000,NULL,111,'D02'),
-- Finance (5)
(115,'Suresh','Agarwal','M','1978-09-09','2009-01-12','suresh.agarwal@company.in','Kolkata','Finance Manager',185000,NULL,NULL,'D03'),
(116,'Kavita','Mehta','F','1987-05-17','2014-05-26','kavita.mehta@company.in','Mumbai','Senior Accountant',105000,NULL,115,'D03'),
(117,'Manoj','Tiwari','M','1991-08-21','2017-10-09','manoj.tiwari@company.in','Varanasi','Accountant',72000,NULL,116,'D03'),
(118,'Lakshmi','Rao','F','1995-01-29','2020-02-10','lakshmi.rao@company.in','Hyderabad','Financial Analyst',85000,NULL,115,'D03'),
(119,'Imran','Khan','M','1997-07-07','2022-04-18','imran.khan@company.in','Bhopal','Accounts Executive',48000,NULL,116,'D03'),
-- Marketing (6)
(120,'Nisha','Malhotra','F','1984-04-18','2013-03-04','nisha.malhotra@company.in','Delhi','Marketing Manager',160000,20000,NULL,'D04'),
(121,'Rohit','Bansal','M','1990-02-28','2017-05-15','rohit.bansal@company.in','Delhi','Brand Manager',110000,15000,120,'D04'),
(122,'Shreya','Ghosh','F','1993-09-12','2019-08-19','shreya.ghosh@company.in','Kolkata','Digital Marketing Specialist',78000,8000,121,'D04'),
(123,'Aman','Chauhan','M','1996-06-06','2021-01-25','aman.chauhan@company.in','Chandigarh','SEO Analyst',56000,NULL,121,'D04'),
(124,'Tanvi','Kapoor','F','1998-11-20','2022-11-07','tanvi.kapoor@company.in','Noida','Content Writer',45000,NULL,121,'D04'),
(125,'Farhan','Siddiqui','M','1995-03-03','2020-10-12','farhan.siddiqui@company.in','Lucknow','Sales Executive',52000,12000,120,'D04'),
-- Operations (7)
(126,'Venkatesh','Subramanian','M','1981-12-24','2011-09-19','venkatesh.s@company.in','Chennai','Operations Manager',175000,NULL,NULL,'D05'),
(127,'Deepa','Krishnan','F','1988-01-16','2015-02-02','deepa.krishnan@company.in','Chennai','Logistics Lead',98000,NULL,126,'D05'),
(128,'Harish','Gowda','M','1992-07-30','2018-04-16','harish.gowda@company.in','Mysuru','Supply Chain Analyst',76000,NULL,127,'D05'),
(129,'Swati','Mishra','F','1994-10-10','2019-12-02','swati.mishra@company.in','Patna','Operations Executive',54000,NULL,127,'D05'),
(130,'Gaurav','Yadav','M','1997-02-22','2021-06-14','gaurav.yadav@company.in','Kanpur','Operations Executive',50000,NULL,127,'D05'),
(131,'Bhavna','Thakur','F','1999-05-05','2023-09-04','bhavna.thakur@company.in','Shimla','Operations Trainee',35000,NULL,127,'D05'),
(132,'Naveen','Prasad','M','1986-08-08','2014-07-21','naveen.prasad@company.in','Chennai','Quality Manager',120000,NULL,126,'D05');

UPDATE department SET manager_id = 101 WHERE dept_id = 'D01';
UPDATE department SET manager_id = 111 WHERE dept_id = 'D02';
UPDATE department SET manager_id = 115 WHERE dept_id = 'D03';
UPDATE department SET manager_id = 120 WHERE dept_id = 'D04';
UPDATE department SET manager_id = 126 WHERE dept_id = 'D05';

INSERT INTO project VALUES
('P01','UPI Payment Gateway',       'D01','Bengaluru', 4500000,'2025-01-15','2025-12-31','Completed'),
('P02','Mobile App Revamp',         'D01','Bengaluru', 3200000,'2025-06-01','2026-12-31','Ongoing'),
('P03','AI Chatbot (Hindi-English)','D01','Hyderabad', 2800000,'2026-02-01','2027-03-31','Ongoing'),
('P04','Campus Hiring Drive 2026',  'D02','Mumbai',     600000,'2026-01-10','2026-08-31','Completed'),
('P05','GST Compliance Automation', 'D03','Mumbai',    1500000,'2025-09-01','2026-11-30','Ongoing'),
('P06','Diwali Festive Campaign',   'D04','New Delhi', 2200000,'2026-08-01','2026-11-15','Ongoing'),
('P07','Warehouse Automation',      'D05','Chennai',   5000000,'2026-04-01','2027-09-30','Ongoing'),
('P08','Tier-2 City Expansion',     'D05','Pune',      3500000,'2026-12-01',NULL,        'Planned');

INSERT INTO works_on VALUES
(101,'P01', 5,'Sponsor'),   (102,'P01',20,'Lead'),      (103,'P01',30,'Developer'),
(105,'P01',35,'Developer'), (118,'P01',10,'Analyst'),
(102,'P02',15,'Architect'), (104,'P02',30,'Lead'),      (106,'P02',40,'Developer'),
(108,'P02',35,'Developer'), (122,'P02',10,'Consultant'),
(101,'P03', 5,'Sponsor'),   (103,'P03',10,'Developer'), (107,'P03',40,'Developer'),
(109,'P03',40,'Developer'), (110,'P03',40,'Developer'), (124,'P03',15,'Content'),
(111,'P04',10,'Sponsor'),   (112,'P04',25,'Lead'),      (113,'P04',40,'Recruiter'),
(108,'P04', 5,'Panelist'),  (104,'P04', 5,'Panelist'),
(115,'P05',10,'Sponsor'),   (116,'P05',30,'Lead'),      (117,'P05',40,'Analyst'),
(119,'P05',40,'Analyst'),   (105,'P05', 5,'Developer'),
(120,'P06',15,'Sponsor'),   (121,'P06',35,'Lead'),      (122,'P06',30,'Specialist'),
(123,'P06',40,'SEO'),       (125,'P06',30,'Sales'),
(126,'P07',10,'Sponsor'),   (127,'P07',35,'Lead'),      (128,'P07',40,'Analyst'),
(129,'P07',40,'Executive'), (130,'P07',40,'Executive'), (132,'P07',15,'Quality'),
(126,'P08', 5,'Sponsor'),   (132,'P08',10,'Planning'),  (118,'P08',10,'Analyst');

-- =====================================================================
--  PART C : QUERIES
-- =====================================================================

-- Q1. [Selection] Display all departments.
SELECT * FROM department;

-- Q2. [Selection] Engineering employees earning more than Rs 1,00,000 per month (WHERE with AND).
SELECT emp_id, first_name, last_name, designation, salary
FROM employee
WHERE dept_id = 'D01' AND salary > 100000;

-- Q3. [Selection] Employees with salary between Rs 50,000 and Rs 80,000 (BETWEEN).
SELECT emp_id, first_name, designation, salary
FROM employee
WHERE salary BETWEEN 50000 AND 80000;

-- Q4. [Selection] Employees based in Mumbai, Chennai or Delhi (IN).
SELECT emp_id, first_name, last_name, city
FROM employee
WHERE city IN ('Mumbai', 'Chennai', 'Delhi');

-- Q5. [Selection] Employees whose designation contains 'Manager' (LIKE).
SELECT emp_id, first_name, designation
FROM employee
WHERE designation LIKE '%Manager%';

-- Q6. [Selection] Employees who report to no one, i.e. top-level managers (IS NULL).
SELECT emp_id, first_name, last_name, designation
FROM employee
WHERE manager_id IS NULL;

-- Q7. [Selection] Employees who earn a commission (IS NOT NULL).
SELECT emp_id, first_name, salary, commission
FROM employee
WHERE commission IS NOT NULL;

-- Q8. [Selection] Female employees hired on or after 1 Jan 2020, or anyone from Finance (AND / OR / dates).
SELECT emp_id, first_name, gender, hire_date, dept_id
FROM employee
WHERE (gender = 'F' AND hire_date >= '2020-01-01') OR dept_id = 'D03';

-- Q9. [Selection] Projects that are NOT completed (NOT / <>).
SELECT proj_id, proj_name, status
FROM project
WHERE status <> 'Completed';

-- Q10. [Projection] Only the name and designation columns of employees.
SELECT first_name, last_name, designation
FROM employee
WHERE dept_id = 'D02';

-- Q11. [Projection] Distinct cities where employees live (DISTINCT).
SELECT DISTINCT city
FROM employee
ORDER BY city;

-- Q12. [Projection] Computed columns with aliases: full name, annual CTC, total monthly pay.
SELECT emp_id,
       CONCAT(first_name, ' ', last_name)       AS full_name,
       salary                                   AS monthly_salary,
       salary * 12                              AS annual_ctc,
       salary + IFNULL(commission, 0)           AS total_monthly_pay
FROM employee
WHERE dept_id = 'D04';

-- Q13. [Projection] Age and experience in years (derived attributes).
SELECT emp_id, first_name,
       TIMESTAMPDIFF(YEAR, dob, CURDATE())       AS age,
       TIMESTAMPDIFF(YEAR, hire_date, CURDATE()) AS experience_years
FROM employee
WHERE dept_id = 'D05';

-- Q14. [Aggregates] Company-wide salary statistics.
SELECT COUNT(*)           AS total_employees,
       COUNT(commission)  AS with_commission,
       SUM(salary)        AS total_monthly_payroll,
       ROUND(AVG(salary), 2) AS avg_salary,
       MIN(salary)        AS min_salary,
       MAX(salary)        AS max_salary
FROM employee;

-- Q15. [Aggregates] COUNT(DISTINCT) and project budget totals.
SELECT COUNT(DISTINCT city)  AS distinct_cities,
       COUNT(DISTINCT designation) AS distinct_designations,
       (SELECT SUM(budget) FROM project) AS total_project_budget,
       (SELECT COUNT(*) FROM project WHERE end_date IS NULL) AS projects_without_end_date
FROM employee;

-- Q16. [GROUP BY] Department-wise headcount and salary statistics.
SELECT d.dept_name,
       COUNT(e.emp_id)         AS headcount,
       SUM(e.salary)           AS total_salary,
       ROUND(AVG(e.salary), 2) AS avg_salary,
       MIN(e.salary)           AS min_salary,
       MAX(e.salary)           AS max_salary
FROM department d
JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY d.dept_id;

-- Q17. [GROUP BY] Gender-wise count and average salary.
SELECT gender, COUNT(*) AS employees, ROUND(AVG(salary), 2) AS avg_salary
FROM employee
GROUP BY gender;

-- Q18. [GROUP BY] Multi-column grouping: department and gender.
SELECT dept_id, gender, COUNT(*) AS employees
FROM employee
GROUP BY dept_id, gender
ORDER BY dept_id, gender;

-- Q19. [GROUP BY] Project-wise team size and total weekly hours.
SELECT p.proj_id, p.proj_name,
       COUNT(w.emp_id)       AS team_size,
       SUM(w.hours_per_week) AS total_hours
FROM project p
JOIN works_on w ON w.proj_id = p.proj_id
GROUP BY p.proj_id, p.proj_name
ORDER BY p.proj_id;

-- Q20. [GROUP BY] Number of employees hired each year.
SELECT YEAR(hire_date) AS hire_year, COUNT(*) AS hired
FROM employee
GROUP BY YEAR(hire_date)
ORDER BY hire_year;

-- Q21. [HAVING] Departments with more than 5 employees.
SELECT dept_id, COUNT(*) AS headcount
FROM employee
GROUP BY dept_id
HAVING COUNT(*) > 5;

-- Q22. [HAVING] Departments whose average salary exceeds Rs 95,000.
SELECT d.dept_name, ROUND(AVG(e.salary), 2) AS avg_salary
FROM department d
JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_name
HAVING AVG(e.salary) > 95000;

-- Q23. [HAVING] Projects with more than 4 members AND at least 150 total weekly hours.
SELECT proj_id, COUNT(*) AS members, SUM(hours_per_week) AS total_hours
FROM works_on
GROUP BY proj_id
HAVING COUNT(*) > 4 AND SUM(hours_per_week) >= 150;

-- Q24. [WHERE + GROUP BY + HAVING] Among employees earning >= Rs 50,000, cities with at least 2 such employees.
SELECT city, COUNT(*) AS employees, MAX(salary) AS highest_salary
FROM employee
WHERE salary >= 50000
GROUP BY city
HAVING COUNT(*) >= 2
ORDER BY city;

-- Q25. [HAVING] Employees working on more than one project.
SELECT e.emp_id, e.first_name, COUNT(w.proj_id) AS projects, SUM(w.hours_per_week) AS weekly_hours
FROM employee e
JOIN works_on w ON w.emp_id = e.emp_id
GROUP BY e.emp_id, e.first_name
HAVING COUNT(w.proj_id) > 1;

-- Q26. [CASE - searched] Salary grade for each Engineering employee.
SELECT emp_id, first_name, salary,
       CASE
           WHEN salary >= 150000 THEN 'A - Leadership'
           WHEN salary >= 100000 THEN 'B - Senior'
           WHEN salary >=  60000 THEN 'C - Mid'
           ELSE                       'D - Junior'
       END AS salary_grade
FROM employee
WHERE dept_id = 'D01';

-- Q27. [CASE - simple] Project priority derived from status.
SELECT proj_id, proj_name, status,
       CASE status
           WHEN 'Ongoing'   THEN 'High'
           WHEN 'Planned'   THEN 'Medium'
           WHEN 'Completed' THEN 'Closed'
       END AS priority
FROM project;

-- Q28. [CASE + GROUP BY] Number of employees in each salary grade.
SELECT CASE
           WHEN salary >= 150000 THEN 'A - Leadership'
           WHEN salary >= 100000 THEN 'B - Senior'
           WHEN salary >=  60000 THEN 'C - Mid'
           ELSE                       'D - Junior'
       END AS salary_grade,
       COUNT(*) AS employees
FROM employee
GROUP BY salary_grade
ORDER BY salary_grade;

-- Q29. [CASE inside aggregates] Pivot: male/female count and senior staff per department.
SELECT dept_id,
       SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END)        AS male,
       SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END)        AS female,
       COUNT(CASE WHEN salary >= 100000 THEN 1 END)         AS earning_1L_plus,
       COUNT(*)                                             AS total
FROM employee
GROUP BY dept_id;

-- Q30. [CASE] Diwali bonus calculation based on experience.
SELECT emp_id, first_name, hire_date, salary,
       CASE
           WHEN hire_date <  '2015-01-01' THEN 0.20
           WHEN hire_date <  '2020-01-01' THEN 0.15
           ELSE                                0.10
       END AS bonus_rate,
       ROUND(salary * CASE
           WHEN hire_date <  '2015-01-01' THEN 0.20
           WHEN hire_date <  '2020-01-01' THEN 0.15
           ELSE                                0.10
       END, 0) AS diwali_bonus
FROM employee
WHERE dept_id = 'D03';

-- Q31. [ORDER BY] Top 5 highest-paid employees (DESC + LIMIT).
SELECT emp_id, first_name, designation, salary
FROM employee
ORDER BY salary DESC
LIMIT 5;

-- Q32. [ORDER BY] Multi-column sort: department ascending, salary descending.
SELECT dept_id, first_name, salary
FROM employee
WHERE dept_id IN ('D02', 'D03')
ORDER BY dept_id ASC, salary DESC;

-- Q33. [ORDER BY] Sort by an aggregate alias: departments by total payroll.
SELECT dept_id, SUM(salary) AS payroll
FROM employee
GROUP BY dept_id
ORDER BY payroll DESC;

-- Q34. [ORDER BY + CASE] Custom order: Ongoing projects first, then Planned, then Completed.
SELECT proj_id, proj_name, status, budget
FROM project
ORDER BY CASE status
             WHEN 'Ongoing'   THEN 1
             WHEN 'Planned'   THEN 2
             WHEN 'Completed' THEN 3
         END,
         budget DESC;

-- Q35. [ORDER BY] Newest joiners first, ties broken by name.
SELECT emp_id, first_name, hire_date
FROM employee
ORDER BY hire_date DESC, first_name
LIMIT 6;

-- Q36. [ALL CONCEPTS] Department report: only departments with avg salary > 85,000,
--      excluding trainees, with a pay band label, sorted by average salary.
SELECT d.dept_name,
       d.location,
       COUNT(e.emp_id)                                   AS headcount,
       ROUND(AVG(e.salary), 0)                           AS avg_salary,
       COUNT(CASE WHEN e.salary >= 100000 THEN 1 END)    AS senior_staff,
       CASE
           WHEN AVG(e.salary) >= 100000 THEN 'High-pay'
           WHEN AVG(e.salary) >=  90000 THEN 'Mid-pay'
           ELSE                              'Standard'
       END                                               AS pay_band
FROM department d
JOIN employee e ON e.dept_id = d.dept_id
WHERE e.designation NOT LIKE '%Trainee%'
GROUP BY d.dept_id, d.dept_name, d.location
HAVING AVG(e.salary) > 85000
ORDER BY avg_salary DESC;
