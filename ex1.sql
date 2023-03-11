BEGIN;

CREATE MATERIALIZED VIEW month_borrowers(
    card_no, 
    name,
    _address,
    phone,
    loan_length,
    book_title,
    branch_name
)
AS
SELECT 
    b.card_no,
    b.name,
    b._address,
    b.phone,
    (bl.due_date - bl.date_out) AS loan_length,
    bo.title AS book_title,
    lb.branch_name
FROM Borrower b
JOIN Book_Loans bl ON b.card_no = bl.card_no
JOIN Book bo ON bl.book_id = bo.book_id
JOIN Library_Branch lb ON bl.branch_id = lb.branch_id
WHERE (bl.due_date - bl.date_out) > 30;

SELECT * FROM month_borrowers;

UPDATE Book_Loans SET due_date = '2019-02-08' WHERE book_id = 1 AND branch_id = 1 AND card_no = 1;
UPDATE Book_Loans SET due_date = '2019-02-08' WHERE book_id = 2 AND branch_id = 1 AND card_no = 1;

SELECT * FROM month_borrowers;

ROLLBACK;