-- Deixei tudo em transações para poder fazer rollback
BEGIN;

CREATE MATERIALIZED VIEW Book_Loans.month_borrowers (
    card_no,
    name,
    _address,
    phone,
    loan_length,
    book_title,
    branch_name ) AS
    SELECT b.card_no,
            b.name,
            b._address,
            b.phone,
            (bl.due_date - bl.date_out) AS loan_length,
            bo.title                    AS book_title,
            lb.branch_name
        FROM Book_Loans.Borrower b
        JOIN Book_Loans.Book_Loans bl ON b.card_no = bl.card_no
        JOIN Book_Loans.Book bo ON bl.book_id = bo.book_id
        JOIN Book_Loans.Library_Branch lb ON bl.branch_id = lb.branch_id
        WHERE (bl.due_date - bl.date_out) > 30;

ROLLBACK;